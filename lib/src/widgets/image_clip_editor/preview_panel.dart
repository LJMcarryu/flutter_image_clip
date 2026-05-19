part of '../image_clip_editor.dart';

class _PreviewPanel extends StatefulWidget {
  const _PreviewPanel({
    super.key,
    required this.image,
    required this.isBusy,
    required this.status,
    required this.cropAspectRatio,
    required this.scaleMode,
    required this.transform,
    required this.labels,
    required this.theme,
  });

  final EditedImage? image;
  final bool isBusy;
  final String status;
  final double cropAspectRatio;
  final ImageClipScaleMode scaleMode;
  final ImageClipCropTransform transform;
  final ImageClipEditorLabels labels;
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
    if (oldWidget.scaleMode != widget.scaleMode ||
        oldWidget.transform != widget.transform) {
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

    final visualSize = widget.transform.visualSize(
      sourceWidth: image.width,
      sourceHeight: image.height,
    );
    final imageLeft = layout.baseRect.left + _offset.dx;
    final imageTop = layout.baseRect.top + _offset.dy;
    final pixelsPerLogicalPixel =
        visualSize.width / (layout.baseRect.width * _scale);
    final cropLeft =
        ((layout.cropRect.left - imageLeft) * pixelsPerLogicalPixel)
            .round()
            .clamp(0, visualSize.width - 1)
            .toInt();
    final cropTop = ((layout.cropRect.top - imageTop) * pixelsPerLogicalPixel)
        .round()
        .clamp(0, visualSize.height - 1)
        .toInt();
    final cropRight =
        ((layout.cropRect.right - imageLeft) * pixelsPerLogicalPixel)
            .round()
            .clamp(cropLeft + 1, visualSize.width)
            .toInt();
    final cropBottom =
        ((layout.cropRect.bottom - imageTop) * pixelsPerLogicalPixel)
            .round()
            .clamp(cropTop + 1, visualSize.height)
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

        return Semantics(
          label: widget.labels.previewSemanticsLabel,
          value: '${image.label}, ${image.dimensionsLabel}, ${widget.status}',
          image: true,
          child: Listener(
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
                      child: Transform.scale(
                        scaleX: widget.transform.flipHorizontal ? -1 : 1,
                        scaleY: widget.transform.flipVertical ? -1 : 1,
                        child: RotatedBox(
                          quarterTurns: widget.transform.quarterTurns,
                          child: Image.memory(
                            image.bytes,
                            fit: BoxFit.fill,
                            gaplessPlayback: true,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                      ),
                    ),
                    _CropShade(rect: layout.cropRect, theme: widget.theme),
                    Positioned.fromRect(
                      rect: layout.cropRect,
                      child: IgnorePointer(
                        child: Semantics(
                          label: widget.labels.cropFrameSemanticsLabel,
                          value:
                              '${layout.cropRect.width.round()} x '
                              '${layout.cropRect.height.round()}',
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

  _CropPreviewLayout _layoutFor(Size size, EditedImage image) {
    final safeSize = Size(
      size.width.isFinite ? size.width : 1,
      size.height.isFinite ? size.height : 1,
    );
    final visualSize = widget.transform.visualSize(
      sourceWidth: image.width,
      sourceHeight: image.height,
    );
    final imageWidthScale = (safeSize.width / visualSize.width)
        .clamp(0, double.infinity)
        .toDouble();
    final imageHeightScale = (safeSize.height / visualSize.height)
        .clamp(0, double.infinity)
        .toDouble();
    final baseScale = imageWidthScale < imageHeightScale
        ? imageWidthScale
        : imageHeightScale;
    final baseSize = Size(
      visualSize.width * baseScale,
      visualSize.height * baseScale,
    );
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
        '${image.label}:${image.width}x${image.height}:'
        '${image.bytes.length}:r${widget.transform.normalizedRotation}:'
        'h${widget.transform.flipHorizontal}:v${widget.transform.flipVertical}';
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
