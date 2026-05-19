import 'dart:typed_data';

import 'models.dart';

/// A batch of image operations that should run in one background isolate job.
///
/// Running a pipeline avoids re-decoding and re-encoding the image between
/// individual transformations.
class ImageClipPipeline {
  const ImageClipPipeline._({
    this.bytes,
    this.inputPath,
    this.source,
    required this.label,
    required this.steps,
    required this.outputSettings,
    required this.decodeSettings,
    this.sourceWidth,
    this.sourceHeight,
    this.operationLabel,
  });

  /// Creates a pipeline from encoded image [bytes].
  const ImageClipPipeline.decode({
    required Uint8List this.bytes,
    required this.label,
    this.steps = const <ImageClipPipelineStep>[],
    this.outputSettings = const ImageClipOutputSettings.png(),
    this.decodeSettings = const ImageClipDecodeSettings(),
    this.sourceWidth,
    this.sourceHeight,
    this.operationLabel,
  }) : inputPath = null,
       source = null;

  /// Creates a pipeline from a local image file path.
  const ImageClipPipeline.decodeFile({
    required String path,
    required this.label,
    this.steps = const <ImageClipPipelineStep>[],
    this.outputSettings = const ImageClipOutputSettings.png(),
    this.decodeSettings = const ImageClipDecodeSettings(),
    this.sourceWidth,
    this.sourceHeight,
    this.operationLabel,
  }) : bytes = null,
       inputPath = path,
       source = null;

  /// Creates a pipeline from an existing [EditedImage].
  ImageClipPipeline.fromImage({
    required EditedImage source,
    List<ImageClipPipelineStep> steps = const <ImageClipPipelineStep>[],
    ImageClipOutputSettings outputSettings =
        const ImageClipOutputSettings.png(),
    String? operationLabel,
  }) : this._(
         source: source,
         inputPath: null,
         label: source.label,
         steps: steps,
         outputSettings: outputSettings,
         decodeSettings: const ImageClipDecodeSettings(),
         sourceWidth: source.sourceWidth,
         sourceHeight: source.sourceHeight,
         operationLabel: operationLabel,
       );

  /// Encoded source bytes when the pipeline starts from raw input bytes.
  final Uint8List? bytes;

  /// Local file path when the pipeline starts from a file.
  final String? inputPath;

  /// Existing processed source image when the pipeline starts from [EditedImage].
  final EditedImage? source;

  /// Human-readable label preserved in the pipeline result.
  final String label;

  /// Ordered transformations applied after the source image is decoded.
  final List<ImageClipPipelineStep> steps;

  /// Output encoding settings for the final pipeline result.
  final ImageClipOutputSettings outputSettings;

  /// Decode-time settings applied before pipeline steps.
  final ImageClipDecodeSettings decodeSettings;

  /// Source decoded width before optional platform-side sampling.
  final int? sourceWidth;

  /// Source decoded height before optional platform-side sampling.
  final int? sourceHeight;

  /// Optional operation label stored on the resulting [EditedImage].
  final String? operationLabel;

  /// Converts this pipeline to the map used by the background processor.
  Map<String, Object?> toMap() => <String, Object?>{
    'bytes': bytes,
    'inputPath': inputPath,
    'source': source?.toMap(),
    'label': label,
    'steps': <Map<String, Object?>>[for (final step in steps) step.toMap()],
    'output': outputSettings.toMap(),
    'decodeSettings': decodeSettings.toMap(),
    'sourceWidth': sourceWidth,
    'sourceHeight': sourceHeight,
    'operationLabel': operationLabel,
  };
}

/// One transformation inside an [ImageClipPipeline].
class ImageClipPipelineStep {
  const ImageClipPipelineStep._(
    this._kind, {
    Map<String, Object?> arguments = const <String, Object?>{},
    CropSettings? cropSettings,
    CropRegion? cropRegion,
    ColorAdjustment? colorAdjustment,
    int? degrees,
    int? maxSide,
  }) : _arguments = arguments,
       _cropSettings = cropSettings,
       _cropRegion = cropRegion,
       _colorAdjustment = colorAdjustment,
       _degrees = degrees,
       _maxSide = maxSide;

  /// Adds a center-crop transformation.
  const ImageClipPipelineStep.cropCenter(CropSettings settings)
    : this._('cropCenter', cropSettings: settings);

  /// Adds an explicit pixel crop transformation.
  const ImageClipPipelineStep.cropRegion(CropRegion region)
    : this._('cropRegion', cropRegion: region);

  /// Adds a clockwise rotation transformation.
  const ImageClipPipelineStep.rotate({int degrees = 90})
    : this._('rotate', degrees: degrees);

  /// Adds a horizontal flip transformation.
  const ImageClipPipelineStep.flipHorizontal() : this._('flipHorizontal');

  /// Adds a vertical flip transformation.
  const ImageClipPipelineStep.flipVertical() : this._('flipVertical');

  /// Adds a resize transformation that constrains the longest side.
  const ImageClipPipelineStep.resizeLongSide(int maxSide)
    : this._('resizeLongSide', maxSide: maxSide);

  /// Adds a brightness, contrast, and saturation adjustment.
  const ImageClipPipelineStep.adjustColor(ColorAdjustment adjustment)
    : this._('adjustColor', colorAdjustment: adjustment);

  final String _kind;
  final Map<String, Object?> _arguments;
  final CropSettings? _cropSettings;
  final CropRegion? _cropRegion;
  final ColorAdjustment? _colorAdjustment;
  final int? _degrees;
  final int? _maxSide;

  /// Converts this step to the map used by the background processor.
  Map<String, Object?> toMap() {
    final arguments = <String, Object?>{..._arguments};
    final cropSettings = _cropSettings;
    final cropRegion = _cropRegion;
    final colorAdjustment = _colorAdjustment;

    if (cropSettings != null) {
      arguments.addAll(cropSettings.toMap());
    }
    if (cropRegion != null) {
      arguments.addAll(cropRegion.toMap());
    }
    if (colorAdjustment != null) {
      arguments.addAll(colorAdjustment.toMap());
    }
    if (_degrees != null) {
      arguments['angle'] = _degrees;
    }
    if (_maxSide != null) {
      arguments['maxSide'] = _maxSide;
    }

    return <String, Object?>{'kind': _kind, ...arguments};
  }
}
