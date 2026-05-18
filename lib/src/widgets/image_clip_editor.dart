import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../image_processing/image_processor.dart';

/// Opens a full-screen image crop editor and returns an [ImageClipResult].
Future<ImageClipResult?> showImageClipEditor(
  BuildContext context, {
  Uint8List? imageBytes,
  String imageLabel = '',
  ImageProcessor? processor,
  ImageClipCropOrientation initialOrientation =
      ImageClipCropOrientation.portrait,
  ImageClipAspectRatio? initialAspectRatio,
  List<ImageClipAspectRatio> aspectRatios = ImageClipAspectRatio.defaults,
  ImageClipScaleMode initialScaleMode = ImageClipScaleMode.fill,
  ImageClipOutputSettings outputSettings = const ImageClipOutputSettings.png(),
  ImageClipProcessingSettings processingSettings =
      const ImageClipProcessingSettings(),
  ImageClipEditorLabels labels = const ImageClipEditorLabels(),
  ImageClipEditorTheme theme = const ImageClipEditorTheme.dark(),
  bool loadSampleOnStart = true,
  bool useRootNavigator = false,
  RouteSettings? routeSettings,
}) {
  return Navigator.of(context, rootNavigator: useRootNavigator).push(
    MaterialPageRoute<ImageClipResult>(
      settings: routeSettings,
      builder: (context) {
        return ImageClipEditor(
          processor: processor,
          initialImageBytes: imageBytes,
          initialImageLabel: imageLabel,
          initialOrientation: initialOrientation,
          initialAspectRatio: initialAspectRatio,
          aspectRatios: aspectRatios,
          initialScaleMode: initialScaleMode,
          outputSettings: outputSettings,
          processingSettings: processingSettings,
          labels: labels,
          theme: theme,
          loadSampleOnStart: loadSampleOnStart,
          closeOnCancel: true,
          closeOnSave: true,
          showResultPage: false,
        );
      },
    ),
  );
}

/// Legacy portrait/landscape selector used when no aspect ratio is supplied.
enum ImageClipCropOrientation {
  /// Uses a portrait 3:4 crop box.
  portrait,

  /// Uses a landscape 4:3 crop box.
  landscape,
}

/// A named crop box aspect ratio shown by [ImageClipEditor].
class ImageClipAspectRatio {
  /// Creates a crop aspect ratio preset.
  const ImageClipAspectRatio({
    required this.label,
    required this.width,
    required this.height,
  }) : assert(width > 0),
       assert(height > 0);

  /// Square 1:1 crop preset.
  static const square = ImageClipAspectRatio(
    label: 'Square',
    width: 1,
    height: 1,
  );

  /// Portrait 3:4 crop preset.
  static const portrait = ImageClipAspectRatio(
    label: 'Portrait',
    width: 3,
    height: 4,
  );

  /// Landscape 4:3 crop preset.
  static const landscape = ImageClipAspectRatio(
    label: 'Landscape',
    width: 4,
    height: 3,
  );

  /// Widescreen 16:9 crop preset.
  static const widescreen = ImageClipAspectRatio(
    label: '16:9',
    width: 16,
    height: 9,
  );

  /// Default presets shown by the editor.
  static const defaults = <ImageClipAspectRatio>[portrait, landscape];

  /// Creates a preset equivalent to the legacy [ImageClipCropOrientation].
  static ImageClipAspectRatio fromOrientation(
    ImageClipCropOrientation orientation,
  ) {
    return switch (orientation) {
      ImageClipCropOrientation.portrait => portrait,
      ImageClipCropOrientation.landscape => landscape,
    };
  }

  /// User-facing preset label.
  final String label;

  /// Relative crop width.
  final double width;

  /// Relative crop height.
  final double height;

  /// Width divided by height.
  double get value => width / height;

  @override
  bool operator ==(Object other) {
    return other is ImageClipAspectRatio &&
        other.label == label &&
        other.width == width &&
        other.height == height;
  }

  @override
  int get hashCode => Object.hash(label, width, height);
}

/// How the source image is initially placed behind the crop box.
enum ImageClipScaleMode {
  /// Shows the whole source image inside the preview area.
  fit,

  /// Scales the source image until the crop box is fully covered.
  fill,
}

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

/// Visual tokens used by [ImageClipEditor] and [ImageClipResultPage].
class ImageClipEditorTheme {
  /// Creates an editor theme.
  const ImageClipEditorTheme({
    this.backgroundColor = const Color(0xFF101113),
    this.previewBackgroundColor = const Color(0xFF101113),
    this.surfaceColor = const Color(0xFF18191C),
    this.imageBackgroundColor = const Color(0xFF17181B),
    this.tileColor = const Color(0xFF222326),
    this.borderColor = const Color(0xFF2A2B2E),
    this.strongBorderColor = const Color(0xFF333439),
    this.primaryTextColor = const Color(0xFFF7F7F7),
    this.secondaryTextColor = const Color(0xFF9D9EA3),
    this.disabledTextColor = const Color(0xFF5A5B5E),
    this.inactiveTextColor = const Color(0xFF6D6E72),
    this.progressColor = const Color(0xFFF7F7F7),
    this.cropShadeColor = const Color(0x99000000),
    this.cropBorderColor = const Color(0xCCFFFFFF),
    this.cropGridColor = const Color(0x99FFFFFF),
    this.borderRadius = 8,
    this.cropBorderWidth = 1.2,
    this.aspectRatioBorderWidth = 1.6,
  });

  /// Creates the default dark editor theme.
  const ImageClipEditorTheme.dark() : this();

