import 'dart:math' as math;

import 'package:flutter/foundation.dart';
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

/// Performs image decoding and transformations on a background isolate.
class ImageProcessor {
  /// Creates an image processor.
  const ImageProcessor({
    this.processingSettings = const ImageClipProcessingSettings(),
  });

  /// Runtime guardrails used for decode and output processing.
  final ImageClipProcessingSettings processingSettings;

  /// Creates a generated sample image for demos and tests.
  Future<EditedImage> createSample() =>
      _run(<String, Object?>{'kind': 'sample', 'label': 'Sample image'});

  /// Decodes encoded image [bytes] into a normalized PNG [EditedImage].
  Future<EditedImage> decodeBytes(Uint8List bytes, {required String label}) {
    return processPipeline(
      ImageClipPipeline.decode(
        bytes: bytes,
        label: label,
        operationLabel: 'Decode',
      ),
    );
  }

  /// Runs [pipeline] as a single background image job.
  ///
  /// Unlike chaining single-operation methods, a pipeline decodes the source
  /// image once, applies all steps in order, and encodes only the final result.
  Future<EditedImage> processPipeline(ImageClipPipeline pipeline) {
    return _run(<String, Object?>{
      'kind': 'pipeline',
      'pipeline': pipeline.toMap(),
    });
  }

  /// Decodes [bytes], applies [steps], and encodes the final result.
  Future<EditedImage> processBytes(
    Uint8List bytes, {
    required String label,
    List<ImageClipPipelineStep> steps = const <ImageClipPipelineStep>[],
    ImageClipOutputSettings outputSettings =
        const ImageClipOutputSettings.png(),
    String? operationLabel,
  }) {
    return processPipeline(
      ImageClipPipeline.decode(
        bytes: bytes,
        label: label,
        steps: steps,
        outputSettings: outputSettings,
        operationLabel: operationLabel,
      ),
    );
  }

  /// Crops the center of [source] using relative [settings].
  Future<EditedImage> cropCenter(
    EditedImage source,
    CropSettings settings, {
    ImageClipOutputSettings outputSettings =
        const ImageClipOutputSettings.png(),
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
    );
  }

  /// Crops [source] to an explicit pixel [region].
  Future<EditedImage> cropRegion(
    EditedImage source,
    CropRegion region, {
    ImageClipOutputSettings outputSettings =
        const ImageClipOutputSettings.png(),
  }) {
    return processPipeline(
      ImageClipPipeline.fromImage(
        source: source,
        steps: <ImageClipPipelineStep>[
          ImageClipPipelineStep.cropRegion(region),
        ],
        outputSettings: outputSettings,
        operationLabel: 'Crop region',
      ),
    );
  }

  /// Rotates [source] clockwise by [degrees].
  Future<EditedImage> rotate(EditedImage source, {int degrees = 90}) {
    return processPipeline(
      ImageClipPipeline.fromImage(
        source: source,
        steps: <ImageClipPipelineStep>[
          ImageClipPipelineStep.rotate(degrees: degrees),
        ],
        operationLabel: 'Rotate',
      ),
    );
  }

  /// Rotates [source] clockwise by 90 degrees.
  Future<EditedImage> rotateRight(EditedImage source) => rotate(source);

  /// Flips [source] around the vertical axis.
  Future<EditedImage> flipHorizontal(EditedImage source) {
    return processPipeline(
      ImageClipPipeline.fromImage(
        source: source,
        steps: const <ImageClipPipelineStep>[
          ImageClipPipelineStep.flipHorizontal(),
        ],
        operationLabel: 'Flip horizontal',
      ),
    );
  }

  /// Flips [source] around the horizontal axis.
  Future<EditedImage> flipVertical(EditedImage source) {
    return processPipeline(
      ImageClipPipeline.fromImage(
        source: source,
        steps: const <ImageClipPipelineStep>[
          ImageClipPipelineStep.flipVertical(),
        ],
        operationLabel: 'Flip vertical',
      ),
    );
  }

  /// Resizes [source] so its longest side is [maxSide] pixels.
  Future<EditedImage> resizeLongSide(EditedImage source, int maxSide) {
    return processPipeline(
      ImageClipPipeline.fromImage(
        source: source,
        steps: <ImageClipPipelineStep>[
          ImageClipPipelineStep.resizeLongSide(maxSide),
        ],
        operationLabel: 'Resize',
      ),
    );
  }

  /// Applies brightness, contrast, and saturation multipliers to [source].
  Future<EditedImage> adjustColor(
    EditedImage source,
    ColorAdjustment adjustment,
  ) {
    return processPipeline(
      ImageClipPipeline.fromImage(
        source: source,
        steps: <ImageClipPipelineStep>[
          ImageClipPipelineStep.adjustColor(adjustment),
        ],
        operationLabel: 'Adjust color',
      ),
    );
  }

  /// Re-encodes [source] using [outputSettings].
  Future<EditedImage> exportImage(
    EditedImage source, {
    ImageClipOutputSettings outputSettings =
        const ImageClipOutputSettings.png(),
  }) {
    return processPipeline(
      ImageClipPipeline.fromImage(
        source: source,
        outputSettings: outputSettings,
        operationLabel: 'Export ${outputSettings.format.name.toUpperCase()}',
      ),
    );
  }

  /// Re-encodes [source] as a PNG [EditedImage].
  Future<EditedImage> exportPng(EditedImage source) {
    return exportImage(source);
  }

  /// Re-encodes [source] as a JPEG [EditedImage].
  Future<EditedImage> exportJpeg(EditedImage source, {int quality = 90}) {
    return exportImage(
      source,
      outputSettings: ImageClipOutputSettings.jpeg(jpegQuality: quality),
    );
  }

  Future<EditedImage> _run(Map<String, Object?> request) async {
    final payload = <String, Object?>{
      ...request,
      'processing': processingSettings.toMap(),
    };
    final result = await compute(
      _runImageJob,
      payload,
      debugLabel: 'image-job',
    );
    return EditedImage.fromMap(result);
  }
}
