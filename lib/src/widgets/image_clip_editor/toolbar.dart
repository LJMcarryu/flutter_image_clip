part of '../image_clip_editor.dart';

class _CropTopBar extends StatelessWidget {
  const _CropTopBar({
    required this.isBusy,
    required this.labels,
    required this.theme,
    required this.onCancel,
  });

  final bool isBusy;
  final ImageClipEditorLabels labels;
  final ImageClipEditorTheme theme;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: theme.topBarHeight,
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        border: Border(bottom: BorderSide(color: theme.borderColor)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              labels.editorTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.primaryTextColor,
                fontSize: 20,
                height: 1.4,
                letterSpacing: 0,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Semantics(
            button: true,
            enabled: !isBusy,
            label: labels.cancelButton,
            child: ExcludeSemantics(
              child: Tooltip(
                message: labels.cancelButton,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: isBusy ? null : onCancel,
                  child: SizedBox.square(
                    key: const ValueKey('image_clip_editor_close_hit_area'),
                    dimension: 44,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox.square(
                        key: const ValueKey('image_clip_editor_close_icon'),
                        dimension: 20,
                        child: CustomPaint(
                          painter: _CloseGlyphPainter(
                            color: isBusy
                                ? theme.disabledTextColor
                                : theme.closeIconColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CloseGlyphPainter extends CustomPainter {
  const _CloseGlyphPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;
    final left = size.width * 0.2;
    final right = size.width * 0.8;
    final top = size.height * 0.2;
    final bottom = size.height * 0.8;
    canvas.drawLine(Offset(left, top), Offset(right, bottom), paint);
    canvas.drawLine(Offset(right, top), Offset(left, bottom), paint);
  }

  @override
  bool shouldRepaint(covariant _CloseGlyphPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _CropBottomBar extends StatelessWidget {
  const _CropBottomBar({
    required this.height,
    required this.selectedAspectRatio,
    required this.aspectRatios,
    required this.scaleMode,
    required this.labels,
    required this.theme,
    required this.canRun,
    required this.canSave,
    required this.showRevert,
    required this.onScaleModeToggle,
    required this.onRotate,
    required this.onRevert,
    required this.onAspectRatioChanged,
    required this.onSave,
  });

  final double height;
  final ImageClipAspectRatio selectedAspectRatio;
  final List<ImageClipAspectRatio> aspectRatios;
  final ImageClipScaleMode scaleMode;
  final ImageClipEditorLabels labels;
  final ImageClipEditorTheme theme;
  final bool canRun;
  final bool canSave;
  final bool showRevert;
  final VoidCallback onScaleModeToggle;
  final VoidCallback onRotate;
  final VoidCallback onRevert;
  final ValueChanged<ImageClipAspectRatio> onAspectRatioChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final barWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 375.0;
        final saveWidth = (barWidth - theme.bottomBarHorizontalPadding * 2)
            .clamp(0, theme.maxSaveButtonWidth)
            .toDouble();

        return Container(
          height: height,
          decoration: BoxDecoration(
            color: theme.surfaceColor,
            border: Border(top: BorderSide(color: theme.borderColor)),
          ),
          child: ClipRect(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: SizedBox(
                width: barWidth,
                height: theme.bottomBarContentHeight,
                child: Stack(
                  children: [
                    Positioned(
                      left: theme.bottomBarHorizontalPadding,
                      right: theme.bottomBarHorizontalPadding,
                      top: theme.positionHintTop,
                      child: Text(
                        labels.positionHint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: theme.secondaryTextColor,
                          fontSize: 11,
                          height: 1.48,
                          letterSpacing: 0.11,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    Positioned(
                      top: theme.toolRowTop,
                      left: 0,
                      right: 0,
                      height: 48,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _CropToolButton(
                            icon: scaleMode == ImageClipScaleMode.fill
                                ? _CropToolIcon.fit
                                : _CropToolIcon.fill,
                            label: scaleMode == ImageClipScaleMode.fill
                                ? labels.fitButton
                                : labels.fillButton,
                            theme: theme,
                            enabled: canRun,
                            onPressed: onScaleModeToggle,
                          ),
                          SizedBox(width: theme.toolButtonGap),
                          _CropToolButton(
                            icon: _CropToolIcon.rotate,
                            label: labels.rotateButton,
                            theme: theme,
                            enabled: canRun,
                            onPressed: onRotate,
                          ),
                          if (showRevert) ...[
                            SizedBox(width: theme.toolButtonGap),
                            _CropToolButton(
                              icon: _CropToolIcon.revert,
                              label: labels.revertButton,
                              theme: theme,
                              enabled: canRun,
                              onPressed: onRevert,
                            ),
                          ],
                        ],
                      ),
                    ),
                    Positioned(
                      top: theme.aspectRatioRowTop,
                      left: 0,
                      right: 0,
                      height: 57,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minWidth: barWidth),
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
                                    left: index == 0 ? 0 : theme.aspectRatioGap,
                                  ),
                                  child: _AspectRatioChoice(
                                    aspectRatio: aspectRatios[index],
                                    selected:
                                        selectedAspectRatio ==
                                        aspectRatios[index],
                                    theme: theme,
                                    enabled: canRun,
                                    onSelected: onAspectRatioChanged,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: theme.saveButtonTop,
                      left: 0,
                      right: 0,
                      height: theme.saveButtonHeight,
                      child: Center(
                        child: SizedBox(
                          key: const ValueKey('image_clip_editor_save_action'),
                          width: saveWidth,
                          height: theme.saveButtonHeight,
                          child: Semantics(
                            button: true,
                            enabled: canSave,
                            label: labels.saveButton,
                            child: ExcludeSemantics(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: canSave ? onSave : null,
                                child: DecoratedBox(
                                  decoration: ShapeDecoration(
                                    color: canSave
                                        ? theme.accentColor
                                        : theme.tileColor,
                                    shape: const StadiumBorder(),
                                  ),
                                  child: Center(
                                    child: Text(
                                      labels.saveButton,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: canSave
                                            ? theme.onAccentColor
                                            : theme.disabledTextColor,
                                        fontSize: 16,
                                        height: 1.4,
                                        letterSpacing: 0,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
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
}

enum _CropToolIcon { fit, fill, rotate, revert }

class _CropToolButton extends StatelessWidget {
  const _CropToolButton({
    required this.icon,
    required this.label,
    required this.theme,
    required this.enabled,
    required this.onPressed,
  });

  final Object icon;
  final String label;
  final ImageClipEditorTheme theme;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? theme.controlTextColor : theme.disabledTextColor;

    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      enabled: enabled,
      label: label,
      child: InkResponse(
        onTap: enabled ? onPressed : null,
        radius: 32,
        child: SizedBox(
          width: 64,
          height: 48,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: 22,
                child: switch (icon) {
                  _CropToolIcon.fit => CustomPaint(
                    painter: _FitGlyphPainter(color: color),
                  ),
                  _CropToolIcon.fill => CustomPaint(
                    painter: _FillGlyphPainter(color: color),
                  ),
                  _CropToolIcon.rotate => CustomPaint(
                    painter: _RotateGlyphPainter(color: color),
                  ),
                  _CropToolIcon.revert => Icon(
                    Icons.restore_rounded,
                    color: color,
                    size: 22,
                  ),
                  _ => Icon(icon as IconData, color: color, size: 22),
                },
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 20,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      height: 20 / 14,
                      letterSpacing: 0,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FitGlyphPainter extends CustomPainter {
  const _FitGlyphPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 22;
    final sy = size.height / 22;
    canvas.save();
    canvas.scale(sx, sy);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.83333
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(3.5, 3.5)
      ..lineTo(8.25, 8.25)
      ..moveTo(3.5, 8.25)
      ..lineTo(8.25, 8.25)
      ..lineTo(8.25, 3.5)
      ..moveTo(18.5, 3.5)
      ..lineTo(13.75, 8.25)
      ..moveTo(18.5, 8.25)
      ..lineTo(13.75, 8.25)
      ..lineTo(13.75, 3.5)
      ..moveTo(3.5, 18.5)
      ..lineTo(8.25, 13.75)
      ..moveTo(3.5, 13.75)
      ..lineTo(8.25, 13.75)
      ..lineTo(8.25, 18.5)
      ..moveTo(18.5, 18.5)
      ..lineTo(13.75, 13.75)
      ..moveTo(18.5, 13.75)
      ..lineTo(13.75, 13.75)
      ..lineTo(13.75, 18.5);
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FitGlyphPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _FillGlyphPainter extends CustomPainter {
  const _FillGlyphPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 22;
    final sy = size.height / 22;
    canvas.save();
    canvas.scale(sx, sy);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.83333
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(13.75, 13.75)
      ..lineTo(18.5, 18.5)
      ..moveTo(13.75, 8.25)
      ..lineTo(18.5, 3.5)
      ..moveTo(19.25, 14.85)
      ..lineTo(19.25, 19.25)
      ..lineTo(14.85, 19.25)
      ..moveTo(19.25, 7.15)
      ..lineTo(19.25, 2.75)
      ..lineTo(14.85, 2.75)
      ..moveTo(2.75, 14.85)
      ..lineTo(2.75, 19.25)
      ..lineTo(7.15, 19.25)
      ..moveTo(3.5, 18.5)
      ..lineTo(8.25, 13.75)
      ..moveTo(2.75, 7.15)
      ..lineTo(2.75, 2.75)
      ..lineTo(7.15, 2.75)
      ..moveTo(8.25, 8.25)
      ..lineTo(3.5, 3.5);
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FillGlyphPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _RotateGlyphPainter extends CustomPainter {
  const _RotateGlyphPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 22;
    final sy = size.height / 22;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.83333
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    canvas.save();
    canvas.scale(sx, sy);
    canvas.translate(2.75, 2.75);
    canvas.scale(16.25 / 18.0833, 16.5 / 18.3333);
    final arc = Path()
      ..moveTo(17.1667, 9.66667)
      ..cubicTo(17.1667, 11.2984, 16.9328, 12.3934, 16.0263, 13.7501)
      ..cubicTo(15.1198, 15.1068, 13.8313, 16.1643, 12.3238, 16.7887)
      ..cubicTo(10.8163, 17.4131, 9.15752, 17.5765, 7.55718, 17.2581)
      ..cubicTo(5.95683, 16.9398, 4.48682, 16.1541, 3.33304, 15.0003)
      ..cubicTo(2.17926, 13.8465, 1.39352, 12.3765, 1.07519, 10.7762)
      ..cubicTo(0.756864, 9.17582, 0.920242, 7.51702, 1.54466, 6.00953)
      ..cubicTo(2.16909, 4.50204, 3.22651, 3.21356, 4.58322, 2.30704)
      ..cubicTo(5.93992, 1.40052, 7.53498, 0.916667, 9.16667, 0.916667)
      ..cubicTo(11.4767, 0.916667, 13.6858, 1.83333, 15.345, 3.42833)
      ..lineTo(16.6667, 4.66667);
    canvas.drawPath(arc, paint);
    canvas.restore();

    canvas.save();
    canvas.scale(sx, sy);
    canvas.translate(14.6667, 2.75);
    canvas.scale(4.5833 / 6.41667, 4.5833 / 6.41667);
    final arrow = Path()
      ..moveTo(5.5, 0.916667)
      ..lineTo(5.5, 5.5)
      ..lineTo(0.916667, 5.5);
    canvas.drawPath(arrow, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RotateGlyphPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _AspectRatioChoice extends StatelessWidget {
  const _AspectRatioChoice({
    required this.aspectRatio,
    required this.selected,
    required this.theme,
    required this.enabled,
    required this.onSelected,
  });

  final ImageClipAspectRatio aspectRatio;
  final bool selected;
  final ImageClipEditorTheme theme;
  final bool enabled;
  final ValueChanged<ImageClipAspectRatio> onSelected;

  @override
  Widget build(BuildContext context) {
    final textColor = enabled
        ? theme.controlTextColor
        : theme.disabledTextColor;

    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      enabled: enabled,
      selected: selected,
      label: aspectRatio.label,
      child: InkResponse(
        onTap: enabled ? () => onSelected(aspectRatio) : null,
        radius: 48,
        child: SizedBox(
          width: 64,
          height: 57,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AspectRatioGlyph(
                aspectRatio: aspectRatio,
                selected: selected,
                enabled: enabled,
                theme: theme,
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 16.5,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    aspectRatio.label,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 11,
                      height: 16.5 / 11,
                      letterSpacing: 0.0645,
                      fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AspectRatioGlyph extends StatelessWidget {
  const _AspectRatioGlyph({
    required this.aspectRatio,
    required this.selected,
    required this.enabled,
    required this.theme,
  });

  final ImageClipAspectRatio aspectRatio;
  final bool selected;
  final bool enabled;
  final ImageClipEditorTheme theme;

  @override
  Widget build(BuildContext context) {
    const maxWidth = 28.0;
    const maxHeight = 28.0;
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
      height: 32,
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: !enabled
                ? _imageClipColorWithOpacity(theme.tileColor, 0.5)
                : selected
                ? theme.accentSurfaceColor
                : theme.tileColor,
            border: Border.all(
              color: selected && enabled
                  ? theme.accentColor
                  : Colors.transparent,
              width: theme.aspectRatioBorderWidth,
            ),
            borderRadius: BorderRadius.circular(
              theme.aspectRatioGlyphBorderRadius,
            ),
          ),
          child: SizedBox(width: size.width, height: size.height),
        ),
      ),
    );
  }
}