  /// Creates a theme from a Flutter [ColorScheme].
  factory ImageClipEditorTheme.fromColorScheme(ColorScheme colorScheme) {
    final dark = colorScheme.brightness == Brightness.dark;
    return ImageClipEditorTheme(
      backgroundColor: colorScheme.surface,
      previewBackgroundColor: colorScheme.surface,
      surfaceColor: colorScheme.surfaceContainerLow,
      imageBackgroundColor: colorScheme.surfaceContainerLowest,
      tileColor: colorScheme.surfaceContainerHigh,
      borderColor: colorScheme.outlineVariant,
      strongBorderColor: colorScheme.outline,
      primaryTextColor: colorScheme.onSurface,
      secondaryTextColor: colorScheme.onSurfaceVariant,
      disabledTextColor: colorScheme.onSurface.withValues(alpha: 0.38),
      inactiveTextColor: colorScheme.onSurfaceVariant.withValues(alpha: 0.72),
      progressColor: colorScheme.primary,
      cropShadeColor: dark ? const Color(0x99000000) : const Color(0x66FFFFFF),
      cropBorderColor: colorScheme.primary,
      cropGridColor: colorScheme.primary.withValues(alpha: 0.62),
    );
  }

  /// Background color for the editor scaffold.
  final Color backgroundColor;

  /// Background color for the preview area.
  final Color previewBackgroundColor;

  /// Surface color for result sections.
  final Color surfaceColor;

  /// Background color behind rendered images.
  final Color imageBackgroundColor;

  /// Surface color for metric tiles.
  final Color tileColor;

  /// Subtle border color.
  final Color borderColor;

  /// Stronger border color for nested controls.
  final Color strongBorderColor;

  /// Main text and enabled control color.
  final Color primaryTextColor;

  /// Secondary label text color.
  final Color secondaryTextColor;

  /// Disabled control color.
  final Color disabledTextColor;

  /// Unselected control color.
  final Color inactiveTextColor;

  /// Progress indicator color.
  final Color progressColor;

  /// Overlay color outside the crop frame.
  final Color cropShadeColor;

  /// Crop frame border color.
  final Color cropBorderColor;

  /// Crop grid line color.
  final Color cropGridColor;

  /// Default corner radius for framed surfaces.
  final double borderRadius;

  /// Stroke width for the crop frame.
  final double cropBorderWidth;

  /// Stroke width for aspect ratio preview glyphs.
  final double aspectRatioBorderWidth;

  /// Creates a copy with selected values replaced.
  ImageClipEditorTheme copyWith({
    Color? backgroundColor,
    Color? previewBackgroundColor,
    Color? surfaceColor,
    Color? imageBackgroundColor,
    Color? tileColor,
    Color? borderColor,
    Color? strongBorderColor,
    Color? primaryTextColor,
    Color? secondaryTextColor,
    Color? disabledTextColor,
    Color? inactiveTextColor,
    Color? progressColor,
    Color? cropShadeColor,
    Color? cropBorderColor,
    Color? cropGridColor,
    double? borderRadius,
    double? cropBorderWidth,
    double? aspectRatioBorderWidth,
  }) {
    return ImageClipEditorTheme(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      previewBackgroundColor:
          previewBackgroundColor ?? this.previewBackgroundColor,
      surfaceColor: surfaceColor ?? this.surfaceColor,
      imageBackgroundColor: imageBackgroundColor ?? this.imageBackgroundColor,
      tileColor: tileColor ?? this.tileColor,
      borderColor: borderColor ?? this.borderColor,
      strongBorderColor: strongBorderColor ?? this.strongBorderColor,
      primaryTextColor: primaryTextColor ?? this.primaryTextColor,
      secondaryTextColor: secondaryTextColor ?? this.secondaryTextColor,
      disabledTextColor: disabledTextColor ?? this.disabledTextColor,
      inactiveTextColor: inactiveTextColor ?? this.inactiveTextColor,
      progressColor: progressColor ?? this.progressColor,
      cropShadeColor: cropShadeColor ?? this.cropShadeColor,
      cropBorderColor: cropBorderColor ?? this.cropBorderColor,
      cropGridColor: cropGridColor ?? this.cropGridColor,
      borderRadius: borderRadius ?? this.borderRadius,
      cropBorderWidth: cropBorderWidth ?? this.cropBorderWidth,
      aspectRatioBorderWidth:
          aspectRatioBorderWidth ?? this.aspectRatioBorderWidth,
    );
  }
}

/// Result returned after a crop is saved.
class ImageClipResult {
  /// Creates a crop result with source, output, and crop metadata.
  const ImageClipResult({
    required this.source,
    required this.cropped,
    required this.region,
    required this.rotationDegrees,
  });

  /// Source image that was displayed in the editor.
  final EditedImage source;

  /// Cropped image produced by the editor.
  final EditedImage cropped;

  /// Pixel crop rectangle applied to [source].
  final CropRegion region;

  /// Clockwise rotation applied before the final crop, in degrees.
  final int rotationDegrees;

  /// Converts the result metadata and images to isolate-safe maps.
  Map<String, Object?> toMap() => <String, Object?>{
    'source': source.toMap(),
    'cropped': cropped.toMap(),
    'region': region.toMap(),
    'rotationDegrees': rotationDegrees,
  };
}

