part of '../image_clip_editor.dart';

/// User-facing copy used by [ImageClipEditor] and [ImageClipResultPage].
class ImageClipEditorLabels {
  /// Creates editor labels and status messages.
  const ImageClipEditorLabels({
    this.editorTitle = 'Position',
    this.positionHint = 'Pinch to zoom • Drag to reposition',
    this.defaultImageLabel = defaultImageLabelValue,
    this.cancelButton = 'Cancel',
    this.saveButton = 'Save',
    this.fitButton = 'Fit',
    this.fillButton = 'Fill',
    this.flipHorizontalButton = 'Flip H',
    this.flipVerticalButton = 'Flip V',
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
    this.flipPreviewStatus = 'Flip preview updated',
    this.croppingStatus = 'Cropping image',
    this.cropCompleteStatus = 'Crop complete',
    this.cropResetMessage = 'Crop frame reset',
    this.taskCanceledStatus = 'Processing canceled',
    this.processingFailedPrefix = 'Processing failed',
  });

  /// Default image label used when no label is supplied.
  static const defaultImageLabelValue = 'Image to crop';

  /// English label preset.
  static const english = ImageClipEditorLabels();

  /// Simplified Chinese label preset.
  static const zhHans = ImageClipEditorLabels(
    editorTitle: '位置',
    positionHint: '双指缩放 • 拖动调整位置',
    defaultImageLabel: '待裁剪图片',
    cancelButton: '取消',
    saveButton: '保存',
    fitButton: '适应',
    fillButton: '填充',
    flipHorizontalButton: '水平翻转',
    flipVerticalButton: '垂直翻转',
    rotateButton: '旋转',
    previewSemanticsLabel: '图片裁剪预览',
    cropFrameSemanticsLabel: '裁剪框',
    resultTitle: '裁剪结果',
    cropDetailsTitle: '裁剪详情',
    rotationDegreesLabel: '旋转角度',
    sourceSizeLabel: '原图尺寸',
    resultDataTitle: '结果数据',
    backTooltip: '返回',
    initialStatus: '选择图片开始裁剪',
    loadingImageStatus: '正在加载图片',
    imageLoadedStatus: '图片已加载',
    waitingForImageStatus: '等待图片',
    generatingSampleStatus: '正在生成示例图片',
    sampleGeneratedStatus: '示例图片已就绪',
    imageRequiredMessage: '请先添加图片再裁剪',
    rotatingStatus: '正在旋转图片',
    rotationCompleteStatus: '旋转完成',
    flipPreviewStatus: '翻转预览已更新',
    croppingStatus: '正在裁剪图片',
    cropCompleteStatus: '裁剪完成',
    cropResetMessage: '裁剪框已重置',
    taskCanceledStatus: '处理已取消',
    processingFailedPrefix: '处理失败',
  );

  /// Title shown in the editor top bar.
  final String editorTitle;

  /// Short hint shown above the crop controls.
  final String positionHint;

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

  /// Button label for horizontal preview flip.
  final String flipHorizontalButton;

  /// Button label for vertical preview flip.
  final String flipVerticalButton;

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

  /// Status shown after a preview flip changes.
  final String flipPreviewStatus;

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
