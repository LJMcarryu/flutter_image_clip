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
    ImageClipTaskOptions? options,
  }) {
    return rotateTask(degrees: degrees, options: options).result;
  }

  /// Starts rotating the current image clockwise by [degrees].
  ImageClipTask<EditedImage> rotateTask({
    int degrees = 90,
    ImageClipTaskOptions? options,
  }) {
    return applyTask(
      <ImageClipPipelineStep>[ImageClipPipelineStep.rotate(degrees: degrees)],
      operationLabel: 'Rotate',
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
