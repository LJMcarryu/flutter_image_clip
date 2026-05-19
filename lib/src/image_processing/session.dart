part of 'image_processor.dart';

/// Stateful editing session built around an [EditedImage].
///
/// A session is useful when a feature applies multiple edits to the same image.
/// Each successful operation updates [image], so callers can keep a single
/// object as the current editing state instead of manually threading
/// intermediate [EditedImage] values through every call.
class ImageClipSession {
  /// Creates a session with an initial [image].
  ImageClipSession({
    required EditedImage image,
    this.processor = const ImageProcessor(),
  }) : _image = image;

  /// Processor used by this session.
  final ImageProcessor processor;

  EditedImage _image;
  ImageClipTask<EditedImage>? _activeTask;
  int _revision = 0;
  int _operationCount = 0;

  /// Current image state for the session.
  EditedImage get image => _image;

  /// Number of successful operations applied since the last replacement.
  int get operationCount => _operationCount;

  /// Whether the session currently has a running task.
  bool get isBusy {
    final task = _activeTask;
    return task != null && !task.isCompleted;
  }

  /// Replaces the current session image and cancels any running task.
  void replaceImage(EditedImage image) {
    cancelTask();
    _image = image;
    _operationCount = 0;
  }

  /// Applies [steps] to the current image and updates [image] on success.
  Future<EditedImage> apply(
    List<ImageClipPipelineStep> steps, {
    ImageClipOutputSettings outputSettings =
        const ImageClipOutputSettings.png(),
    String? operationLabel,
    ImageClipTaskOptions? options,
  }) {
    return applyTask(
      steps,
      outputSettings: outputSettings,
      operationLabel: operationLabel,
      options: options,
    ).result;
  }

  /// Starts applying [steps] to the current image.
  ImageClipTask<EditedImage> applyTask(
    List<ImageClipPipelineStep> steps, {
    ImageClipOutputSettings outputSettings =
        const ImageClipOutputSettings.png(),
    String? operationLabel,
    ImageClipTaskOptions? options,
  }) {
    cancelTask();
    final taskRevision = ++_revision;
    final task = processor.processPipelineTask(
      ImageClipPipeline.fromImage(
        source: _image,
        steps: steps,
        outputSettings: outputSettings,
        operationLabel: operationLabel,
      ),
      options: options,
    );
    _activeTask = task;
    unawaited(
      task.result.then<void>(
        (result) {
          if (taskRevision == _revision) {
            _image = result;
            _operationCount++;
            _activeTask = null;
          }
        },
        onError: (Object _) {
          if (taskRevision == _revision) {
            _activeTask = null;
          }
        },
      ),
    );
    return task;
  }

  /// Crops the current image to [region].
  Future<EditedImage> cropRegion(
    CropRegion region, {
    ImageClipOutputSettings outputSettings =
        const ImageClipOutputSettings.png(),
    ImageClipTaskOptions? options,
  }) {
    return cropRegionTask(
      region,
      outputSettings: outputSettings,
      options: options,
    ).result;
  }

  /// Starts cropping the current image to [region].
  ImageClipTask<EditedImage> cropRegionTask(
    CropRegion region, {
    ImageClipOutputSettings outputSettings =
        const ImageClipOutputSettings.png(),
    ImageClipTaskOptions? options,
  }) {
    return applyTask(
      <ImageClipPipelineStep>[ImageClipPipelineStep.cropRegion(region)],
      outputSettings: outputSettings,
      operationLabel: 'Crop region',
      options: options,
    );
  }

  /// Rotates the current image clockwise by [degrees].
  Future<EditedImage> rotate({
    int degrees = 90,
    ImageClipOutputSettings outputSettings =
        const ImageClipOutputSettings.png(),
    ImageClipTaskOptions? options,
  }) {
    return rotateTask(
      degrees: degrees,
      outputSettings: outputSettings,
      options: options,
    ).result;
  }

