import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'exceptions.dart';
import 'models.dart';
import 'pipeline.dart';

export 'exceptions.dart';
export 'models.dart';
export 'pipeline.dart';

part 'image_job.dart';
part 'image_operations.dart';
part 'sample_image.dart';
part 'tasks.dart';

/// Performs image decoding and transformations on a background isolate.
class ImageProcessor {
  /// Creates an image processor.
  const ImageProcessor({
    this.processingSettings = const ImageClipProcessingSettings(),
  });

  /// Runtime guardrails used for decode and output processing.
  final ImageClipProcessingSettings processingSettings;

  /// Creates a generated sample image for demos and tests.
  Future<EditedImage> createSample({ImageClipTaskOptions? options}) {
    return createSampleTask(options: options).result;
  }

  /// Starts generating a sample image as a cancelable task.
  ImageClipTask<EditedImage> createSampleTask({ImageClipTaskOptions? options}) {
    return _start(<String, Object?>{
      'kind': 'sample',
      'label': 'Sample image',
    }, options: options);
  }

  /// Decodes encoded image [bytes] into a normalized PNG [EditedImage].
  Future<EditedImage> decodeBytes(
    Uint8List bytes, {
    required String label,
    ImageClipTaskOptions? options,
  }) {
    return decodeBytesTask(bytes, label: label, options: options).result;
  }

  /// Starts decoding encoded image [bytes] as a cancelable task.
  ImageClipTask<EditedImage> decodeBytesTask(
    Uint8List bytes, {
    required String label,
    ImageClipTaskOptions? options,
  }) {
    return processPipelineTask(
      ImageClipPipeline.decode(
        bytes: bytes,
        label: label,
        operationLabel: 'Decode',
      ),
      options: options,
    );
  }

  /// Runs [pipeline] as a single background image job.
  ///
  /// Unlike chaining single-operation methods, a pipeline decodes the source
  /// image once, applies all steps in order, and encodes only the final result.
  Future<EditedImage> processPipeline(
    ImageClipPipeline pipeline, {
    ImageClipTaskOptions? options,
  }) {
    return processPipelineTask(pipeline, options: options).result;
  }

  /// Starts [pipeline] as a cancelable background image task.
  ImageClipTask<EditedImage> processPipelineTask(
    ImageClipPipeline pipeline, {
    ImageClipTaskOptions? options,
  }) {
    return _start(<String, Object?>{
      'kind': 'pipeline',
      'pipeline': pipeline.toMap(),
    }, options: options);
  }

  /// Decodes [bytes], applies [steps], and encodes the final result.
  Future<EditedImage> processBytes(
    Uint8List bytes, {
    required String label,
    List<ImageClipPipelineStep> steps = const <ImageClipPipelineStep>[],
    ImageClipOutputSettings outputSettings =
        const ImageClipOutputSettings.png(),
    String? operationLabel,
    ImageClipTaskOptions? options,
  }) {
    return processBytesTask(
      bytes,
      label: label,
      steps: steps,
      outputSettings: outputSettings,
      operationLabel: operationLabel,
      options: options,
    ).result;
  }

  /// Starts decoding [bytes] and applying [steps] as a cancelable task.
  ImageClipTask<EditedImage> processBytesTask(
    Uint8List bytes, {
    required String label,
    List<ImageClipPipelineStep> steps = const <ImageClipPipelineStep>[],
    ImageClipOutputSettings outputSettings =
        const ImageClipOutputSettings.png(),
    String? operationLabel,
    ImageClipTaskOptions? options,
  }) {
    return processPipelineTask(
      ImageClipPipeline.decode(
        bytes: bytes,
        label: label,
        steps: steps,
        outputSettings: outputSettings,
        operationLabel: operationLabel,
      ),
      options: options,
    );
  }

  /// Crops the center of [source] using relative [settings].
  Future<EditedImage> cropCenter(
    EditedImage source,
    CropSettings settings, {
    ImageClipOutputSettings outputSettings =
        const ImageClipOutputSettings.png(),
    ImageClipTaskOptions? options,
  }) {
    return processPipeline(
      ImageClipPipeline.fromImage(
        source: source,
        steps: <ImageClipPipelineStep>[
          ImageClipPipelineStep.cropCenter(settings),
        ],
        outputSettings: outputSettings,
        operationLabel: 'Crop',
      ),
      options: options,
    );
  }

  /// Crops [source] to an explicit pixel [region].
  Future<EditedImage> cropRegion(
    EditedImage source,
    CropRegion region, {
    ImageClipOutputSettings outputSettings =
        const ImageClipOutputSettings.png(),
    ImageClipTaskOptions? options,
  }) {
    return cropRegionTask(
      source,
      region,
      outputSettings: outputSettings,
      options: options,
    ).result;
  }

