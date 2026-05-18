import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../image_processing/image_processor.dart';

/// 打开完整图片裁剪界面，保存后返回 [ImageClipResult]。
Future<ImageClipResult?> showImageClipEditor(
  BuildContext context, {
  Uint8List? imageBytes,
  String imageLabel = '待裁剪图片',
  ImageProcessor? processor,
  ImageClipCropOrientation initialOrientation =
      ImageClipCropOrientation.portrait,
  ImageClipScaleMode initialScaleMode = ImageClipScaleMode.fill,
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
          initialScaleMode: initialScaleMode,
          loadSampleOnStart: loadSampleOnStart,
          closeOnCancel: true,
          closeOnSave: true,
          showResultPage: false,
        );
      },
    ),
  );
}

enum ImageClipCropOrientation { portrait, landscape }

enum ImageClipScaleMode { fit, fill }

class ImageClipResult {
  const ImageClipResult({
    required this.source,
    required this.cropped,
    required this.region,
    required this.rotationDegrees,
  });

  final EditedImage source;
  final EditedImage cropped;
  final CropRegion region;
  final int rotationDegrees;

  Map<String, Object?> toMap() => <String, Object?>{
    'source': source.toMap(),
    'cropped': cropped.toMap(),
    'region': region.toMap(),
    'rotationDegrees': rotationDegrees,
  };
}

class ImageClipEditor extends StatefulWidget {
  const ImageClipEditor({
    super.key,
    this.processor,
    this.initialImageBytes,
    this.initialImageLabel = '待裁剪图片',
    this.initialOrientation = ImageClipCropOrientation.portrait,
    this.initialScaleMode = ImageClipScaleMode.fill,
    this.loadSampleOnStart = true,
    this.closeOnCancel = false,
    this.closeOnSave = false,
    this.showResultPage = true,
    this.onCancel,
    this.onResult,
  });

  final ImageProcessor? processor;
  final Uint8List? initialImageBytes;
  final String initialImageLabel;
  final ImageClipCropOrientation initialOrientation;
  final ImageClipScaleMode initialScaleMode;
  final bool loadSampleOnStart;
  final bool closeOnCancel;
  final bool closeOnSave;
  final bool showResultPage;
  final VoidCallback? onCancel;
  final ValueChanged<ImageClipResult>? onResult;

  @override
  State<ImageClipEditor> createState() => _ImageClipEditorState();
}

class _ImageClipEditorState extends State<ImageClipEditor> {
  late final ImageProcessor _processor;
  final _previewKey = GlobalKey<_PreviewPanelState>();

  EditedImage? _image;
  bool _isBusy = false;
  String _status = '选择图片开始剪辑';
  late ImageClipCropOrientation _cropOrientation;
  late ImageClipScaleMode _cropScaleMode;
  int _rotationDegrees = 0;

  double get _cropAspectRatio => switch (_cropOrientation) {
    ImageClipCropOrientation.portrait => 3 / 4,
    ImageClipCropOrientation.landscape => 4 / 3,
  };

  @override
  void initState() {
    super.initState();
    _processor = widget.processor ?? ImageProcessor();
    _cropOrientation = widget.initialOrientation;
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
      backgroundColor: const Color(0xFF101113),
      body: SafeArea(
        child: Column(
          children: [
            _CropTopBar(
              isBusy: _isBusy,
              canSave: _image != null,
              onCancel: _cancelCrop,
              onSave: _applyCrop,
            ),
            if (_isBusy) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: _PreviewPanel(
                key: _previewKey,
                image: _image,
                isBusy: _isBusy,
                status: _status,
                cropAspectRatio: _cropAspectRatio,
                scaleMode: _cropScaleMode,
              ),
            ),
            _CropBottomBar(
              selectedOrientation: _cropOrientation,
              scaleMode: _cropScaleMode,
              canRun: _image != null && !_isBusy,
              onScaleModeToggle: _toggleScaleMode,
              onRotate: _rotateRight,
              onOrientationChanged: _setCropOrientation,
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
        () => _processor.decodeBytes(bytes, label: widget.initialImageLabel),
        busyLabel: '正在载入图片',
        doneLabel: '图片已载入',
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
      _status = '等待传入图片';
      _rotationDegrees = 0;
    });
    return Future<void>.value();
  }

  Future<void> _loadSample() {
    return _runImageTask(
      () => _processor.createSample(),
      busyLabel: '正在生成示例图',
      doneLabel: '示例图已生成',
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
      _showMessage('请先传入图片');
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
      _showMessage('请先传入图片');
      return Future<void>.value();
    }
    return _runImageTask(
      () => _processor.rotateRight(source),
      busyLabel: '正在旋转',
      doneLabel: '旋转完成',
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
        _status =
            '$doneLabel：${result.dimensionsLabel}，${result.bytesLabel}，${result.elapsedMs} ms';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isBusy = false;
        _status = '处理失败：$error';
      });
      _showMessage('处理失败：$error');
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
      _status = '正在裁剪';
    });

    try {
      final cropped = await _processor.cropRegion(source, region);
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
        _status =
            '裁剪完成：${cropped.dimensionsLabel}，${cropped.bytesLabel}，${cropped.elapsedMs} ms';
      });
      widget.onResult?.call(result);
      if (widget.closeOnSave) {
        Navigator.of(context).pop(result);
        return;
      }
      if (widget.showResultPage) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => ImageClipResultPage(result: result),
          ),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isBusy = false;
        _status = '处理失败：$error';
      });
      _showMessage('处理失败：$error');
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
      _cropOrientation = widget.initialOrientation;
      _cropScaleMode = widget.initialScaleMode;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _resetCropView();
      }
    });
    _showMessage('已复位裁剪框');
  }

  void _setCropOrientation(ImageClipCropOrientation orientation) {
    if (_cropOrientation == orientation || _isBusy) {
      return;
    }
    setState(() {
      _cropOrientation = orientation;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _resetCropView();
      }
    });
  }
}

