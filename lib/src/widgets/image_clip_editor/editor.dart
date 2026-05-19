part of '../image_clip_editor.dart';

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
  ImageClipDecodeSettings previewDecodeSettings =
      const ImageClipDecodeSettings(),
  ImageClipProcessingSettings processingSettings =
      const ImageClipProcessingSettings(),
  ImageClipEditorLabels labels = const ImageClipEditorLabels(),
  ImageClipEditorTheme theme = const ImageClipEditorTheme.dark(),
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
          aspectRatios: aspectRatios,
          initialScaleMode: initialScaleMode,
          outputSettings: outputSettings,
          previewDecodeSettings: previewDecodeSettings,
          processingSettings: processingSettings,
          labels: labels,
          theme: theme,
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
    this.aspectRatios = ImageClipAspectRatio.defaults,
    this.initialScaleMode = ImageClipScaleMode.fill,
    this.outputSettings = const ImageClipOutputSettings.png(),
    this.previewDecodeSettings = const ImageClipDecodeSettings(),
    this.processingSettings = const ImageClipProcessingSettings(),
    this.labels = const ImageClipEditorLabels(),
    this.theme = const ImageClipEditorTheme.dark(),
    this.loadSampleOnStart = true,
    this.closeOnCancel = false,
    this.closeOnSave = false,
    this.showResultPage = true,
    this.onCancel,
    this.onProgress,
    this.onResult,
  });

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
                value: _progressValue,
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
                transform: _cropTransform,
                labels: widget.labels,
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
              onFlipHorizontal: _flipHorizontalPreview,
              onFlipVertical: _flipVerticalPreview,
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

  Future<ImageClipResult?> _saveCropResult({
    required EditedImage source,
    required CropRegion sourceRegion,
    required CropRegion previewRegion,
    required ImageClipCropTransform transform,
  }) async {
    if (_isBusy) {
      return null;
    }
    final taskId = ++_taskSerial;
    _activeTask?.cancel();
    unawaited(_activeProgressSubscription?.cancel());
    _activeProgressSubscription = null;

    setState(() {
      _isBusy = true;
      _progressValue = 0;
      _status = widget.labels.croppingStatus;
    });

    try {
      final saveRegion = _sourceRegionForSave(source, sourceRegion);
      final steps = <ImageClipPipelineStep>[
        ImageClipPipelineStep.cropRegion(saveRegion),
        if (transform.normalizedRotation != 0)
          ImageClipPipelineStep.rotate(degrees: transform.normalizedRotation),
        if (transform.flipHorizontal)
          const ImageClipPipelineStep.flipHorizontal(),
        if (transform.flipVertical) const ImageClipPipelineStep.flipVertical(),
      ];
      final saveBytes = _sourceImageBytes;
      final sourceLabel = _sourceImageLabel ?? source.label;
      final saveFromOriginal = saveBytes != null && source.isPreviewSized;
      final activeTask = saveFromOriginal
          ? _processor.processBytesTask(
              saveBytes,
              label: sourceLabel,
              steps: steps,
              outputSettings: widget.outputSettings,
              operationLabel: 'Crop',
            )
          : _processor.processPipelineTask(
              ImageClipPipeline.fromImage(
                source: source,
                steps: steps,
                outputSettings: widget.outputSettings,
                operationLabel: 'Crop',
              ),
            );
      _activeTask = activeTask;
      _listenToProgress(activeTask, taskId);
      final cropped = await activeTask.result;
      if (!mounted || taskId != _taskSerial) {
        return null;
      }
      final result = ImageClipResult(
        source: source,
        cropped: cropped,
        region: saveRegion,
        previewRegion: previewRegion,
        rotationDegrees: transform.normalizedRotation,
        flippedHorizontally: transform.flipHorizontal,
        flippedVertically: transform.flipVertical,
      );
      setState(() {
        _isBusy = false;
        _activeTask = null;
        _activeProgressSubscription = null;
        _progressValue = null;
        _status = widget.labels.completedStatus(
          widget.labels.cropCompleteStatus,
          cropped,
        );
      });
      widget.onResult?.call(result);
      if (widget.closeOnSave) {
        Navigator.of(context).pop(result);
        return result;
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
      return result;
    } catch (error) {
      if (!mounted || taskId != _taskSerial) {
        return null;
      }
      setState(() {
        _isBusy = false;
        _activeTask = null;
        _activeProgressSubscription = null;
        _progressValue = null;
        _status = widget.labels.errorMessage(error);
      });
      _showMessage(widget.labels.errorMessage(error));
      return null;
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
    _rotationDegrees = 0;
    _flipHorizontal = false;
    _flipVertical = false;
  }

  CropRegion _sourceRegionForSave(EditedImage source, CropRegion region) {
    if (!source.isPreviewSized) {
      return region;
    }
    final scaleX = source.sourceWidth / source.width;
    final scaleY = source.sourceHeight / source.height;
    final x = (region.x * scaleX).round().clamp(0, source.sourceWidth - 1);
    final y = (region.y * scaleY).round().clamp(0, source.sourceHeight - 1);
    return CropRegion(
      x: x.toInt(),
      y: y.toInt(),
      width: (region.width * scaleX)
          .round()
          .clamp(1, source.sourceWidth - x)
          .toInt(),
      height: (region.height * scaleY)
          .round()
          .clamp(1, source.sourceHeight - y)
          .toInt(),
      cornerRadius: region.cornerRadius * ((scaleX + scaleY) / 2),
    );
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