  /// Starts cropping [source] to an explicit pixel [region].
  ImageClipTask<EditedImage> cropRegionTask(
    EditedImage source,
    CropRegion region, {
    ImageClipOutputSettings outputSettings =
        const ImageClipOutputSettings.png(),
    ImageClipTaskOptions? options,
  }) {
    return processPipelineTask(
      ImageClipPipeline.fromImage(
        source: source,
        steps: <ImageClipPipelineStep>[
          ImageClipPipelineStep.cropRegion(region),
        ],
        outputSettings: outputSettings,
        operationLabel: 'Crop region',
      ),
      options: options,
    );
  }

  /// Rotates [source] clockwise by [degrees].
  Future<EditedImage> rotate(
    EditedImage source, {
    int degrees = 90,
    ImageClipTaskOptions? options,
  }) {
    return rotateTask(source, degrees: degrees, options: options).result;
  }

  /// Starts rotating [source] clockwise by [degrees].
  ImageClipTask<EditedImage> rotateTask(
    EditedImage source, {
    int degrees = 90,
    ImageClipTaskOptions? options,
  }) {
    return processPipelineTask(
      ImageClipPipeline.fromImage(
        source: source,
        steps: <ImageClipPipelineStep>[
          ImageClipPipelineStep.rotate(degrees: degrees),
        ],
        operationLabel: 'Rotate',
      ),
      options: options,
    );
  }

  /// Rotates [source] clockwise by 90 degrees.
  Future<EditedImage> rotateRight(
    EditedImage source, {
    ImageClipTaskOptions? options,
  }) {
    return rotate(source, options: options);
  }

  /// Starts rotating [source] clockwise by 90 degrees.
  ImageClipTask<EditedImage> rotateRightTask(
    EditedImage source, {
    ImageClipTaskOptions? options,
  }) {
    return rotateTask(source, options: options);
  }

  /// Flips [source] around the vertical axis.
  Future<EditedImage> flipHorizontal(
    EditedImage source, {
    ImageClipTaskOptions? options,
  }) {
    return processPipeline(
      ImageClipPipeline.fromImage(
        source: source,
        steps: const <ImageClipPipelineStep>[
          ImageClipPipelineStep.flipHorizontal(),
        ],
        operationLabel: 'Flip horizontal',
      ),
      options: options,
    );
  }

  /// Flips [source] around the horizontal axis.
  Future<EditedImage> flipVertical(
    EditedImage source, {
    ImageClipTaskOptions? options,
  }) {
    return processPipeline(
      ImageClipPipeline.fromImage(
        source: source,
        steps: const <ImageClipPipelineStep>[
          ImageClipPipelineStep.flipVertical(),
        ],
        operationLabel: 'Flip vertical',
      ),
      options: options,
    );
  }

  /// Resizes [source] so its longest side is [maxSide] pixels.
  Future<EditedImage> resizeLongSide(
    EditedImage source,
    int maxSide, {
    ImageClipTaskOptions? options,
  }) {
    return processPipeline(
      ImageClipPipeline.fromImage(
        source: source,
        steps: <ImageClipPipelineStep>[
          ImageClipPipelineStep.resizeLongSide(maxSide),
        ],
        operationLabel: 'Resize',
      ),
      options: options,
    );
  }

  /// Applies brightness, contrast, and saturation multipliers to [source].
  Future<EditedImage> adjustColor(
    EditedImage source,
    ColorAdjustment adjustment, {
    ImageClipTaskOptions? options,
  }) {
    return processPipeline(
      ImageClipPipeline.fromImage(
        source: source,
        steps: <ImageClipPipelineStep>[
          ImageClipPipelineStep.adjustColor(adjustment),
        ],
        operationLabel: 'Adjust color',
      ),
      options: options,
    );
  }

  /// Re-encodes [source] using [outputSettings].
  Future<EditedImage> exportImage(
    EditedImage source, {
    ImageClipOutputSettings outputSettings =
        const ImageClipOutputSettings.png(),
    ImageClipTaskOptions? options,
  }) {
    return processPipeline(
      ImageClipPipeline.fromImage(
        source: source,
        outputSettings: outputSettings,
        operationLabel: 'Export ${outputSettings.format.name.toUpperCase()}',
      ),
      options: options,
    );
  }

  /// Re-encodes [source] as a PNG [EditedImage].
  Future<EditedImage> exportPng(
    EditedImage source, {
    ImageClipTaskOptions? options,
  }) {
    return exportImage(source, options: options);
  }

  /// Re-encodes [source] as a JPEG [EditedImage].
  Future<EditedImage> exportJpeg(
    EditedImage source, {
    int quality = 90,
    ImageClipTaskOptions? options,
  }) {
    return exportImage(
      source,
      outputSettings: ImageClipOutputSettings.jpeg(jpegQuality: quality),
      options: options,
    );
  }

  ImageClipTask<EditedImage> _start(
    Map<String, Object?> request, {
    ImageClipTaskOptions? options,
  }) {
    final payload = <String, Object?>{
      ...request,
      'processing': processingSettings.toMap(),
    };
    return ImageClipTask._start(payload, options: options);
  }
}
