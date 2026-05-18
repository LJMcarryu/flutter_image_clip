import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_image_clip/flutter_image_clip.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'fixtures/mobile_image_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('runs the image processing pipeline off the UI isolate', () async {
    final processor = ImageProcessor();

    final sample = await processor.createSample();
    expect(sample.width, 960);
    expect(sample.height, 640);
    expect(sample.bytes, isNotEmpty);

    final cropped = await processor.cropCenter(
      sample,
      const CropSettings(widthRatio: 0.5, heightRatio: 0.25, cornerRadius: 16),
    );
    expect(cropped.width, 480);
    expect(cropped.height, 160);

    final gestureCropped = await processor.cropRegion(
      sample,
      const CropRegion(x: 120, y: 80, width: 300, height: 220, cornerRadius: 8),
    );
    expect(gestureCropped.operation, 'Crop region');
    expect(gestureCropped.width, 300);
    expect(gestureCropped.height, 220);

    final rotated = await processor.rotateRight(cropped);
    expect(rotated.width, 160);
    expect(rotated.height, 480);

    final adjusted = await processor.adjustColor(
      rotated,
      const ColorAdjustment(brightness: 1.08, contrast: 1.1, saturation: 0.9),
    );
    expect(adjusted.operation, 'Adjust color');
    expect(adjusted.bytes, isNotEmpty);

    final exported = await processor.exportPng(adjusted);
    expect(exported.operation, 'Export PNG');
    expect(exported.format, ImageClipOutputFormat.png);
    expect(exported.bytes, isNotEmpty);

    final jpeg = await processor.exportJpeg(adjusted, quality: 82);
    expect(jpeg.operation, 'Export JPEG');
    expect(jpeg.format, ImageClipOutputFormat.jpeg);
    expect(jpeg.mimeType, 'image/jpeg');
    expect(jpeg.bytes.sublist(0, 2), <int>[0xFF, 0xD8]);
  });

  test('bakes EXIF orientation when decoding image bytes', () async {
    final processor = ImageProcessor();
    final source = img.Image(width: 2, height: 3)
      ..exif.imageIfd.orientation = 6;

    final decoded = await processor.decodeBytes(
      img.encodeJpg(source),
      label: 'rotated.jpg',
    );

    expect(decoded.width, 3);
    expect(decoded.height, 2);
  });

  test('decodes common mobile EXIF orientation values', () async {
    final processor = ImageProcessor();

    for (final fixture in MobileImageFixtures.orientationCases) {
      final decoded = await processor.decodeBytes(
        fixture.bytes,
        label: fixture.label,
      );

      expect(decoded.width, fixture.expectedWidth, reason: fixture.label);
      expect(decoded.height, fixture.expectedHeight, reason: fixture.label);
    }
  });

  test('preserves transparent PNG pixels through decode and crop', () async {
    final processor = ImageProcessor();
    final decoded = await processor.decodeBytes(
      MobileImageFixtures.transparentPng(),
      label: 'transparent.png',
    );
    final cropped = await processor.cropRegion(
      decoded,
      const CropRegion(x: 1, y: 1, width: 2, height: 2, cornerRadius: 0),
    );
    final pixels = img.decodePng(cropped.bytes)!;

    expect(decoded.format, ImageClipOutputFormat.png);
    expect(cropped.width, 2);
    expect(cropped.height, 2);
    expect(pixels.getPixel(0, 0).a, 0);
    expect(pixels.getPixel(1, 1).a, greaterThan(0));
    expect(pixels.getPixel(1, 1).a, lessThan(255));
  });

  test('throws a typed exception for corrupt mobile image bytes', () {
    final processor = ImageProcessor();

    expect(
      processor.decodeBytes(
        MobileImageFixtures.corruptJpeg(),
        label: 'corrupt.jpg',
      ),
      throwsA(isA<ImageClipDecodeException>()),
    );
  });

  test('probes encoded image headers without full decoding', () {
    final processor = ImageProcessor();

    final png = processor.probeBytes(_pngHeader(width: 320, height: 180));
    expect(png.format, ImageClipEncodedFormat.png);
    expect(png.width, 320);
    expect(png.height, 180);
    expect(png.pixelCount, 57600);

    final jpeg = processor.probeBytes(_jpegHeader(width: 640, height: 480));
    expect(jpeg.format, ImageClipEncodedFormat.jpeg);
    expect(jpeg.dimensionsLabel, '640x480');

    final gif = processor.probeBytes(_gifHeader(width: 48, height: 32));
    expect(gif.format, ImageClipEncodedFormat.gif);
    expect(gif.width, 48);
    expect(gif.height, 32);

    final webp = processor.probeBytes(
      _webpVp8xHeader(width: 1024, height: 768),
    );
    expect(webp.format, ImageClipEncodedFormat.webp);
    expect(webp.width, 1024);
    expect(webp.height, 768);

    final unknown = processor.probeBytes(Uint8List.fromList(<int>[1, 2, 3]));
    expect(unknown.format, ImageClipEncodedFormat.unknown);
    expect(unknown.hasDimensions, isFalse);
  });

  test('runs multiple image operations as a single pipeline', () async {
    final processor = ImageProcessor();
    final source = img.Image(width: 400, height: 300);

    final result = await processor.processBytes(
      img.encodePng(source),
      label: 'pipeline.png',
      steps: const <ImageClipPipelineStep>[
        ImageClipPipelineStep.rotate(),
        ImageClipPipelineStep.cropRegion(
          CropRegion(x: 0, y: 0, width: 100, height: 200, cornerRadius: 0),
        ),
        ImageClipPipelineStep.resizeLongSide(160),
      ],
      outputSettings: const ImageClipOutputSettings.jpeg(jpegQuality: 80),
    );

    expect(result.operation, 'Pipeline');
    expect(result.label, 'pipeline.png');
    expect(result.width, 80);
    expect(result.height, 160);
    expect(result.format, ImageClipOutputFormat.jpeg);
    expect(result.bytes.sublist(0, 2), <int>[0xFF, 0xD8]);
  });

  test('processes existing EditedImage values through a pipeline', () async {
    final processor = ImageProcessor();
    final sample = await processor.createSample();

    final result = await processor.processPipeline(
      ImageClipPipeline.fromImage(
        source: sample,
        steps: const <ImageClipPipelineStep>[
          ImageClipPipelineStep.cropRegion(
            CropRegion(x: 120, y: 80, width: 300, height: 220, cornerRadius: 0),
          ),
          ImageClipPipelineStep.flipHorizontal(),
        ],
      ),
    );

    expect(result.operation, 'Pipeline');
    expect(result.label, sample.label);
    expect(result.width, 300);
    expect(result.height, 220);
    expect(result.bytes, isNotEmpty);
  });

  test('tracks current image state in an image clip session', () async {
    final processor = ImageProcessor();
    final sample = await processor.createSample();
    final session = ImageClipSession(image: sample, processor: processor);

    final rotated = await session.rotate();
    expect(rotated.width, 640);
    expect(rotated.height, 960);
    expect(session.image, same(rotated));
    expect(session.operationCount, 1);

    final cropped = await session.cropRegion(
      const CropRegion(x: 10, y: 20, width: 120, height: 160, cornerRadius: 0),
      outputSettings: const ImageClipOutputSettings.jpeg(jpegQuality: 84),
    );
    expect(cropped.width, 120);
    expect(cropped.height, 160);
    expect(cropped.format, ImageClipOutputFormat.jpeg);
    expect(session.image, same(cropped));
    expect(session.operationCount, 2);
  });

  test('cancels the active image clip session task', () async {
    final processor = _DelayedPipelineProcessor();
    final session = ImageClipSession(
      image: _editedImage('session.png', width: 80, height: 60),
      processor: processor,
    );

    final task = session.rotateTask();
    expect(session.isBusy, isTrue);
    expect(session.cancelTask(), isTrue);

    await expectLater(
      task.result,
      throwsA(isA<ImageClipTaskCanceledException>()),
    );
    expect(session.isBusy, isFalse);
    expect(session.image.label, 'session.png');
    expect(session.operationCount, 0);
  });

  test('emits progress events for pipeline tasks', () async {
    final processor = ImageProcessor();
    final source = img.Image(width: 120, height: 90);
    final progressEvents = <ImageClipTaskProgress>[];

    final result = await processor
        .processBytesTask(
          img.encodePng(source),
          label: 'progress.png',
          steps: const <ImageClipPipelineStep>[
            ImageClipPipelineStep.rotate(),
            ImageClipPipelineStep.cropRegion(
              CropRegion(x: 0, y: 0, width: 40, height: 60, cornerRadius: 0),
            ),
          ],
          options: ImageClipTaskOptions(onProgress: progressEvents.add),
        )
        .result;

    expect(result.bytes, isNotEmpty);
    expect(
      progressEvents.map((event) => event.stage),
      containsAll(<ImageClipTaskProgressStage>[
        ImageClipTaskProgressStage.decoding,
        ImageClipTaskProgressStage.processing,
        ImageClipTaskProgressStage.encoding,
        ImageClipTaskProgressStage.completed,
      ]),
    );
    expect(progressEvents.last.fraction, 1);
  });

  test('cancels image processing tasks', () async {
    final task = ImageClipTask<EditedImage>.fromFuture(
      Future<EditedImage>.delayed(
        const Duration(seconds: 5),
        () => throw StateError('should not complete'),
      ),
    );

    expect(task.cancel(), isTrue);
    await expectLater(
      task.result,
      throwsA(isA<ImageClipTaskCanceledException>()),
    );
    expect(task.isCanceled, isTrue);
  });

  test('times out image processing tasks', () async {
    final completer = Completer<EditedImage>();
    final task = ImageClipTask<EditedImage>.fromFuture(
      completer.future,
      options: const ImageClipTaskOptions(timeout: Duration(milliseconds: 10)),
    );

    await expectLater(
      task.result,
      throwsA(isA<ImageClipTaskTimeoutException>()),
    );
    expect(task.isCanceled, isTrue);
  });

  test(
    'downscales decoded images to the configured output pixel limit',
    () async {
      const settings = ImageClipProcessingSettings(maxOutputPixels: 25);
      final processor = ImageProcessor(processingSettings: settings);
      final source = img.Image(width: 10, height: 10);

      final decoded = await processor.decodeBytes(
        img.encodePng(source),
        label: 'large.png',
      );

      expect(decoded.width * decoded.height, lessThanOrEqualTo(25));
      expect(decoded.width, 5);
      expect(decoded.height, 5);
    },
  );

  test('throws a typed exception when input image exceeds pixel limit', () {
    const settings = ImageClipProcessingSettings(maxInputPixels: 50);
    final processor = ImageProcessor(processingSettings: settings);
    final source = img.Image(width: 10, height: 10);

    expect(
      processor.decodeBytes(img.encodePng(source), label: 'too-large.png'),
      throwsA(isA<ImageClipImageTooLargeException>()),
    );
  });

  test('rejects oversized PNG input from its header before full decode', () {
    const settings = ImageClipProcessingSettings(maxInputPixels: 1000);
    final processor = ImageProcessor(processingSettings: settings);

    expect(
      processor.decodeBytes(
        _pngHeader(width: 10000, height: 10000),
        label: 'huge.png',
      ),
      throwsA(isA<ImageClipImageTooLargeException>()),
    );
  });

  test('throws a typed exception for invalid crop regions', () async {
    final processor = ImageProcessor();
    final sample = await processor.createSample();

    expect(
      processor.cropRegion(
        sample,
        const CropRegion(x: 0, y: 0, width: 0, height: 100, cornerRadius: 0),
      ),
      throwsA(isA<ImageClipInvalidCropRegionException>()),
    );
  });
}