  /// Starts rotating the current image clockwise by [degrees].
  ImageClipTask<EditedImage> rotateTask({
    int degrees = 90,
    ImageClipOutputSettings outputSettings =
        const ImageClipOutputSettings.png(),
    ImageClipTaskOptions? options,
  }) {
    return applyTask(
      <ImageClipPipelineStep>[ImageClipPipelineStep.rotate(degrees: degrees)],
      outputSettings: outputSettings,
      operationLabel: 'Rotate',
      options: options,
    );
  }

  /// Flips the current image around the vertical axis.
  Future<EditedImage> flipHorizontal({
    ImageClipOutputSettings outputSettings =
        const ImageClipOutputSettings.png(),
    ImageClipTaskOptions? options,
  }) {
    return flipHorizontalTask(
      outputSettings: outputSettings,
      options: options,
    ).result;
  }

  /// Starts flipping the current image around the vertical axis.
  ImageClipTask<EditedImage> flipHorizontalTask({
    ImageClipOutputSettings outputSettings =
        const ImageClipOutputSettings.png(),
    ImageClipTaskOptions? options,
  }) {
    return applyTask(
      const <ImageClipPipelineStep>[ImageClipPipelineStep.flipHorizontal()],
      outputSettings: outputSettings,
      operationLabel: 'Flip horizontal',
      options: options,
    );
  }

  /// Flips the current image around the horizontal axis.
  Future<EditedImage> flipVertical({
    ImageClipOutputSettings outputSettings =
        const ImageClipOutputSettings.png(),
    ImageClipTaskOptions? options,
  }) {
    return flipVerticalTask(
      outputSettings: outputSettings,
      options: options,
    ).result;
  }

  /// Starts flipping the current image around the horizontal axis.
  ImageClipTask<EditedImage> flipVerticalTask({
    ImageClipOutputSettings outputSettings =
        const ImageClipOutputSettings.png(),
    ImageClipTaskOptions? options,
  }) {
    return applyTask(
      const <ImageClipPipelineStep>[ImageClipPipelineStep.flipVertical()],
      outputSettings: outputSettings,
      operationLabel: 'Flip vertical',
      options: options,
    );
  }

  /// Resizes the current image so its longest side is [maxSide].
  Future<EditedImage> resizeLongSide(
    int maxSide, {
    ImageClipTaskOptions? options,
  }) {
    return applyTask(
      <ImageClipPipelineStep>[ImageClipPipelineStep.resizeLongSide(maxSide)],
      operationLabel: 'Resize',
      options: options,
    ).result;
  }

  /// Applies brightness, contrast, and saturation to the current image.
  Future<EditedImage> adjustColor(
    ColorAdjustment adjustment, {
    ImageClipTaskOptions? options,
  }) {
    return applyTask(
      <ImageClipPipelineStep>[ImageClipPipelineStep.adjustColor(adjustment)],
      operationLabel: 'Adjust color',
      options: options,
    ).result;
  }

  /// Re-encodes the current image with [outputSettings].
  Future<EditedImage> exportImage({
    ImageClipOutputSettings outputSettings =
        const ImageClipOutputSettings.png(),
    ImageClipTaskOptions? options,
  }) {
    return applyTask(
      const <ImageClipPipelineStep>[],
      outputSettings: outputSettings,
      operationLabel: 'Export ${outputSettings.format.name.toUpperCase()}',
      options: options,
    ).result;
  }

  /// Cancels the active session task, if any.
  bool cancelTask() {
    final task = _activeTask;
    if (task == null || task.isCompleted) {
      return false;
    }
    _revision++;
    _activeTask = null;
    return task.cancel();
  }
}

