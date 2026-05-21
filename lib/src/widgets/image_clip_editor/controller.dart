part of '../image_clip_editor.dart';

/// Programmatic controller for an [ImageClipEditor].
///
/// Attach the controller to an editor through [ImageClipEditor.controller], then
/// call these methods from parent widgets to load images, reset the viewport, or
/// trigger crop operations without relying on toolbar taps.
class ImageClipEditorController {
  /// Creates a controller for driving a single [ImageClipEditor].
  ImageClipEditorController();

  _ImageClipEditorState? _state;

  /// Whether this controller is currently attached to an editor state.
  bool get isAttached => _state != null;

  /// Whether the attached editor is currently running an image task.
  bool get isBusy => _state?._isBusy ?? false;

  /// The image currently loaded in the attached editor.
  EditedImage? get image => _state?._image;

  /// The current crop frame in source-image pixel coordinates.
  ///
  /// The returned region may extend outside the source image when the crop
  /// frame contains Fit-mode letterbox or pillarbox space.
  CropRegion? currentCropRegion({double cornerRadius = 0}) {
    return _requireState()._currentCropRegion(cornerRadius: cornerRadius);
  }

  /// Loads encoded image [bytes] into the attached editor.
  ///
  /// If another load or processing task is still running, its eventual result is
  /// ignored and this image becomes the newest requested editor state.
  Future<void> loadImage(Uint8List bytes, {String label = ''}) {
    return _requireState()._loadControllerImage(bytes, label: label);
  }

  /// Loads a local image file [path] into the attached editor.
  ///
  /// Use this for gallery files when available. It avoids keeping the full
  /// original source bytes in widget state and lets save operations read the
  /// source file inside background processing.
  Future<void> loadImageFile(String path, {String label = ''}) {
    return _requireState()._loadControllerImageFile(path, label: label);
  }

  /// Generates and loads the built-in sample image.
  Future<void> loadSample() {
    return _requireState()._loadSample(replaceCurrent: true);
  }

  /// Clears the current image and resets the editor status.
  void clearImage() {
    _requireState()._clearImageFromController();
  }

  /// Resets the crop viewport to the editor's current scale mode.
  void resetView() {
    _requireState()._resetCropView();
  }

  /// Rotates the editor preview clockwise by 90 degrees.
  ///
  /// The source image is not re-encoded here. Rotation is applied when the
  /// current crop is saved.
  Future<void> rotateRight() {
    return _requireState()._rotateRight();
  }

  /// Flips the editor preview around its vertical axis.
  ///
  /// The source image is not re-encoded here. Flip is applied when the current
  /// crop is saved.
  Future<void> flipHorizontal() {
    return _requireState()._flipHorizontalPreview();
  }

  /// Flips the editor preview around its horizontal axis.
  ///
  /// The source image is not re-encoded here. Flip is applied when the current
  /// crop is saved.
  Future<void> flipVertical() {
    return _requireState()._flipVerticalPreview();
  }

  /// Runs the current crop operation and returns its result.
  Future<ImageClipResult?> crop() {
    return _requireState()._applyCrop();
  }

  /// Cancels the currently running editor task, if any.
  bool cancelTask() {
    return _requireState()._cancelActiveTask();
  }

  void _attach(_ImageClipEditorState state) {
    final attachedState = _state;
    if (attachedState != null && !identical(attachedState, state)) {
      throw FlutterError(
        'This ImageClipEditorController is already attached to another '
        'ImageClipEditor.',
      );
    }
    _state = state;
  }

  void _detach(_ImageClipEditorState state) {
    if (identical(_state, state)) {
      _state = null;
    }
  }

  _ImageClipEditorState _requireState() {
    final state = _state;
    if (state == null) {
      throw StateError(
        'ImageClipEditorController is not attached to an ImageClipEditor.',
      );
    }
    return state;
  }
}