/// Embeddable Flutter widget for interactive image clipping.
class ImageClipEditor extends StatefulWidget {
  /// Creates an image crop editor widget.
  const ImageClipEditor({
    super.key,
    this.processor,
    this.initialImageBytes,
    this.initialImageLabel = '',
    this.initialOrientation = ImageClipCropOrientation.portrait,
    this.initialAspectRatio,
    this.aspectRatios = ImageClipAspectRatio.defaults,
    this.initialScaleMode = ImageClipScaleMode.fill,
    this.outputSettings = const ImageClipOutputSettings.png(),
    this.processingSettings = const ImageClipProcessingSettings(),
    this.labels = const ImageClipEditorLabels(),
    this.theme = const ImageClipEditorTheme.dark(),
    this.loadSampleOnStart = true,
    this.closeOnCancel = false,
    this.closeOnSave = false,
    this.showResultPage = true,
    this.onCancel,
    this.onResult,
  });

  /// Optional processor instance used for image operations.
  final ImageProcessor? processor;

  /// Encoded image bytes loaded when the editor starts.
  final Uint8List? initialImageBytes;

  /// Label attached to [initialImageBytes] in image processing results.
  ///
  /// When empty, [ImageClipEditorLabels.defaultImageLabel] is used.
  final String initialImageLabel;

  /// Legacy initial crop-box orientation.
  ///
  /// Ignored when [initialAspectRatio] is provided.
  final ImageClipCropOrientation initialOrientation;

  /// Initial crop-box aspect ratio that overrides [initialOrientation].
  final ImageClipAspectRatio? initialAspectRatio;

  /// Aspect ratio presets shown in the bottom toolbar.
  final List<ImageClipAspectRatio> aspectRatios;

  /// Initial image scaling mode.
  final ImageClipScaleMode initialScaleMode;

  /// Output encoding settings used for the saved crop result.
  final ImageClipOutputSettings outputSettings;

  /// Runtime guardrails used when this widget creates its own processor.
  final ImageClipProcessingSettings processingSettings;

  /// User-facing copy used by the editor.
  final ImageClipEditorLabels labels;

  /// Visual tokens used by the editor.
  final ImageClipEditorTheme theme;

  /// Whether to generate a sample image when [initialImageBytes] is null.
  final bool loadSampleOnStart;

  /// Whether canceling the editor should pop the current route.
  final bool closeOnCancel;

  /// Whether saving a crop should pop the current route with the result.
  final bool closeOnSave;

  /// Whether to navigate to [ImageClipResultPage] after saving.
  final bool showResultPage;

  /// Called when the user cancels the crop operation.
  final VoidCallback? onCancel;

  /// Called with the saved crop result.
  final ValueChanged<ImageClipResult>? onResult;

  @override
  State<ImageClipEditor> createState() => _ImageClipEditorState();
}

class _ImageClipEditorState extends State<ImageClipEditor> {
  late final ImageProcessor _processor;
  final _previewKey = GlobalKey<_PreviewPanelState>();

  EditedImage? _image;
  bool _isBusy = false;
  late String _status;
  late ImageClipAspectRatio _cropAspectRatio;
  late ImageClipScaleMode _cropScaleMode;
  int _rotationDegrees = 0;

  double get _cropAspectRatioValue => _cropAspectRatio.value;

  ImageClipAspectRatio get _initialAspectRatio {
    return widget.initialAspectRatio ??
        ImageClipAspectRatio.fromOrientation(widget.initialOrientation);
  }

  String get _initialImageLabel {
    return widget.initialImageLabel.isEmpty
        ? widget.labels.defaultImageLabel
        : widget.initialImageLabel;
  }

  List<ImageClipAspectRatio> get _aspectRatioChoices {
    final presets = widget.aspectRatios.isEmpty
        ? ImageClipAspectRatio.defaults
        : widget.aspectRatios;
    if (presets.contains(_cropAspectRatio)) {
      return presets;
    }
    return <ImageClipAspectRatio>[_cropAspectRatio, ...presets];
  }

  @override
  void initState() {
    super.initState();
    _processor =
        widget.processor ??
        ImageProcessor(processingSettings: widget.processingSettings);
    _status = widget.labels.initialStatus;
    _cropAspectRatio = _initialAspectRatio;
    _cropScaleMode = widget.initialScaleMode;
    unawaited(_loadInitialImage());
  }