class ImageClipResultPage extends StatelessWidget {
  const ImageClipResultPage({super.key, required this.result});

  final ImageClipResult result;

  @override
  Widget build(BuildContext context) {
    final region = result.region;

    return Scaffold(
      backgroundColor: const Color(0xFF101113),
      body: SafeArea(
        child: Column(
          children: [
            _ResultTopBar(onBack: () => Navigator.of(context).pop()),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CroppedImagePreview(image: result.cropped),
                    const SizedBox(height: 18),
                    _MetricSection(
                      title: '截图信息',
                      children: [
                        _MetricTile(
                          label: '旋转角度',
                          value: '${result.rotationDegrees}°',
                        ),
                        _MetricTile(
                          label: '原图尺寸',
                          value:
                              '${result.source.width} x ${result.source.height}',
                        ),
                        _MetricTile(label: 'x', value: '${region.x} px'),
                        _MetricTile(label: 'y', value: '${region.y} px'),
                        _MetricTile(
                          label: 'width',
                          value: '${region.width} px',
                        ),
                        _MetricTile(
                          label: 'height',
                          value: '${region.height} px',
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _ResultDataPreview(result: result),
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
  const _ResultTopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF2A2B2E))),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          IconButton(
            onPressed: onBack,
            color: const Color(0xFFF7F7F7),
            icon: const Icon(Icons.arrow_back),
            tooltip: '返回',
          ),
          const SizedBox(width: 4),
          const Text(
            '裁剪结果',
            style: TextStyle(
              color: Color(0xFFF7F7F7),
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
  const _CroppedImagePreview({required this.image});

  final EditedImage image;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 360,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF17181B),
        border: Border.all(color: const Color(0xFF2A2B2E)),
        borderRadius: BorderRadius.circular(8),
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
  const _MetricSection({required this.title, required this.children});

  final String title;
  final List<_MetricTile> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF18191C),
        border: Border.all(color: const Color(0xFF2A2B2E)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFF2F2F2),
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
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF222326),
        border: Border.all(color: const Color(0xFF333439)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF9D9EA3), fontSize: 13),
          ),
          const SizedBox(height: 5),
          SelectableText(
            value,
            maxLines: 1,
            style: const TextStyle(
              color: Color(0xFFF4F4F4),
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
  const _ResultDataPreview({required this.result});

  final ImageClipResult result;

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
        'cropped.height: ${result.cropped.height}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF18191C),
        border: Border.all(color: const Color(0xFF2A2B2E)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '返回数据',
            style: TextStyle(
              color: Color(0xFFF2F2F2),
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          SelectableText(
            data,
            style: const TextStyle(
              color: Color(0xFFE7E7E7),
              fontSize: 14,
              height: 1.45,
              fontFeatures: [FontFeature.tabularFigures()],
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
  });

  final EditedImage? image;
  final bool isBusy;
  final String status;
  final double cropAspectRatio;
  final ImageClipScaleMode scaleMode;

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
      return _EmptyPreview(status: widget.status);
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
                  _CropShade(rect: layout.cropRect),
                  Positioned.fromRect(
                    rect: layout.cropRect,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xCCFFFFFF),
                            width: 1.2,
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
  const _CropShade({required this.rect});

  final Rect rect;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(child: CustomPaint(painter: _CropShadePainter(rect)));
  }
}

class _CropShadePainter extends CustomPainter {
  const _CropShadePainter(this.rect);

  final Rect rect;

  @override
  void paint(Canvas canvas, Size size) {
    final shade = Paint()..color = const Color(0x99000000);
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRect(rect);
    canvas.drawPath(path, shade);

    final grid = Paint()
      ..color = const Color(0x99FFFFFF)
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
    return oldDelegate.rect != rect;
  }
}

class _EmptyPreview extends StatelessWidget {
  const _EmptyPreview({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        status,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: const Color(0xFFE7E7E7),
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
    required this.onCancel,
    required this.onSave,
  });

  final bool isBusy;
  final bool canSave;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final enabledColor = const Color(0xFFF7F7F7);
    final disabledColor = enabledColor.withValues(alpha: 0.38);

    return Container(
      height: 76,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF2A2B2E))),
      ),
      child: Row(
        children: [
          const SizedBox(width: 18),
          _TextActionButton(
            label: 'Cancel',
            color: enabledColor,
            onPressed: isBusy ? null : onCancel,
          ),
          const Spacer(),
          _TextActionButton(
            label: 'Save',
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
    required this.selectedOrientation,
    required this.scaleMode,
    required this.canRun,
    required this.onScaleModeToggle,
    required this.onRotate,
    required this.onOrientationChanged,
  });

  final ImageClipCropOrientation selectedOrientation;
  final ImageClipScaleMode scaleMode;
  final bool canRun;
  final VoidCallback onScaleModeToggle;
  final VoidCallback onRotate;
  final ValueChanged<ImageClipCropOrientation> onOrientationChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 500;
        final barHeight = compact ? 202.0 : 236.0;
        final toolGap = compact ? 46.0 : 72.0;
        final modeGap = compact ? 32.0 : 54.0;

        return Container(
          height: barHeight,
          decoration: const BoxDecoration(
            color: Color(0xFF101113),
            border: Border(top: BorderSide(color: Color(0xFF2A2B2E))),
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
                              ? 'Fit'
                              : 'Fill',
                          enabled: canRun,
                          compact: compact,
                          onPressed: onScaleModeToggle,
                        ),
                        SizedBox(width: toolGap),
                        _CropToolButton(
                          icon: Icons.rotate_90_degrees_cw_outlined,
                          label: 'Rotate',
                          enabled: canRun,
                          compact: compact,
                          onPressed: onRotate,
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? 18 : 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _OrientationChoice(
                          label: 'Portrait',
                          orientation: ImageClipCropOrientation.portrait,
                          selected:
                              selectedOrientation ==
                              ImageClipCropOrientation.portrait,
                          enabled: canRun,
                          compact: compact,
                          onSelected: onOrientationChanged,
                        ),
                        SizedBox(width: modeGap),
                        _OrientationChoice(
                          label: 'Landscape',
                          orientation: ImageClipCropOrientation.landscape,
                          selected:
                              selectedOrientation ==
                              ImageClipCropOrientation.landscape,
                          enabled: canRun,
                          compact: compact,
                          onSelected: onOrientationChanged,
                        ),
                      ],
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
    required this.enabled,
    required this.compact,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final bool compact;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? const Color(0xFFF4F4F4) : const Color(0xFF5A5B5E);

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

class _OrientationChoice extends StatelessWidget {
  const _OrientationChoice({
    required this.label,
    required this.orientation,
    required this.selected,
    required this.enabled,
    required this.compact,
    required this.onSelected,
  });

  final String label;
  final ImageClipCropOrientation orientation;
  final bool selected;
  final bool enabled;
  final bool compact;
  final ValueChanged<ImageClipCropOrientation> onSelected;

  @override
  Widget build(BuildContext context) {
    final color = !enabled
        ? const Color(0xFF4F5053)
        : selected
        ? const Color(0xFFF1F1F1)
        : const Color(0xFF6D6E72);

    return InkResponse(
      onTap: enabled ? () => onSelected(orientation) : null,
      radius: 48,
      child: SizedBox(
        width: compact ? 104 : 116,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _OrientationGlyph(
              orientation: orientation,
              color: color,
              compact: compact,
            ),
            SizedBox(height: compact ? 8 : 12),
            Text(
              label,
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

class _OrientationGlyph extends StatelessWidget {
  const _OrientationGlyph({
    required this.orientation,
    required this.color,
    required this.compact,
  });

  final ImageClipCropOrientation orientation;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = switch ((orientation, compact)) {
      (ImageClipCropOrientation.portrait, true) => const Size(30, 42),
      (ImageClipCropOrientation.portrait, false) => const Size(34, 48),
      (ImageClipCropOrientation.landscape, true) => const Size(50, 32),
      (ImageClipCropOrientation.landscape, false) => const Size(58, 36),
    };

    return SizedBox(
      width: 64,
      height: compact ? 46 : 52,
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 1.6),
          ),
          child: SizedBox(width: size.width, height: size.height),
        ),
      ),
    );
  }
}
