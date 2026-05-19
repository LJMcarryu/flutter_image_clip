part of '../image_clip_editor.dart';

/// User-facing copy used by [ImageClipEditor] and [ImageClipResultPage].
class ImageClipEditorLabels {
  /// Creates editor labels and status messages.
  const ImageClipEditorLabels({
    this.defaultImageLabel = defaultImageLabelValue,
    this.cancelButton = 'Cancel',
    this.saveButton = 'Save',
    this.fitButton = 'Fit',
    this.fillButton = 'Fill',
    this.rotateButton = 'Rotate',
    this.previewSemanticsLabel = 'Image crop preview',
    this.cropFrameSemanticsLabel = 'Crop frame',
    this.resultTitle = 'Crop result',
    this.cropDetailsTitle = 'Crop details',
    this.rotationDegreesLabel = 'Rotation',
    this.sourceSizeLabel = 'Source size',
    this.resultDataTitle = 'Result data',
    this.backTooltip = 'Back',
    this.initialStatus = 'Choose an image to start cropping',
    this.loadingImageStatus = 'Loading image',
    this.imageLoadedStatus = 'Image loaded',
    this.waitingForImageStatus = 'Waiting for image',
    this.generatingSampleStatus = 'Generating sample image',
    this.sampleGeneratedStatus = 'Sample image ready',
    this.imageRequiredMessage = 'Add an image before cropping',
    this.rotatingStatus = 'Rotating image',
    this.rotationCompleteStatus = 'Rotation complete',
    this.croppingStatus = 'Cropping image',
    this.cropCompleteStatus = 'Crop complete',
    this.cropResetMessage = 'Crop frame reset',
    this.taskCanceledStatus = 'Processing canceled',
    this.processingFailedPrefix = 'Processing failed',
  });

  /// Default image label used when no label is supplied.
  static const defaultImageLabelValue = 'Image to crop';

  /// Default label attached to incoming image bytes.
  final String defaultImageLabel;

  /// Cancel button label.
  final String cancelButton;

  /// Save button label.
  final String saveButton;

  /// Button label for fit mode.
  final String fitButton;

  /// Button label for fill mode.
  final String fillButton;

  /// Rotate button label.
  final String rotateButton;

  /// Semantics label for the interactive crop preview.
  final String previewSemanticsLabel;

  /// Semantics label for the crop frame overlay.
  final String cropFrameSemanticsLabel;

  /// Result page title.
  final String resultTitle;

  /// Result metadata section title.
  final String cropDetailsTitle;

  /// Rotation metric label.
  final String rotationDegreesLabel;

  /// Source image size metric label.
  final String sourceSizeLabel;

  /// Result data section title.
  final String resultDataTitle;

  /// Back button tooltip.
  final String backTooltip;

  /// Initial empty preview status.
  final String initialStatus;

  /// Status shown while image bytes are decoded.
  final String loadingImageStatus;

  /// Status shown after image bytes are decoded.
  final String imageLoadedStatus;

  /// Status shown when no image is available.
  final String waitingForImageStatus;

  /// Status shown while the sample image is generated.
  final String generatingSampleStatus;

  /// Status shown after the sample image is generated.
  final String sampleGeneratedStatus;

  /// Message shown when the user tries to crop without an image.
  final String imageRequiredMessage;

  /// Status shown while the image is rotating.
  final String rotatingStatus;

  /// Status shown after rotation completes.
  final String rotationCompleteStatus;

  /// Status shown while the final crop is running.
  final String croppingStatus;

  /// Status shown after the final crop completes.
  final String cropCompleteStatus;

  /// Message shown after the crop frame is reset.
  final String cropResetMessage;

  /// Status shown after the current processing task is canceled.
  final String taskCanceledStatus;

  /// Prefix used for processing errors.
  final String processingFailedPrefix;

  /// Formats a completed processing status with image metadata.
  String completedStatus(String label, EditedImage result) {
    return '$label: ${result.dimensionsLabel}, ${result.bytesLabel}, '
        '${result.elapsedMs} ms';
  }

  /// Formats a processing error message.
  String errorMessage(Object error) => '$processingFailedPrefix: $error';
}