  @override
  void didUpdateWidget(covariant ImageClipEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialImageBytes != widget.initialImageBytes ||
        oldWidget.initialImageLabel != widget.initialImageLabel) {
      unawaited(_loadInitialImage());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.theme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _CropTopBar(
              isBusy: _isBusy,
              canSave: _image != null,
              labels: widget.labels,
              theme: widget.theme,
              onCancel: _cancelCrop,
              onSave: _applyCrop,
            ),
            if (_isBusy)
              LinearProgressIndicator(
                minHeight: 2,
                color: widget.theme.progressColor,
                backgroundColor: widget.theme.borderColor,
              ),
            Expanded(
              child: _PreviewPanel(
                key: _previewKey,
                image: _image,
                isBusy: _isBusy,
                status: _status,
                cropAspectRatio: _cropAspectRatioValue,
                scaleMode: _cropScaleMode,
                theme: widget.theme,
              ),
            ),
            _CropBottomBar(
              selectedAspectRatio: _cropAspectRatio,
              aspectRatios: _aspectRatioChoices,
              scaleMode: _cropScaleMode,
              labels: widget.labels,
              theme: widget.theme,
              canRun: _image != null && !_isBusy,
              onScaleModeToggle: _toggleScaleMode,
              onRotate: _rotateRight,
              onAspectRatioChanged: _setCropAspectRatio,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadInitialImage() {
    final bytes = widget.initialImageBytes;
    if (bytes != null) {
      return _runImageTask(
        () => _processor.decodeBytes(bytes, label: _initialImageLabel),
        busyLabel: widget.labels.loadingImageStatus,
        doneLabel: widget.labels.imageLoadedStatus,
        onDone: (_) {
          _rotationDegrees = 0;
        },
      );
    }

    if (widget.loadSampleOnStart) {
      return _loadSample();
    }

    setState(() {
      _image = null;
      _status = widget.labels.waitingForImageStatus;
      _rotationDegrees = 0;
    });
    return Future<void>.value();
  }

  Future<void> _loadSample() {
    return _runImageTask(
      () => _processor.createSample(),
      busyLabel: widget.labels.generatingSampleStatus,
      doneLabel: widget.labels.sampleGeneratedStatus,
      onDone: (_) {
        _rotationDegrees = 0;
      },
    );
  }

  Future<void> _applyCrop() async {
    final source = _image;
    if (source == null) {
      if (widget.loadSampleOnStart) {
        return _loadSample();
      }
      _showMessage(widget.labels.imageRequiredMessage);
      return;
    }
    final region = _previewKey.currentState?.currentCropRegion(cornerRadius: 0);
    final cropRegion =
        region ??
        CropRegion(
          x: 0,
          y: 0,
          width: source.width,
          height: source.height,
          cornerRadius: 0,
        );

    await _saveCropResult(source: source, region: cropRegion);
  }

  Future<void> _rotateRight() {
    final source = _image;
    if (source == null) {
      if (widget.loadSampleOnStart) {
        return _loadSample();
      }
      _showMessage(widget.labels.imageRequiredMessage);
      return Future<void>.value();
    }
    return _runImageTask(
      () => _processor.rotateRight(source),
      busyLabel: widget.labels.rotatingStatus,
      doneLabel: widget.labels.rotationCompleteStatus,
      onDone: (_) {
        _rotationDegrees = (_rotationDegrees + 90) % 360;
      },
    );
  }

  Future<void> _runImageTask(
    Future<EditedImage> Function() task, {
    required String busyLabel,
    required String doneLabel,
    void Function(EditedImage result)? onDone,
  }) async {
    if (_isBusy) {
      return;
    }

    setState(() {
      _isBusy = true;
      _status = busyLabel;
    });

    try {
      final result = await task();
      if (!mounted) {
        return;
      }
      setState(() {
        _image = result;
        _isBusy = false;
        onDone?.call(result);
        _status = widget.labels.completedStatus(doneLabel, result);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isBusy = false;
        _status = widget.labels.errorMessage(error);
      });
      _showMessage(widget.labels.errorMessage(error));
    }
  }

  Future<void> _saveCropResult({
    required EditedImage source,
    required CropRegion region,
  }) async {
    if (_isBusy) {
      return;
    }

    setState(() {
      _isBusy = true;
      _status = widget.labels.croppingStatus;
    });

    try {
      final cropped = await _processor.cropRegion(
        source,
        region,
        outputSettings: widget.outputSettings,
      );
      if (!mounted) {
        return;
      }
      final result = ImageClipResult(
        source: source,
        cropped: cropped,
        region: region,
        rotationDegrees: _rotationDegrees,
      );
      setState(() {
        _isBusy = false;
        _status = widget.labels.completedStatus(
          widget.labels.cropCompleteStatus,
          cropped,
        );
      });
      widget.onResult?.call(result);
      if (widget.closeOnSave) {
        Navigator.of(context).pop(result);
        return;
      }
      if (widget.showResultPage) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => ImageClipResultPage(
              result: result,
              labels: widget.labels,
              theme: widget.theme,
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isBusy = false;
        _status = widget.labels.errorMessage(error);
      });
      _showMessage(widget.labels.errorMessage(error));
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _resetCropView() {
    _previewKey.currentState?.resetCropView();
  }

  void _toggleScaleMode() {
    if (_isBusy) {
      return;
    }
    setState(() {
      _cropScaleMode = switch (_cropScaleMode) {
        ImageClipScaleMode.fill => ImageClipScaleMode.fit,
        ImageClipScaleMode.fit => ImageClipScaleMode.fill,
      };
    });
  }

  void _cancelCrop() {
    widget.onCancel?.call();
    if (widget.closeOnCancel) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      _cropAspectRatio = _initialAspectRatio;
      _cropScaleMode = widget.initialScaleMode;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _resetCropView();
      }
    });
    _showMessage(widget.labels.cropResetMessage);
  }

  void _setCropAspectRatio(ImageClipAspectRatio aspectRatio) {
    if (_cropAspectRatio == aspectRatio || _isBusy) {
      return;
    }
    setState(() {
      _cropAspectRatio = aspectRatio;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _resetCropView();
      }
    });
  }
}

/// Displays the cropped image and crop metadata after saving.
class ImageClipResultPage extends StatelessWidget {
  /// Creates a result page for a saved crop [result].
  const ImageClipResultPage({
    super.key,
    required this.result,
    this.labels = const ImageClipEditorLabels(),
    this.theme = const ImageClipEditorTheme.dark(),
  });

  /// Crop result to preview.
  final ImageClipResult result;

  /// User-facing copy used by this result page.
  final ImageClipEditorLabels labels;

  /// Visual tokens used by this result page.
  final ImageClipEditorTheme theme;