/// Synchronous session that keeps decoded pixels in memory between operations.
///
/// Use this when repeated edits are already running off the UI isolate, or when
/// the image is small enough for synchronous processing. Unlike
/// [ImageClipSession], this class avoids re-decoding and re-encoding between
/// intermediate steps; encoding only happens when [exportImage] is called.
class ImageClipDecodedSession {
  ImageClipDecodedSession._({
    required img.Image image,
    required this.label,
    required this.processingSettings,
  }) : _image = image;

  /// Decodes [bytes] and creates a session that stores decoded pixels.
  factory ImageClipDecodedSession.decode(
    Uint8List bytes, {
    required String label,
    ImageClipProcessingSettings processingSettings =
        const ImageClipProcessingSettings(),
  }) {
    return ImageClipDecodedSession._(
      image: _decode(bytes, processingSettings),
      label: label,
      processingSettings: processingSettings,
    );
  }

  /// Creates a decoded session from an existing encoded [source].
  factory ImageClipDecodedSession.fromEditedImage(
    EditedImage source, {
    ImageClipProcessingSettings processingSettings =
        const ImageClipProcessingSettings(),
  }) {
    return ImageClipDecodedSession.decode(
      source.bytes,
      label: source.label,
      processingSettings: processingSettings,
    );
  }

  img.Image _image;
  int _operationCount = 0;

  /// Human-readable label preserved in exported results.
  final String label;

  /// Guardrails used for decode and export.
  final ImageClipProcessingSettings processingSettings;

  /// Current decoded width in pixels.
  int get width => _image.width;

  /// Current decoded height in pixels.
  int get height => _image.height;

  /// Number of successful in-memory operations applied to this session.
  int get operationCount => _operationCount;

  /// Applies [steps] to the decoded image without encoding intermediate output.
  void apply(List<ImageClipPipelineStep> steps) {
    for (final step in steps) {
      _image = _applyPipelineStep(
        _image,
        Map<Object?, Object?>.from(step.toMap()),
      );
      _operationCount++;
    }
  }

  /// Crops the decoded image to [region].
  void cropRegion(CropRegion region) {
    apply(<ImageClipPipelineStep>[ImageClipPipelineStep.cropRegion(region)]);
  }

  /// Rotates the decoded image clockwise by [degrees].
  void rotate({int degrees = 90}) {
    apply(<ImageClipPipelineStep>[
      ImageClipPipelineStep.rotate(degrees: degrees),
    ]);
  }

  /// Flips the decoded image around the vertical axis.
  void flipHorizontal() {
    apply(const <ImageClipPipelineStep>[
      ImageClipPipelineStep.flipHorizontal(),
    ]);
  }

  /// Flips the decoded image around the horizontal axis.
  void flipVertical() {
    apply(const <ImageClipPipelineStep>[ImageClipPipelineStep.flipVertical()]);
  }

  /// Resizes the decoded image so its longest side is [maxSide].
  void resizeLongSide(int maxSide) {
    apply(<ImageClipPipelineStep>[
      ImageClipPipelineStep.resizeLongSide(maxSide),
    ]);
  }

  /// Applies brightness, contrast, and saturation to the decoded image.
  void adjustColor(ColorAdjustment adjustment) {
    apply(<ImageClipPipelineStep>[
      ImageClipPipelineStep.adjustColor(adjustment),
    ]);
  }

  /// Encodes the current decoded image to an [EditedImage].
  EditedImage exportImage({
    ImageClipOutputSettings outputSettings =
        const ImageClipOutputSettings.png(),
    String? operationLabel,
  }) {
    final stopwatch = Stopwatch()..start();
    final outputImage = _prepareOutputImage(_image, processingSettings);
    final bytes = _encodeImage(outputImage, outputSettings);
    stopwatch.stop();
    return EditedImage(
      bytes: bytes,
      width: outputImage.width,
      height: outputImage.height,
      label: label,
      operation:
          operationLabel ??
          'Export ${outputSettings.format.name.toUpperCase()}',
      elapsedMs: stopwatch.elapsedMilliseconds,
      format: outputSettings.format,
    );
  }
}
