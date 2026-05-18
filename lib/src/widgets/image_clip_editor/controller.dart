part of '../image_clip_editor.dart';

/// Programmatic controller for an [ImageClipEditor].
///
/// Attach the controller to an editor through [ImageClipEditor.controller], then
/// call these methods from parent widgets to load images, reset the viewport, or
/// trigger crop operations without relying on toolbar taps.
class ImageClipEditorController {
  _ImageClipEditorState? _state;

  /// Whether this controller is currently attached to an editor state.
  bool get isAttached => _state != null;

  /// Whether the attached editor is currently running an image task.
  bool get isBusy => _state?._isBusy ?? false;

  /// The image currently loaded in the attached editor.
  EditedImage? get image => _state?._image;

  /// The current visible crop region in source-image pixel coordinates.
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

  /// Rotates the current image clockwise by 90 degrees.
  Future<void> rotateRight() {
    return _requireState()._rotateRight();
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