Uint8List _pngHeader({required int width, required int height}) {
  final bytes = Uint8List(24);
  bytes.setAll(0, <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  _writeUint32be(bytes, 8, 13);
  bytes.setAll(12, 'IHDR'.codeUnits);
  _writeUint32be(bytes, 16, width);
  _writeUint32be(bytes, 20, height);
  return bytes;
}

Uint8List _jpegHeader({required int width, required int height}) {
  return Uint8List.fromList(<int>[
    0xFF,
    0xD8,
    0xFF,
    0xC0,
    0x00,
    0x11,
    0x08,
    (height >> 8) & 0xFF,
    height & 0xFF,
    (width >> 8) & 0xFF,
    width & 0xFF,
    0x03,
    0x01,
    0x11,
    0x00,
    0x02,
    0x11,
    0x00,
    0x03,
    0x11,
    0x00,
    0xFF,
    0xD9,
  ]);
}

Uint8List _gifHeader({required int width, required int height}) {
  return Uint8List.fromList(<int>[
    ...'GIF89a'.codeUnits,
    width & 0xFF,
    (width >> 8) & 0xFF,
    height & 0xFF,
    (height >> 8) & 0xFF,
  ]);
}

Uint8List _webpVp8xHeader({required int width, required int height}) {
  final bytes = Uint8List(30);
  bytes.setAll(0, 'RIFF'.codeUnits);
  _writeUint32le(bytes, 4, 22);
  bytes.setAll(8, 'WEBP'.codeUnits);
  bytes.setAll(12, 'VP8X'.codeUnits);
  _writeUint32le(bytes, 16, 10);
  _writeUint24le(bytes, 24, width - 1);
  _writeUint24le(bytes, 27, height - 1);
  return bytes;
}

void _writeUint32be(Uint8List bytes, int offset, int value) {
  bytes[offset] = (value >> 24) & 0xFF;
  bytes[offset + 1] = (value >> 16) & 0xFF;
  bytes[offset + 2] = (value >> 8) & 0xFF;
  bytes[offset + 3] = value & 0xFF;
}

void _writeUint32le(Uint8List bytes, int offset, int value) {
  bytes[offset] = value & 0xFF;
  bytes[offset + 1] = (value >> 8) & 0xFF;
  bytes[offset + 2] = (value >> 16) & 0xFF;
  bytes[offset + 3] = (value >> 24) & 0xFF;
}

void _writeUint24le(Uint8List bytes, int offset, int value) {
  bytes[offset] = value & 0xFF;
  bytes[offset + 1] = (value >> 8) & 0xFF;
  bytes[offset + 2] = (value >> 16) & 0xFF;
}

EditedImage _editedImage(
  String label, {
  required int width,
  required int height,
}) {
  return EditedImage(
    bytes: Uint8List.fromList(
      img.encodePng(img.Image(width: width, height: height)),
    ),
    width: width,
    height: height,
    label: label,
    operation: 'Fixture',
    elapsedMs: 1,
  );
}

class _DelayedPipelineProcessor extends ImageProcessor {
  @override
  ImageClipTask<EditedImage> processPipelineTask(
    ImageClipPipeline pipeline, {
    ImageClipTaskOptions? options,
  }) {
    return ImageClipTask<EditedImage>.fromFuture(
      Future<EditedImage>.delayed(
        const Duration(seconds: 5),
        () => _editedImage('late.png', width: 20, height: 20),
      ),
      options: options,
    );
  }
}