  @override
  Widget build(BuildContext context) {
    final region = result.region;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _ResultTopBar(
              labels: labels,
              theme: theme,
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CroppedImagePreview(image: result.cropped, theme: theme),
                    const SizedBox(height: 18),
                    _MetricSection(
                      title: labels.cropDetailsTitle,
                      theme: theme,
                      children: [
                        _MetricTile(
                          label: labels.rotationDegreesLabel,
                          value: '${result.rotationDegrees}°',
                          theme: theme,
                        ),
                        _MetricTile(
                          label: labels.sourceSizeLabel,
                          value:
                              '${result.source.width} x ${result.source.height}',
                          theme: theme,
                        ),
                        _MetricTile(
                          label: 'x',
                          value: '${region.x} px',
                          theme: theme,
                        ),
                        _MetricTile(
                          label: 'y',
                          value: '${region.y} px',
                          theme: theme,
                        ),
                        _MetricTile(
                          label: 'width',
                          value: '${region.width} px',
                          theme: theme,
                        ),
                        _MetricTile(
                          label: 'height',
                          value: '${region.height} px',
                          theme: theme,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _ResultDataPreview(
                      result: result,
                      labels: labels,
                      theme: theme,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultTopBar extends StatelessWidget {
  const _ResultTopBar({
    required this.labels,
    required this.theme,
    required this.onBack,
  });

  final ImageClipEditorLabels labels;
  final ImageClipEditorTheme theme;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.borderColor)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          IconButton(
            onPressed: onBack,
            color: theme.primaryTextColor,
            icon: const Icon(Icons.arrow_back),
            tooltip: labels.backTooltip,
          ),
          const SizedBox(width: 4),
          Text(
            labels.resultTitle,
            style: TextStyle(
              color: theme.primaryTextColor,
              fontSize: 22,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _CroppedImagePreview extends StatelessWidget {
  const _CroppedImagePreview({required this.image, required this.theme});

  final EditedImage image;
  final ImageClipEditorTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 360,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.imageBackgroundColor,
        border: Border.all(color: theme.borderColor),
        borderRadius: BorderRadius.circular(theme.borderRadius),
      ),
      child: Image.memory(
        image.bytes,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

class _MetricSection extends StatelessWidget {
  const _MetricSection({
    required this.title,
    required this.children,
    required this.theme,
  });

  final String title;
  final List<_MetricTile> children;
  final ImageClipEditorTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        border: Border.all(color: theme.borderColor),
        borderRadius: BorderRadius.circular(theme.borderRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: theme.primaryTextColor,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 520 ? 3 : 2;
              final tileWidth =
                  (constraints.maxWidth - (columns - 1) * 10) / columns;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final child in children)
                    SizedBox(width: tileWidth, child: child),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.theme,
  });

  final String label;
  final String value;
  final ImageClipEditorTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.tileColor,
        border: Border.all(color: theme.strongBorderColor),
        borderRadius: BorderRadius.circular(theme.borderRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: theme.secondaryTextColor, fontSize: 13),
          ),
          const SizedBox(height: 5),
          SelectableText(
            value,
            maxLines: 1,
            style: TextStyle(
              color: theme.primaryTextColor,
              fontSize: 17,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultDataPreview extends StatelessWidget {
  const _ResultDataPreview({
    required this.result,
    required this.labels,
    required this.theme,
  });

  final ImageClipResult result;
  final ImageClipEditorLabels labels;
  final ImageClipEditorTheme theme;

  @override
  Widget build(BuildContext context) {
    final region = result.region;
    final data =
        'rotationDegrees: ${result.rotationDegrees}\n'
        'region.x: ${region.x}\n'
        'region.y: ${region.y}\n'
        'region.width: ${region.width}\n'
        'region.height: ${region.height}\n'
        'cropped.width: ${result.cropped.width}\n'
        'cropped.height: ${result.cropped.height}\n'
        'cropped.mimeType: ${result.cropped.mimeType}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        border: Border.all(color: theme.borderColor),
        borderRadius: BorderRadius.circular(theme.borderRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            labels.resultDataTitle,
            style: TextStyle(
              color: theme.primaryTextColor,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          SelectableText(
            data,
            style: TextStyle(
              color: theme.primaryTextColor,
              fontSize: 14,
              height: 1.45,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewPanel extends StatefulWidget {
  const _PreviewPanel({
    super.key,
    required this.image,
    required this.isBusy,
    required this.status,
    required this.cropAspectRatio,
    required this.scaleMode,
    required this.theme,
  });

  final EditedImage? image;
  final bool isBusy;
  final String status;
  final double cropAspectRatio;
  final ImageClipScaleMode scaleMode;
  final ImageClipEditorTheme theme;

  @override
  State<_PreviewPanel> createState() => _PreviewPanelState();
}

class _PreviewPanelState extends State<_PreviewPanel> {
  static const _maxScale = 6.0;

  _CropPreviewLayout? _layout;
  String? _lastImageKey;
  double _scale = 1;
  Offset _offset = Offset.zero;
  double _startScale = 1;
  Offset _startOffset = Offset.zero;
  Offset _startLocalFocalPoint = Offset.zero;

  @override
  void didUpdateWidget(covariant _PreviewPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scaleMode != widget.scaleMode) {
      final layout = _layout;
      if (layout != null) {
        _resetToLayout(layout);
      }
    }
  }

  CropRegion? currentCropRegion({required double cornerRadius}) {
    final image = widget.image;
    final layout = _layout;
    if (image == null || layout == null) {
      return null;
    }

    final imageLeft = layout.baseRect.left + _offset.dx;
    final imageTop = layout.baseRect.top + _offset.dy;
    final pixelsPerLogicalPixel =
        image.width / (layout.baseRect.width * _scale);
    final cropLeft =
        ((layout.cropRect.left - imageLeft) * pixelsPerLogicalPixel)
            .round()
            .clamp(0, image.width - 1)
            .toInt();
    final cropTop = ((layout.cropRect.top - imageTop) * pixelsPerLogicalPixel)
        .round()
        .clamp(0, image.height - 1)
        .toInt();
    final cropRight =
        ((layout.cropRect.right - imageLeft) * pixelsPerLogicalPixel)
            .round()
            .clamp(cropLeft + 1, image.width)
            .toInt();
    final cropBottom =
        ((layout.cropRect.bottom - imageTop) * pixelsPerLogicalPixel)
            .round()
            .clamp(cropTop + 1, image.height)
            .toInt();

    return CropRegion(
      x: cropLeft,
      y: cropTop,
      width: cropRight - cropLeft,
      height: cropBottom - cropTop,
      cornerRadius: cornerRadius,
    );
  }

  @override
  Widget build(BuildContext context) {
    final image = widget.image;
    if (image == null) {
      return _EmptyPreview(status: widget.status, theme: widget.theme);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = _layoutFor(constraints.biggest, image);
        _rememberLayout(layout, image);

        return Listener(
          onPointerSignal: _handlePointerSignal,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: (details) {
              _startScale = _scale;
              _startOffset = _offset;
              _startLocalFocalPoint = details.localFocalPoint;
            },
            onScaleUpdate: (details) {
              final focalImagePoint =
                  (_startLocalFocalPoint -
                      layout.baseRect.topLeft -
                      _startOffset) /
                  _startScale;
              final nextScale = (_startScale * details.scale)
                  .clamp(layout.minScaleFor(widget.scaleMode), _maxScale)
                  .toDouble();
              final nextOffset =
                  details.localFocalPoint -
                  layout.baseRect.topLeft -
                  focalImagePoint * nextScale;

              setState(() {
                _scale = nextScale;
                _offset = _clampOffset(
                  nextOffset,
                  layout,
                  nextScale,
                  widget.scaleMode,
                );
              });
            },
            onDoubleTap: _resetGestureCrop,
            child: ClipRect(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned(
                    left: layout.baseRect.left + _offset.dx,
                    top: layout.baseRect.top + _offset.dy,
                    width: layout.baseRect.width * _scale,
                    height: layout.baseRect.height * _scale,
                    child: Image.memory(
                      image.bytes,
                      fit: BoxFit.fill,
                      gaplessPlayback: true,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                  _CropShade(rect: layout.cropRect, theme: widget.theme),
                  Positioned.fromRect(
                    rect: layout.cropRect,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: widget.theme.cropBorderColor,
                            width: widget.theme.cropBorderWidth,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  _CropPreviewLayout _layoutFor(Size size, EditedImage image) {
    final safeSize = Size(
      size.width.isFinite ? size.width : 1,
      size.height.isFinite ? size.height : 1,
    );
    final imageWidthScale = (safeSize.width / image.width)
        .clamp(0, double.infinity)
        .toDouble();
    final imageHeightScale = (safeSize.height / image.height)
        .clamp(0, double.infinity)
        .toDouble();
    final baseScale = imageWidthScale < imageHeightScale
        ? imageWidthScale
        : imageHeightScale;
    final baseSize = Size(image.width * baseScale, image.height * baseScale);
    final baseRect =
        Offset(
          (safeSize.width - baseSize.width) / 2,
          (safeSize.height - baseSize.height) / 2,
        ) &
        baseSize;
    final cropSize = _cropSizeFor(safeSize, widget.cropAspectRatio);
    final cropRect =
        Offset(
          (safeSize.width - cropSize.width) / 2,
          (safeSize.height - cropSize.height) / 2,
        ) &
        cropSize;
    final cropWidthScale = cropRect.width / baseRect.width;
    final cropHeightScale = cropRect.height / baseRect.height;
    final fitScale = cropWidthScale < cropHeightScale
        ? cropWidthScale
        : cropHeightScale;
    final fillScale = cropWidthScale > cropHeightScale
        ? cropWidthScale
        : cropHeightScale;

    return _CropPreviewLayout(
      size: safeSize,
      baseRect: baseRect,
      cropRect: cropRect,
      fitScale: fitScale,
      fillScale: fillScale,
    );
  }

  void _rememberLayout(_CropPreviewLayout layout, EditedImage image) {
    _layout = layout;
    final imageKey =
        '${image.label}:${image.width}x${image.height}:${image.bytes.length}';
    if (_lastImageKey != imageKey) {
      _lastImageKey = imageKey;
      _resetToLayout(layout);
      return;
    }

    final clampedScale = _scale
        .clamp(layout.minScaleFor(widget.scaleMode), _maxScale)
        .toDouble();
    final clampedOffset = _clampOffset(
      _offset,
      layout,
      clampedScale,
      widget.scaleMode,
    );
    if (clampedScale != _scale || clampedOffset != _offset) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _scale = clampedScale;
          _offset = clampedOffset;
        });
      });
    }
  }

  Offset _clampOffset(
    Offset candidate,
    _CropPreviewLayout layout,
    double scale,
    ImageClipScaleMode scaleMode,
  ) {
    final scaledWidth = layout.baseRect.width * scale;
    final scaledHeight = layout.baseRect.height * scale;

    return Offset(
      _clampAxisOffset(
        candidate.dx,
        cropStart: layout.cropRect.left,
        cropEnd: layout.cropRect.right,
        imageStart: layout.baseRect.left,
        scaledExtent: scaledWidth,
        scaleMode: scaleMode,
      ),
      _clampAxisOffset(
        candidate.dy,
        cropStart: layout.cropRect.top,
        cropEnd: layout.cropRect.bottom,
        imageStart: layout.baseRect.top,
        scaledExtent: scaledHeight,
        scaleMode: scaleMode,
      ),
    );
  }

  double _clampAxisOffset(
    double value, {
    required double cropStart,
    required double cropEnd,
    required double imageStart,
    required double scaledExtent,
    required ImageClipScaleMode scaleMode,
  }) {
    final cropExtent = cropEnd - cropStart;
    final coverMin = cropEnd - imageStart - scaledExtent;
    final coverMax = cropStart - imageStart;
    final containMin = cropStart - imageStart;
    final containMax = cropEnd - imageStart - scaledExtent;
    final useContain =
        scaleMode == ImageClipScaleMode.fit && scaledExtent <= cropExtent;
    final boundA = useContain ? containMin : coverMin;
    final boundB = useContain ? containMax : coverMax;
    final lower = boundA <= boundB ? boundA : boundB;
    final upper = boundA <= boundB ? boundB : boundA;
    return value.clamp(lower, upper).toDouble();
  }

  void _resetToLayout(_CropPreviewLayout layout) {
    _scale = layout.minScaleFor(widget.scaleMode);
    _offset = _clampOffset(Offset.zero, layout, _scale, widget.scaleMode);
  }

  void _resetGestureCrop() {
    final layout = _layout;
    if (layout == null) {
      return;
    }
    setState(() {
      _resetToLayout(layout);
    });
  }

  void resetCropView() {
    _resetGestureCrop();
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || event.scrollDelta.dy == 0) {
      return;
    }

    GestureBinding.instance.pointerSignalResolver.register(event, (
      PointerSignalEvent resolvedEvent,
    ) {
      if (!mounted || resolvedEvent is! PointerScrollEvent) {
        return;
      }
      _zoomBy(
        resolvedEvent.scrollDelta.dy < 0 ? 1.08 : 1 / 1.08,
        focalPoint: resolvedEvent.localPosition,
      );
    });
  }

  void _zoomBy(double factor, {Offset? focalPoint}) {
    final layout = _layout;
    if (layout == null) {
      return;
    }

    final currentScale = _scale
        .clamp(layout.minScaleFor(widget.scaleMode), _maxScale)
        .toDouble();
    final nextScale = (currentScale * factor)
        .clamp(layout.minScaleFor(widget.scaleMode), _maxScale)
        .toDouble();
    if ((nextScale - currentScale).abs() < 0.001) {
      return;
    }

    final anchor = focalPoint ?? layout.cropRect.center;
    final focalImagePoint =
        (anchor - layout.baseRect.topLeft - _offset) / currentScale;
    final nextOffset =
        anchor - layout.baseRect.topLeft - focalImagePoint * nextScale;

    setState(() {
      _scale = nextScale;
      _offset = _clampOffset(nextOffset, layout, nextScale, widget.scaleMode);
    });
  }
}

Size _cropSizeFor(Size size, double aspectRatio) {
  final maxWidth = (size.width - 28).clamp(1, double.infinity).toDouble();
  final maxHeight = (size.height - 36).clamp(1, double.infinity).toDouble();
  if (maxWidth / maxHeight > aspectRatio) {
    return Size(maxHeight * aspectRatio, maxHeight);
  }
  return Size(maxWidth, maxWidth / aspectRatio);
}

class _CropPreviewLayout {
  const _CropPreviewLayout({
    required this.size,
    required this.baseRect,
    required this.cropRect,
    required this.fitScale,
    required this.fillScale,
  });

  final Size size;
  final Rect baseRect;
  final Rect cropRect;
  final double fitScale;
  final double fillScale;

  double minScaleFor(ImageClipScaleMode scaleMode) {
    return switch (scaleMode) {
      ImageClipScaleMode.fit => fitScale,
      ImageClipScaleMode.fill => fillScale,
    };
  }
}

class _CropShade extends StatelessWidget {
  const _CropShade({required this.rect, required this.theme});

  final Rect rect;
  final ImageClipEditorTheme theme;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(painter: _CropShadePainter(rect, theme)),
    );
  }
}

class _CropShadePainter extends CustomPainter {
  const _CropShadePainter(this.rect, this.theme);

  final Rect rect;
  final ImageClipEditorTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    final shade = Paint()..color = theme.cropShadeColor;
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRect(rect);
    canvas.drawPath(path, shade);

    final grid = Paint()
      ..color = theme.cropGridColor
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      final dx = rect.left + rect.width * i / 3;
      final dy = rect.top + rect.height * i / 3;
      canvas.drawLine(Offset(dx, rect.top), Offset(dx, rect.bottom), grid);
      canvas.drawLine(Offset(rect.left, dy), Offset(rect.right, dy), grid);
    }
  }

  @override
  bool shouldRepaint(covariant _CropShadePainter oldDelegate) {
    return oldDelegate.rect != rect || oldDelegate.theme != theme;
  }
}

class _EmptyPreview extends StatelessWidget {
  const _EmptyPreview({required this.status, required this.theme});

  final String status;
  final ImageClipEditorTheme theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        status,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: theme.primaryTextColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _CropTopBar extends StatelessWidget {
  const _CropTopBar({
    required this.isBusy,
    required this.canSave,
    required this.labels,
    required this.theme,
    required this.onCancel,
    required this.onSave,
  });

  final bool isBusy;
  final bool canSave;
  final ImageClipEditorLabels labels;
  final ImageClipEditorTheme theme;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final enabledColor = theme.primaryTextColor;
    final disabledColor = theme.disabledTextColor;

    return Container(
      height: 76,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.borderColor)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 18),
          _TextActionButton(
            label: labels.cancelButton,
            color: enabledColor,
            onPressed: isBusy ? null : onCancel,
          ),
          const Spacer(),
          _TextActionButton(
            label: labels.saveButton,
            color: canSave && !isBusy ? enabledColor : disabledColor,
            onPressed: canSave && !isBusy ? onSave : null,
          ),
          const SizedBox(width: 18),
        ],
      ),
    );
  }
}

class _TextActionButton extends StatelessWidget {
  const _TextActionButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color,
        textStyle: const TextStyle(fontSize: 26, fontWeight: FontWeight.w400),
      ),
      child: Text(label),
    );
  }
}

class _CropBottomBar extends StatelessWidget {
  const _CropBottomBar({
    required this.selectedAspectRatio,
    required this.aspectRatios,
    required this.scaleMode,
    required this.labels,
    required this.theme,
    required this.canRun,
    required this.onScaleModeToggle,
    required this.onRotate,
    required this.onAspectRatioChanged,
  });

  final ImageClipAspectRatio selectedAspectRatio;
  final List<ImageClipAspectRatio> aspectRatios;
  final ImageClipScaleMode scaleMode;
  final ImageClipEditorLabels labels;
  final ImageClipEditorTheme theme;
  final bool canRun;
  final VoidCallback onScaleModeToggle;
  final VoidCallback onRotate;
  final ValueChanged<ImageClipAspectRatio> onAspectRatioChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 500;
        final barHeight = compact ? 202.0 : 236.0;
        final toolGap = compact ? 46.0 : 72.0;
        final modeGap = compact ? 24.0 : 40.0;

        return Container(
          height: barHeight,
          decoration: BoxDecoration(
            color: theme.backgroundColor,
            border: Border(top: BorderSide(color: theme.borderColor)),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: constraints.maxWidth.isFinite
                    ? constraints.maxWidth
                    : 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _CropToolButton(
                          icon: scaleMode == ImageClipScaleMode.fill
                              ? Icons.fit_screen_outlined
                              : Icons.fullscreen_outlined,
                          label: scaleMode == ImageClipScaleMode.fill
                              ? labels.fitButton
                              : labels.fillButton,
                          theme: theme,
                          enabled: canRun,
                          compact: compact,
                          onPressed: onScaleModeToggle,
                        ),
                        SizedBox(width: toolGap),
                        _CropToolButton(
                          icon: Icons.rotate_90_degrees_cw_outlined,
                          label: labels.rotateButton,
                          theme: theme,
                          enabled: canRun,
                          compact: compact,
                          onPressed: onRotate,
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? 18 : 28),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (
                            var index = 0;
                            index < aspectRatios.length;
                            index++
                          )
                            Padding(
                              padding: EdgeInsets.only(
                                left: index == 0 ? 0 : modeGap / 2,
                                right: index == aspectRatios.length - 1
                                    ? 0
                                    : modeGap / 2,
                              ),
                              child: _AspectRatioChoice(
                                aspectRatio: aspectRatios[index],
                                selected:
                                    selectedAspectRatio == aspectRatios[index],
                                theme: theme,
                                enabled: canRun,
                                compact: compact,
                                onSelected: onAspectRatioChanged,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CropToolButton extends StatelessWidget {
  const _CropToolButton({
    required this.icon,
    required this.label,
    required this.theme,
    required this.enabled,
    required this.compact,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final ImageClipEditorTheme theme;
  final bool enabled;
  final bool compact;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? theme.primaryTextColor : theme.disabledTextColor;

    return InkResponse(
      onTap: enabled ? onPressed : null,
      radius: 44,
      child: SizedBox(
        width: compact ? 82 : 92,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: compact ? 32 : 38),
            SizedBox(height: compact ? 6 : 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: compact ? 20 : 22,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AspectRatioChoice extends StatelessWidget {
  const _AspectRatioChoice({
    required this.aspectRatio,
    required this.selected,
    required this.theme,
    required this.enabled,
    required this.compact,
    required this.onSelected,
  });

  final ImageClipAspectRatio aspectRatio;
  final bool selected;
  final ImageClipEditorTheme theme;
  final bool enabled;
  final bool compact;
  final ValueChanged<ImageClipAspectRatio> onSelected;

  @override
  Widget build(BuildContext context) {
    final color = !enabled
        ? theme.disabledTextColor
        : selected
        ? theme.primaryTextColor
        : theme.inactiveTextColor;

    return InkResponse(
      onTap: enabled ? () => onSelected(aspectRatio) : null,
      radius: 48,
      child: SizedBox(
        width: compact ? 104 : 116,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AspectRatioGlyph(
              aspectRatio: aspectRatio,
              color: color,
              theme: theme,
              compact: compact,
            ),
            SizedBox(height: compact ? 8 : 12),
            Text(
              aspectRatio.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: compact ? 20 : 22,
                fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AspectRatioGlyph extends StatelessWidget {
  const _AspectRatioGlyph({
    required this.aspectRatio,
    required this.color,
    required this.theme,
    required this.compact,
  });

  final ImageClipAspectRatio aspectRatio;
  final Color color;
  final ImageClipEditorTheme theme;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final maxWidth = compact ? 54.0 : 62.0;
    final maxHeight = compact ? 42.0 : 48.0;
    final ratio = aspectRatio.value;
    var glyphWidth = maxWidth;
    var glyphHeight = glyphWidth / ratio;
    if (glyphHeight > maxHeight) {
      glyphHeight = maxHeight;
      glyphWidth = glyphHeight * ratio;
    }
    final size = Size(glyphWidth, glyphHeight);

    return SizedBox(
      width: 64,
      height: compact ? 46 : 52,
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: color,
              width: theme.aspectRatioBorderWidth,
            ),
          ),
          child: SizedBox(width: size.width, height: size.height),
        ),
      ),
    );
  }
}
