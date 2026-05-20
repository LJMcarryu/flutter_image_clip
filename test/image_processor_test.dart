import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
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

  test('decodes preview images with source dimensions preserved', () async {
    final processor = ImageProcessor();

    final preview = await processor.decodePreviewBytes(
      img.encodePng(img.Image(width: 800, height: 400)),
      label: 'preview.png',
      targetLongSide: 200,
    );

    expect(preview.width, 200);
    expect(preview.height, 100);
    expect(preview.sourceWidth, 800);
    expect(preview.sourceHeight, 400);
    expect(preview.isPreviewSized, isTrue);
  });

  test('normalizes image bytes through a decode adapter', () async {
    final adapter = _FixtureDecodeAdapter(
      bytes: Uint8List.fromList(
        img.encodePng(img.Image(width: 32, height: 18)),
      ),
      sourceWidth: 640,
      sourceHeight: 360,
    );
    final processor = ImageProcessor(decodeAdapter: adapter);

    final decoded = await processor.decodeBytes(
      Uint8List.fromList(<int>[1, 2, 3, 4]),
      label: 'native.heic',
    );

    expect(adapter.callCount, 1);
    expect(decoded.width, 32);
    expect(decoded.height, 18);
    expect(decoded.sourceWidth, 640);
    expect(decoded.sourceHeight, 360);
    expect(decoded.isPreviewSized, isTrue);
  });

  test('normalizes image bytes through the platform decode adapter', () async {
    const channel = MethodChannel('flutter_image_clip/decode_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'decode');
          return <String, Object?>{
            'bytes': Uint8List.fromList(
              img.encodePng(img.Image(width: 24, height: 12)),
            ),
            'sourceWidth': 240,
            'sourceHeight': 120,
          };
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final processor = ImageProcessor(
      decodeAdapter: const ImageClipPlatformDecodeAdapter(channel: channel),
    );
    final decoded = await processor.decodeBytes(
      Uint8List.fromList(img.encodePng(img.Image(width: 240, height: 120))),
      label: 'platform.png',
      decodeSettings: const ImageClipDecodeSettings.preview(targetLongSide: 24),
    );

    expect(decoded.width, 24);
    expect(decoded.height, 12);
    expect(decoded.sourceWidth, 240);
    expect(decoded.sourceHeight, 120);
  });

  test('maps platform unsupported format errors to typed exceptions', () async {
    const channel = MethodChannel('flutter_image_clip/decode_unsupported_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          throw PlatformException(
            code: 'unsupported_format',
            message: 'Unsupported image format',
          );
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final processor = ImageProcessor(
      decodeAdapter: const ImageClipPlatformDecodeAdapter(channel: channel),
    );

    await expectLater(
      processor.decodeBytes(
        Uint8List.fromList(img.encodePng(img.Image(width: 240, height: 120))),
        label: 'platform.png',
        decodeSettings: const ImageClipDecodeSettings.preview(
          targetLongSide: 24,
        ),
      ),
      throwsA(isA<ImageClipUnsupportedFormatException>()),
    );
  });

  test('maps platform argument errors to adapter exceptions', () async {
    const channel = MethodChannel('flutter_image_clip/decode_args_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          throw PlatformException(
            code: 'invalid_args',
            message: 'Image bytes are required',
          );
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final processor = ImageProcessor(
      decodeAdapter: const ImageClipPlatformDecodeAdapter(channel: channel),
    );

    await expectLater(
      processor.decodeBytes(
        Uint8List.fromList(img.encodePng(img.Image(width: 240, height: 120))),
        label: 'platform.png',
        decodeSettings: const ImageClipDecodeSettings.preview(
          targetLongSide: 24,
        ),
      ),
      throwsA(isA<ImageClipPlatformException>()),
    );
  });

  test('maps platform decode failures to decode exceptions', () async {
    const channel = MethodChannel('flutter_image_clip/decode_failed_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          throw PlatformException(
            code: 'decode_failed',
            message: 'Unable to decode image',
          );
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final processor = ImageProcessor(
      decodeAdapter: const ImageClipPlatformDecodeAdapter(channel: channel),
    );

    await expectLater(
      processor.decodeBytes(
        Uint8List.fromList(img.encodePng(img.Image(width: 240, height: 120))),
        label: 'platform.png',
        decodeSettings: const ImageClipDecodeSettings.preview(
          targetLongSide: 24,
        ),
      ),
      throwsA(isA<ImageClipDecodeException>()),
    );
  });

  test('forwards progress from adapter-backed pipeline tasks', () async {
    final adapter = _FixtureDecodeAdapter(
      bytes: Uint8List.fromList(
        img.encodePng(img.Image(width: 80, height: 60)),
      ),
      sourceWidth: 800,
      sourceHeight: 600,
    );
    final processor = ImageProcessor(decodeAdapter: adapter);
    final task = processor.processBytesTask(
      Uint8List.fromList(<int>[1, 2, 3, 4]),
      label: 'native.heic',
      steps: const <ImageClipPipelineStep>[
        ImageClipPipelineStep.rotate(),
        ImageClipPipelineStep.cropRegion(
          CropRegion(x: 0, y: 0, width: 40, height: 60, cornerRadius: 0),
        ),
      ],
    );
    final progressEvents = <ImageClipTaskProgress>[];
    final subscription = task.progress.listen(progressEvents.add);

    final result = await task.result;
    await subscription.cancel();

    expect(result.bytes, isNotEmpty);
    expect(adapter.callCount, 1);
    expect(
      progressEvents.map((event) => event.stage),
      containsAll(<ImageClipTaskProgressStage>[
        ImageClipTaskProgressStage.decoding,
        ImageClipTaskProgressStage.processing,
        ImageClipTaskProgressStage.encoding,
        ImageClipTaskProgressStage.completed,
      ]),
    );
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

    final heic = processor.probeBytes(_heicHeader());
    expect(heic.format, ImageClipEncodedFormat.heic);
    expect(heic.canDecodeWithDart, isFalse);

    final unknown = processor.probeBytes(Uint8List.fromList(<int>[1, 2, 3]));
    expect(unknown.format, ImageClipEncodedFormat.unknown);
    expect(unknown.hasDimensions, isFalse);
  });

  test('throws a typed exception for HEIC bytes', () {
    final processor = ImageProcessor();

    expect(
      processor.decodeBytes(_heicHeader(), label: 'photo.heic'),
      throwsA(isA<ImageClipUnsupportedFormatException>()),
    );
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

  test('processes image files inside the worker isolate', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'flutter_image_clip_test_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });
    final input = File('${tempDir.path}/source.png');
    await input.writeAsBytes(
      img.encodePng(img.Image(width: 160, height: 120)),
      flush: true,
    );

    final processor = ImageProcessor();
    final result = await processor.processFile(
      input.path,
      steps: const <ImageClipPipelineStep>[
        ImageClipPipelineStep.cropRegion(
          CropRegion(x: 10, y: 10, width: 80, height: 60, cornerRadius: 0),
        ),
      ],
      outputSettings: const ImageClipOutputSettings.jpeg(jpegQuality: 82),
    );
    final output = await processor.writeImageToFile(
      result,
      '${tempDir.path}/result.${result.fileExtension}',
    );

    expect(result.label, 'source.png');
    expect(result.width, 80);
    expect(result.height, 60);
    expect(result.format, ImageClipOutputFormat.jpeg);
    expect(await output.length(), result.bytes.length);
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

  test('maps transformed preview crop rectangles back to source pixels', () {
    const previewRegion = CropRegion(
      x: 10,
      y: 20,
      width: 30,
      height: 40,
      cornerRadius: 2,
    );
    const transform = ImageClipCropTransform(
      rotationDegrees: 90,
      flipHorizontal: true,
    );

    expect(
      transform.visualSize(sourceWidth: 100, sourceHeight: 80),
      const ImageClipDimensions(width: 80, height: 100),
    );

    final sourceRegion = transform.sourceRegionForPreview(
      sourceWidth: 100,
      sourceHeight: 80,
      previewRegion: previewRegion,
    );

    expect(sourceRegion.x, 20);
    expect(sourceRegion.y, 10);
    expect(sourceRegion.width, 40);
    expect(sourceRegion.height, 30);
    expect(sourceRegion.cornerRadius, 2);
  });

  test('crop transforms cover quarter-turn, flip, and bounded regions', () {
    expect(
      const ImageClipCropTransform(rotationDegrees: -90).normalizedRotation,
      270,
    );
    expect(
      const ImageClipCropTransform(rotationDegrees: 180).sourceRegionForPreview(
        sourceWidth: 120,
        sourceHeight: 100,
        previewRegion: const CropRegion(
          x: 90,
          y: 70,
          width: 30,
          height: 20,
          cornerRadius: 4,
        ),
      ),
      const CropRegion(x: 0, y: 10, width: 30, height: 20, cornerRadius: 4),
    );
    expect(
      const ImageClipCropTransform(
        rotationDegrees: 270,
        flipVertical: true,
      ).sourceRegionForPreview(
        sourceWidth: 100,
        sourceHeight: 80,
        previewRegion: const CropRegion(
          x: 10,
          y: 20,
          width: 30,
          height: 40,
          cornerRadius: 3,
        ),
      ),
      const CropRegion(x: 20, y: 10, width: 40, height: 30, cornerRadius: 3),
    );
    expect(
      const ImageClipCropTransform().sourceRegionForPreview(
        sourceWidth: 20,
        sourceHeight: 10,
        previewRegion: const CropRegion(
          x: -8,
          y: -6,
          width: 80,
          height: 40,
          cornerRadius: 0,
        ),
      ),
      const CropRegion(x: 0, y: 0, width: 20, height: 10, cornerRadius: 0),
    );
    expect(
      () => const ImageClipCropTransform(rotationDegrees: 45).quarterTurns,
      throwsA(isA<ArgumentError>()),
    );
    expect(
      const ImageClipCropTransform().copyWith(flipHorizontal: true),
      const ImageClipCropTransform(flipHorizontal: true),
    );
  });

  test('crop regions and settings support stable map/copy helpers', () {
    const region = CropRegion(
      x: 4,
      y: 8,
      width: 20,
      height: 30,
      cornerRadius: 2,
    );
    final restored = CropRegion.fromMap(region.toMap());
    const cropSettings = CropSettings(
      widthRatio: 0.6,
      heightRatio: 0.5,
      cornerRadius: 4,
    );
    const colorAdjustment = ColorAdjustment(
      brightness: 1.1,
      contrast: 0.9,
      saturation: 1.2,
    );

    expect(restored, region);
    expect(region.copyWith(width: 24).width, 24);
    expect(CropSettings.fromMap(cropSettings.toMap()), cropSettings);
    expect(cropSettings.copyWith(widthRatio: 0.7).widthRatio, 0.7);
    expect(
      CropSettings.fromMap(<Object?, Object?>{'widthRatio': 'invalid'}),
      const CropSettings(widthRatio: 0.75, heightRatio: 0.75, cornerRadius: 0),
    );
    expect(ColorAdjustment.fromMap(colorAdjustment.toMap()), colorAdjustment);
    expect(colorAdjustment.copyWith(saturation: 0.8).saturation, 0.8);
    expect(
      ColorAdjustment.fromMap(<Object?, Object?>{'contrast': 'invalid'}),
      const ColorAdjustment(brightness: 1, contrast: 1, saturation: 1),
    );
    expect(
      const ImageClipOutputSettings.jpeg(
        jpegQuality: 80,
      ).copyWith(jpegQuality: 88),
      const ImageClipOutputSettings.jpeg(jpegQuality: 88),
    );
    expect(
      const ImageClipDecodeSettings.preview(
        targetLongSide: 512,
      ).copyWith(clearTargetLongSide: true).targetLongSide,
      isNull,
    );
  });

  test('task progress helpers are stable for UI state', () {
    const progress = ImageClipTaskProgress(
      stage: ImageClipTaskProgressStage.processing,
      completedSteps: 12,
      totalSteps: 10,
      message: 'Processing',
    );
    const sameProgress = ImageClipTaskProgress(
      stage: ImageClipTaskProgressStage.processing,
      completedSteps: 12,
      totalSteps: 10,
      message: 'Processing',
    );
    const completed = ImageClipTaskProgress(
      stage: ImageClipTaskProgressStage.completed,
      completedSteps: 1,
      totalSteps: 1,
      message: 'Completed',
    );

    expect(progress.fraction, 0.85);
    expect(progress.isCompleted, isFalse);
    expect(progress, sameProgress);
    expect(progress.hashCode, sameProgress.hashCode);
    expect(progress.toString(), contains('Processing'));
    expect(completed.fraction, 1);
    expect(completed.isCompleted, isTrue);
  });

  test('single rotate and flip operations can export JPEG directly', () async {
    final processor = ImageProcessor();
    final source = await processor.decodeBytes(
      img.encodePng(img.Image(width: 40, height: 30)),
      label: 'single-step.png',
    );

    final rotated = await processor.rotateRight(
      source,
      outputSettings: const ImageClipOutputSettings.jpeg(jpegQuality: 82),
    );
    final flipped = await processor.flipHorizontal(
      source,
      outputSettings: const ImageClipOutputSettings.jpeg(jpegQuality: 82),
    );
    final vertical = await processor
        .flipVerticalTask(
          source,
          outputSettings: const ImageClipOutputSettings.jpeg(jpegQuality: 82),
        )
        .result;

    expect(rotated.format, ImageClipOutputFormat.jpeg);
    expect(rotated.bytes.sublist(0, 2), <int>[0xFF, 0xD8]);
    expect(flipped.format, ImageClipOutputFormat.jpeg);
    expect(flipped.bytes.sublist(0, 2), <int>[0xFF, 0xD8]);
    expect(vertical.format, ImageClipOutputFormat.jpeg);
    expect(vertical.bytes.sublist(0, 2), <int>[0xFF, 0xD8]);
  });

  test('tracks current image state in an image clip session', () async {
    final processor = ImageProcessor();
    final sample = await processor.createSample();
    final session = ImageClipSession(image: sample, processor: processor);

    final rotated = await session.rotate(
      outputSettings: const ImageClipOutputSettings.jpeg(jpegQuality: 84),
    );
    expect(rotated.width, 640);
    expect(rotated.height, 960);
    expect(rotated.format, ImageClipOutputFormat.jpeg);
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

  test('replacing a session image cancels stale work', () async {
    final processor = _DelayedPipelineProcessor();
    final initial = _editedImage('initial.png', width: 80, height: 60);
    final replacement = _editedImage('replacement.png', width: 40, height: 30);
    final session = ImageClipSession(image: initial, processor: processor);

    final task = session.rotateTask();
    expect(session.isBusy, isTrue);

    session.replaceImage(replacement);

    await expectLater(
      task.result,
      throwsA(isA<ImageClipTaskCanceledException>()),
    );
    expect(session.isBusy, isFalse);
    expect(session.image, same(replacement));
    expect(session.operationCount, 0);
  });

  test('session failures keep the current image unchanged', () async {
    final source = _editedImage('source.png', width: 80, height: 60);
    final session = ImageClipSession(image: source);

    final task = session.cropRegionTask(
      const CropRegion(x: 0, y: 0, width: 0, height: 20, cornerRadius: 0),
    );

    await expectLater(
      task.result,
      throwsA(isA<ImageClipInvalidCropRegionException>()),
    );
    await Future<void>.delayed(Duration.zero);
    expect(session.isBusy, isFalse);
    expect(session.image, same(source));
    expect(session.operationCount, 0);
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

  test('keeps decoded pixels between decoded session operations', () {
    final source = img.Image(width: 80, height: 60);
    final session = ImageClipDecodedSession.decode(
      Uint8List.fromList(img.encodePng(source)),
      label: 'decoded.png',
    );

    session.rotate();
    expect(session.width, 60);
    expect(session.height, 80);

    session.cropRegion(
      const CropRegion(x: 4, y: 6, width: 30, height: 40, cornerRadius: 0),
    );
    expect(session.width, 30);
    expect(session.height, 40);
    expect(session.operationCount, 2);

    final exported = session.exportImage(
      outputSettings: const ImageClipOutputSettings.jpeg(jpegQuality: 80),
    );
    expect(exported.width, 30);
    expect(exported.height, 40);
    expect(exported.format, ImageClipOutputFormat.jpeg);
    expect(exported.bytes.sublist(0, 2), <int>[0xFF, 0xD8]);
  });

  test('decoded sessions support all in-memory edit helpers', () async {
    final processor = ImageProcessor();
    final source = await processor.decodeBytes(
      img.encodePng(img.Image(width: 256, height: 128)),
      label: 'decoded-source.png',
    );
    final session = ImageClipDecodedSession.fromEditedImage(source);

    session.flipHorizontal();
    session.flipVertical();
    session.resizeLongSide(128);
    session.adjustColor(
      const ColorAdjustment(brightness: 1.05, contrast: 0.95, saturation: 1.1),
    );

    final exported = session.exportImage(operationLabel: 'Use decoded pixels');

    expect(session.operationCount, 4);
    expect(session.width, 128);
    expect(session.height, 64);
    expect(exported.label, 'decoded-source.png');
    expect(exported.operation, 'Use decoded pixels');
    expect(exported.format, ImageClipOutputFormat.png);
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

Uint8List _heicHeader() {
  return Uint8List.fromList(<int>[
    0x00,
    0x00,
    0x00,
    0x18,
    ...'ftyp'.codeUnits,
    ...'heic'.codeUnits,
    0x00,
    0x00,
    0x00,
    0x00,
    ...'mif1'.codeUnits,
    ...'heic'.codeUnits,
  ]);
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

class _FixtureDecodeAdapter extends ImageClipDecodeAdapter {
  _FixtureDecodeAdapter({
    required this.bytes,
    required this.sourceWidth,
    required this.sourceHeight,
  });

  final Uint8List bytes;
  final int sourceWidth;
  final int sourceHeight;

  int callCount = 0;

  @override
  bool supports(ImageClipImageInfo info) => true;

  @override
  Future<ImageClipDecodeAdapterResult?> decode(
    Uint8List bytes, {
    required ImageClipImageInfo info,
    required String label,
    required ImageClipDecodeSettings settings,
  }) async {
    callCount++;
    return ImageClipDecodeAdapterResult(
      bytes: this.bytes,
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
    );
  }
}
