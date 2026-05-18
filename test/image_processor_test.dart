import 'package:flutter_image_clip/flutter_image_clip.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

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
