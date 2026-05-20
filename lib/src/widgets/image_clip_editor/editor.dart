part of '../image_clip_editor.dart';

/// Opens a full-screen image crop editor and returns an [ImageClipResult].
///
/// [initialRotationDegrees] must be a quarter-turn rotation. When
/// [initialCropRegion] is supplied it is interpreted in original source-image
/// pixel coordinates, then clamped to the loaded image bounds before the
/// preview is restored. Non-positive crop sizes are ignored.
///
/// Set [cropAreaHeight] to pin the main crop preview area to a fixed height.
/// When omitted, the preview keeps the default adaptive height.
Future<ImageClipResult?> showImageClipEditor(
  BuildContext context, {
  Uint8List? imageBytes,
  String imageLabel = '',
  ImageProcessor? processor,
  ImageClipCropOrientation initialOrientation =
      ImageClipCropOrientation.portrait,
  ImageClipAspectRatio? initialAspectRatio,
  int initialRotationDegrees = 0,
  CropRegion? initialCropRegion,
  List<ImageClipAspectRatio> aspectRatios = ImageClipAspectRatio.defaults,
  ImageClipScaleMode initialScaleMode = ImageClipScaleMode.fit,
  ImageClipOutputSettings outputSettings = const ImageClipOutputSettings.png(),
  ImageClipDecodeSettings previewDecodeSettings =
      const ImageClipDecodeSettings(),
  ImageClipProcessingSettings processingSettings =
      const ImageClipProcessingSettings(),
  ImageClipEditorLabels labels = const ImageClipEditorLabels(),
  ImageClipEditorTheme theme = const ImageClipEditorTheme(),
  double? cropAreaHeight,
  bool loadSampleOnStart = true,
  bool useRootNavigator = false,
  RouteSettings? routeSettings,
  ValueChanged<ImageClipTaskProgress>? onProgress,
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
          initialRotationDegrees: initialRotationDegrees,
          initialCropRegion: initialCropRegion,
          aspectRatios: aspectRatios,
          initialScaleMode: initialScaleMode,
          outputSettings: outputSettings,
          previewDecodeSettings: previewDecodeSettings,
          processingSettings: processingSettings,
          labels: labels,
          theme: theme,
          cropAreaHeight: cropAreaHeight,
          loadSampleOnStart: loadSampleOnStart,
          closeOnCancel: true,
          closeOnSave: true,
          showResultPage: false,
          onProgress: onProgress,
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
  static const square = ImageClipAspectRatio(label: '1:1', width: 1, height: 1);

  /// Portrait 3:4 crop preset.
  static const portrait = ImageClipAspectRatio(
    label: '3:4',
    width: 3,
    height: 4,
  );

  /// Landscape 4:3 crop preset.
  static const landscape = ImageClipAspectRatio(
    label: '4:3',
    width: 4,
    height: 3,
  );

  /// Widescreen 16:9 crop preset.
  static const widescreen = ImageClipAspectRatio(
    label: '16:9',
    width: 16,
    height: 9,
  );

  /// Landscape 16:10 crop preset.
  static const ratio16x10 = ImageClipAspectRatio(
    label: '16:10',
    width: 16,
    height: 10,
  );

  /// Portrait 10:16 crop preset.
  static const ratio10x16 = ImageClipAspectRatio(
    label: '10:16',
    width: 10,
    height: 16,
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

  /// Creates an aspect ratio from pixel [width] and [height].
  ///
  /// If [presets] contains a ratio with the same numeric value, that preset is
  /// returned so callers keep the intended UI label. Otherwise a new ratio is
  /// created with a reduced label such as `3:4`.
  static ImageClipAspectRatio fromDimensions({
    required int width,
    required int height,
    String? label,
    Iterable<ImageClipAspectRatio> presets = const <ImageClipAspectRatio>[],
  }) {
    if (width <= 0) {
      throw ArgumentError.value(
        width,
        'width',
        'Aspect ratio width must be greater than zero.',
      );
    }
    if (height <= 0) {
      throw ArgumentError.value(
        height,
        'height',
        'Aspect ratio height must be greater than zero.',
      );
    }

    final target = width / height;
    for (final preset in presets) {
      if ((preset.value - target).abs() < _aspectRatioTolerance) {
        return preset;
      }
    }

    final divisor = _greatestCommonDivisor(width, height);
    final reducedWidth = width ~/ divisor;
    final reducedHeight = height ~/ divisor;
    return ImageClipAspectRatio(
      label: label ?? '$reducedWidth:$reducedHeight',
      width: width.toDouble(),
      height: height.toDouble(),
    );
  }

  /// Creates an aspect ratio from a saved [region] and preview rotation.
  ///
  /// [rotationDegrees] must be a quarter-turn rotation. For `90` and `270`
  /// degrees, [CropRegion.width] and [CropRegion.height] are swapped before the
  /// ratio is resolved.
  static ImageClipAspectRatio fromCropRegion(
    CropRegion region, {
    int rotationDegrees = 0,
    String? label,
    Iterable<ImageClipAspectRatio> presets = const <ImageClipAspectRatio>[],
  }) {
    if (!region.hasPositiveSize) {
      throw ArgumentError.value(
        region,
        'region',
        'Crop region width and height must be greater than zero.',
      );
    }
    if (!ImageClipCropTransform.isQuarterTurnRotation(rotationDegrees)) {
      throw ArgumentError.value(
        rotationDegrees,
        'rotationDegrees',
        'Only quarter-turn rotations are supported.',
      );
    }

    final rotated = ImageClipCropTransform(
      rotationDegrees: rotationDegrees,
    ).quarterTurns.isOdd;
    return ImageClipAspectRatio.fromDimensions(
      width: rotated ? region.height : region.width,
      height: rotated ? region.width : region.height,
      label: label,
      presets: presets,
    );
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

/// Embeddable Flutter widget for interactive image clipping.
class ImageClipEditor extends StatefulWidget {
  /// Creates an image crop editor widget.
  const ImageClipEditor({
    super.key,
    this.controller,
    this.processor,
    this.initialImageBytes,
    this.initialImageLabel = '',
    this.initialOrientation = ImageClipCropOrientation.portrait,
    this.initialAspectRatio,
    this.initialRotationDegrees = 0,
    this.initialCropRegion,
    this.aspectRatios = ImageClipAspectRatio.defaults,
    this.initialScaleMode = ImageClipScaleMode.fit,
    this.outputSettings = const ImageClipOutputSettings.png(),
    this.previewDecodeSettings = const ImageClipDecodeSettings(),
    this.processingSettings = const ImageClipProcessingSettings(),
    this.labels = const ImageClipEditorLabels(),
    this.theme = const ImageClipEditorTheme(),
    this.cropAreaHeight,
    this.loadSampleOnStart = true,
    this.closeOnCancel = false,
    this.closeOnSave = false,
    this.showResultPage = true,
    this.onCancel,
    this.onProgress,
    this.onResult,
  }) : assert(initialRotationDegrees % 90 == 0),
       assert(cropAreaHeight == null || cropAreaHeight > 0);

  /// Optional controller used to drive this editor from parent widgets.
  final ImageClipEditorController? controller;

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

  /// Initial clockwise preview rotation in degrees.
  ///
  /// Only quarter-turn rotations are supported. Values outside `0..359` are
  /// normalized, so `-90` and `270` are equivalent.
  final int initialRotationDegrees;

  /// Initial crop position in source-image pixel coordinates.
  ///
  /// When provided, the editor restores the preview scale and offset so this
  /// source region is shown inside the crop frame. The initial crop aspect
  /// ratio is derived from this region and [initialRotationDegrees].
  ///
  /// Coordinates outside the source image are clamped after the image loads.
  /// Regions with non-positive [CropRegion.width] or [CropRegion.height] are
  /// ignored and the editor falls back to [initialAspectRatio] or
  /// [initialOrientation].
  final CropRegion? initialCropRegion;

  /// Aspect ratio presets shown in the bottom toolbar.
  final List<ImageClipAspectRatio> aspectRatios;

  /// Initial image scaling mode.
  final ImageClipScaleMode initialScaleMode;

  /// Output encoding settings used for the saved crop result.
  final ImageClipOutputSettings outputSettings;

  /// Decode settings used for the interactive preview image.
  ///
  /// Set [ImageClipDecodeSettings.targetLongSide] to keep editor previews small
  /// while saving from the original bytes when possible.
  final ImageClipDecodeSettings previewDecodeSettings;

  /// Runtime guardrails used when this widget creates its own processor.
  final ImageClipProcessingSettings processingSettings;

  /// User-facing copy used by the editor.
  final ImageClipEditorLabels labels;

  /// Visual tokens used by the editor.
  final ImageClipEditorTheme theme;

  /// Fixed height for the main crop preview area.
  ///
  /// When null, the preview area fills the remaining vertical space above the
  /// bottom toolbar. When set, the value is clamped at layout time so the bottom
  /// toolbar keeps a usable minimum height on short screens.
  final double? cropAreaHeight;

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

  /// Called when the active image task emits progress.
  final ValueChanged<ImageClipTaskProgress>? onProgress;

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
  int _taskSerial = 0;
  Uint8List? _sourceImageBytes;
  String? _sourceImageLabel;
  ImageClipTask<EditedImage>? _activeTask;
  StreamSubscription<ImageClipTaskProgress>? _activeProgressSubscription;
  double? _progressValue;
  late String _status;
  late ImageClipAspectRatio _cropAspectRatio;
  late ImageClipScaleMode _cropScaleMode;
  int _rotationDegrees = 0;
  int _initialCropRegionRevision = 0;
  bool _flipHorizontal = false;
  bool _flipVertical = false;

  double get _cropAspectRatioValue => _cropAspectRatio.value;

  ImageClipCropTransform get _cropTransform {
    return ImageClipCropTransform(
      rotationDegrees: _rotationDegrees,
      flipHorizontal: _flipHorizontal,
      flipVertical: _flipVertical,
    );
  }

  ImageClipAspectRatio get _initialAspectRatio {
    final region = _validInitialCropRegion;
    if (region != null) {
      return _aspectRatioForInitialRegion(region);
    }
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

  ImageClipCropTransform get _initialCropTransform {
    return ImageClipCropTransform(
      rotationDegrees: widget.initialRotationDegrees,
    );
  }

  CropRegion? get _validInitialCropRegion {
    final region = widget.initialCropRegion;
    if (region == null || !region.hasPositiveSize) {
      return null;
    }
    return region;
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
    _rotationDegrees = _initialCropTransform.normalizedRotation;
    widget.controller?._attach(this);
    unawaited(_loadInitialImage());
  }

  @override
  void didUpdateWidget(covariant ImageClipEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
    if (oldWidget.initialImageBytes != widget.initialImageBytes ||
        oldWidget.initialImageLabel != widget.initialImageLabel) {
      unawaited(_loadInitialImage());
    }
    final initialCropRegionChanged =
        oldWidget.initialRotationDegrees != widget.initialRotationDegrees ||
        oldWidget.initialCropRegion != widget.initialCropRegion;
    if (initialCropRegionChanged ||
        oldWidget.initialAspectRatio != widget.initialAspectRatio ||
        oldWidget.initialOrientation != widget.initialOrientation) {
      setState(() {
        if (initialCropRegionChanged) {
          _initialCropRegionRevision++;
        }
        _cropAspectRatio = _initialAspectRatio;
        _resetPreviewTransform();
      });
    }
  }

  @override
  void dispose() {
    _taskSerial++;
    _activeTask?.cancel();
    unawaited(_activeProgressSubscription?.cancel());
    widget.controller?._detach(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.theme.backgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final busyHeight = _isBusy ? 2.0 : 0.0;
            final cropAreaHeight = _cropAreaHeightFor(
              constraints.maxHeight,
              busyHeight: busyHeight,
            );
            final bottomBarHeight = _bottomBarHeightFor(
              constraints.maxHeight,
              busyHeight: busyHeight,
              cropAreaHeight: cropAreaHeight,
            );
            final preview = KeyedSubtree(
              key: const ValueKey('image_clip_editor_crop_area'),
              child: _PreviewPanel(
                key: _previewKey,
                image: _image,
                isBusy: _isBusy,
                status: _status,
                cropAspectRatio: _cropAspectRatioValue,
                scaleMode: _cropScaleMode,
                transform: _cropTransform,
                initialCropRegion: _initialPreviewCropRegionFor(_image),
                initialCropRegionRevision: _initialCropRegionRevision,
                labels: widget.labels,
                theme: widget.theme,
              ),
            );

            return Column(
              children: [
                _CropTopBar(
                  isBusy: _isBusy,
                  labels: widget.labels,
                  theme: widget.theme,
                  onCancel: _cancelCrop,
                ),
                if (_isBusy)
                  LinearProgressIndicator(
                    value: _progressValue,
                    minHeight: busyHeight,
                    color: widget.theme.progressColor,
                    backgroundColor: widget.theme.borderColor,
                  ),
                if (cropAreaHeight == null)
                  Expanded(child: preview)
                else
                  SizedBox(height: cropAreaHeight, child: preview),
                _CropBottomBar(
                  height: bottomBarHeight,
                  selectedAspectRatio: _cropAspectRatio,
                  aspectRatios: _aspectRatioChoices,
                  scaleMode: _cropScaleMode,
                  labels: widget.labels,
                  theme: widget.theme,
                  canRun: _image != null && !_isBusy,
                  canSave: _image != null && !_isBusy,
                  onScaleModeToggle: _toggleScaleMode,
                  onRotate: _rotateRight,
                  onAspectRatioChanged: _setCropAspectRatio,
                  onSave: _applyCrop,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  double? _cropAreaHeightFor(
    double availableHeight, {
    required double busyHeight,
  }) {
    final requestedHeight = widget.cropAreaHeight;
    if (requestedHeight == null || !availableHeight.isFinite) {
      return requestedHeight;
    }

    final topBarHeight = widget.theme.topBarHeight;
    final compactBottomBarHeight = widget.theme.compactBottomBarHeight;
    final maxHeight =
        availableHeight - topBarHeight - busyHeight - compactBottomBarHeight;
    if (maxHeight <= 0) {
      return 0;
    }
    return requestedHeight.clamp(0, maxHeight).toDouble();
  }

  double _bottomBarHeightFor(
    double availableHeight, {
    required double busyHeight,
    double? cropAreaHeight,
  }) {
    final topBarHeight = widget.theme.topBarHeight;
    final targetBottomBarHeight = widget.theme.bottomBarHeight;
    final compactBottomBarHeight = widget.theme.compactBottomBarHeight;

    if (cropAreaHeight != null && availableHeight.isFinite) {
      final height =
          availableHeight - topBarHeight - busyHeight - cropAreaHeight;
      return height.clamp(0, double.infinity).toDouble();
    }

    if (!availableHeight.isFinite) {
      return targetBottomBarHeight;
    }

    final usableHeight = availableHeight - topBarHeight - busyHeight;
    if (usableHeight <= compactBottomBarHeight) {
      return usableHeight.clamp(0, targetBottomBarHeight).toDouble();
    }

    final minPreviewHeight = (availableHeight * 0.32)
        .clamp(112, targetBottomBarHeight)
        .toDouble();
    final adaptiveHeight = usableHeight - minPreviewHeight;
    return adaptiveHeight
        .clamp(compactBottomBarHeight, targetBottomBarHeight)
        .toDouble();
  }

  Future<void> _loadInitialImage() {
    final bytes = widget.initialImageBytes;
    if (bytes != null) {
      return _runImageTask(
        () => _processor.decodeBytesTask(
          bytes,
          label: _initialImageLabel,
          decodeSettings: widget.previewDecodeSettings,
        ),
        busyLabel: widget.labels.loadingImageStatus,
        doneLabel: widget.labels.imageLoadedStatus,
        replaceCurrent: true,
        onDone: (_) {
          _sourceImageBytes = bytes;
          _sourceImageLabel = _initialImageLabel;
          _resetPreviewTransform();
        },
      );
    }

    if (widget.loadSampleOnStart) {
      return _loadSample(replaceCurrent: true);
    }

    _taskSerial++;
    setState(() {
      _image = null;
      _sourceImageBytes = null;
      _sourceImageLabel = null;
      _status = widget.labels.waitingForImageStatus;
      _resetPreviewTransform();
    });
    return Future<void>.value();
  }

  CropRegion? _initialPreviewCropRegionFor(EditedImage? image) {
    final initialRegion = _validInitialCropRegion;
    if (image == null || initialRegion == null) {
      return null;
    }
    final sourceRegion = initialRegion.clampToBounds(
      sourceWidth: image.sourceWidth,
      sourceHeight: image.sourceHeight,
    );
    final previewSourceRegion = _previewSourceRegionForInitial(
      image,
      sourceRegion,
    );
    return _cropTransform.previewRegionForSource(
      sourceWidth: image.width,
      sourceHeight: image.height,
      sourceRegion: previewSourceRegion,
    );
  }

  CropRegion _previewSourceRegionForInitial(
    EditedImage image,
    CropRegion region,
  ) {
    if (!image.isPreviewSized) {
      return region;
    }
    final scaleX = image.width / image.sourceWidth;
    final scaleY = image.height / image.sourceHeight;
    final x = (region.x * scaleX).round().clamp(0, image.width - 1);
    final y = (region.y * scaleY).round().clamp(0, image.height - 1);
    return CropRegion(
      x: x.toInt(),
      y: y.toInt(),
      width: (region.width * scaleX).round().clamp(1, image.width - x).toInt(),
      height: (region.height * scaleY)
          .round()
          .clamp(1, image.height - y)
          .toInt(),
      cornerRadius: region.cornerRadius * ((scaleX + scaleY) / 2),
    );
  }

  Future<void> _loadControllerImage(Uint8List bytes, {required String label}) {
    final effectiveLabel = label.isEmpty
        ? widget.labels.defaultImageLabel
        : label;
    return _runImageTask(
      () => _processor.decodeBytesTask(
        bytes,
        label: effectiveLabel,
        decodeSettings: widget.previewDecodeSettings,
      ),
      busyLabel: widget.labels.loadingImageStatus,
      doneLabel: widget.labels.imageLoadedStatus,
      replaceCurrent: true,
      onDone: (_) {
        _sourceImageBytes = bytes;
        _sourceImageLabel = effectiveLabel;
        _resetPreviewTransform();
      },
    );
  }

  Future<void> _loadSample({bool replaceCurrent = false}) {
    return _runImageTask(
      () => _processor.createSampleTask(),
      busyLabel: widget.labels.generatingSampleStatus,
      doneLabel: widget.labels.sampleGeneratedStatus,
      replaceCurrent: replaceCurrent,
      onDone: (_) {
        _sourceImageBytes = null;
        _sourceImageLabel = null;
        _resetPreviewTransform();
      },
    );
  }

  void _clearImageFromController() {
    _taskSerial++;
    _activeTask?.cancel();
    _activeTask = null;
    unawaited(_activeProgressSubscription?.cancel());
    _activeProgressSubscription = null;
    setState(() {
      _image = null;
      _sourceImageBytes = null;
      _sourceImageLabel = null;
      _isBusy = false;
      _progressValue = null;
      _resetPreviewTransform();
      _status = widget.labels.waitingForImageStatus;
    });
  }

  CropRegion? _currentPreviewCropRegion({required double cornerRadius}) {
    return _previewKey.currentState?.currentCropRegion(
      cornerRadius: cornerRadius,
    );
  }

  CropRegion? _currentCropRegion({required double cornerRadius}) {
    final source = _image;
    final previewRegion = _currentPreviewCropRegion(cornerRadius: cornerRadius);
    if (source == null || previewRegion == null) {
      return null;
    }
    return _cropTransform.sourceRegionForPreview(
      sourceWidth: source.width,
      sourceHeight: source.height,
      previewRegion: previewRegion,
    );
  }

  bool _cancelActiveTask() {
    final activeTask = _activeTask;
    if (activeTask == null || activeTask.isCompleted) {
      return false;
    }
    _taskSerial++;
    final canceled = activeTask.cancel();
    _activeTask = null;
    unawaited(_activeProgressSubscription?.cancel());
    _activeProgressSubscription = null;
    if (mounted) {
      setState(() {
        _isBusy = false;
        _progressValue = null;
        _status = widget.labels.taskCanceledStatus;
      });
    }
    return canceled;
  }

  Future<ImageClipResult?> _applyCrop() async {
    final source = _image;
    if (source == null) {
      if (widget.loadSampleOnStart) {
        await _loadSample();
        return null;
      }
      _showMessage(widget.labels.imageRequiredMessage);
      return null;
    }
    final region = _currentPreviewCropRegion(cornerRadius: 0);
    final transform = _cropTransform;
    final visualSize = transform.visualSize(
      sourceWidth: source.width,
      sourceHeight: source.height,
    );
    final previewRegion =
        region ??
        CropRegion(
          x: 0,
          y: 0,
          width: visualSize.width,
          height: visualSize.height,
          cornerRadius: 0,
        );
    final sourceRegion = transform.sourceRegionForPreview(
      sourceWidth: source.width,
      sourceHeight: source.height,
      previewRegion: previewRegion,
    );

    return _saveCropResult(
      source: source,
      sourceRegion: sourceRegion,
      previewRegion: previewRegion,
      transform: transform,
    );
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
    setState(() {
      _rotationDegrees = _cropTransform
          .copyWith(rotationDegrees: _rotationDegrees + 90)
          .normalizedRotation;
      _status = widget.labels.rotationCompleteStatus;
    });
    return Future<void>.value();
  }

  Future<void> _flipHorizontalPreview() {
    return _updatePreviewFlip(horizontal: true);
  }

  Future<void> _flipVerticalPreview() {
    return _updatePreviewFlip(horizontal: false);
  }

  Future<void> _updatePreviewFlip({required bool horizontal}) {
    final source = _image;
    if (source == null) {
      if (widget.loadSampleOnStart) {
        return _loadSample();
      }
      _showMessage(widget.labels.imageRequiredMessage);
      return Future<void>.value();
    }
    setState(() {
      if (horizontal) {
        _flipHorizontal = !_flipHorizontal;
      } else {
        _flipVertical = !_flipVertical;
      }
      _status = widget.labels.flipPreviewStatus;
    });
    return Future<void>.value();
  }

  Future<void> _runImageTask(
    ImageClipTask<EditedImage> Function() task, {
    required String busyLabel,
    required String doneLabel,
    bool replaceCurrent = false,
    void Function(EditedImage result)? onDone,
  }) async {
    if (_isBusy && !replaceCurrent) {
      return;
    }
    final taskId = ++_taskSerial;
    if (replaceCurrent) {
      _activeTask?.cancel();
      unawaited(_activeProgressSubscription?.cancel());
      _activeProgressSubscription = null;
    }

    setState(() {
      _isBusy = true;
      _progressValue = 0;
      _status = busyLabel;
    });

    try {
      final activeTask = task();
      _activeTask = activeTask;
      _listenToProgress(activeTask, taskId);
      final result = await activeTask.result;
      if (!mounted || taskId != _taskSerial) {
        return;
      }
      unawaited(_activeProgressSubscription?.cancel());
      setState(() {
        _image = result;
        _isBusy = false;
        _activeTask = null;
        _activeProgressSubscription = null;
        _progressValue = null;
        onDone?.call(result);
        _status = widget.labels.completedStatus(doneLabel, result);
      });
    } catch (error) {
      if (!mounted || taskId != _taskSerial) {
        return;
      }
      setState(() {
        _isBusy = false;
        _activeTask = null;
        _activeProgressSubscription = null;
        _progressValue = null;
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

  void _listenToProgress(ImageClipTask<EditedImage> task, int taskId) {
    unawaited(_activeProgressSubscription?.cancel());
    _activeProgressSubscription = task.progress.listen((progress) {
      if (!mounted || taskId != _taskSerial) {
        return;
      }
      setState(() {
        _progressValue = progress.fraction.clamp(0, 1).toDouble();
      });
      widget.onProgress?.call(progress);
    });
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

  void _resetPreviewTransform() {
    _rotationDegrees = _initialCropTransform.normalizedRotation;
    _flipHorizontal = false;
    _flipVertical = false;
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
      _resetPreviewTransform();
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

  ImageClipAspectRatio _aspectRatioForInitialRegion(CropRegion region) {
    return ImageClipAspectRatio.fromCropRegion(
      region,
      rotationDegrees: widget.initialRotationDegrees,
      presets: widget.aspectRatios.isEmpty
          ? ImageClipAspectRatio.defaults
          : widget.aspectRatios,
    );
  }
}

const _aspectRatioTolerance = 0.001;

int _greatestCommonDivisor(int a, int b) {
  var x = a.abs();
  var y = b.abs();
  while (y != 0) {
    final next = x % y;
    x = y;
    y = next;
  }
  return x == 0 ? 1 : x;
}
