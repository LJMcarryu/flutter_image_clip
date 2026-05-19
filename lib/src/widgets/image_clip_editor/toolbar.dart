part of '../image_clip_editor.dart';

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
    required this.onFlipHorizontal,
    required this.onFlipVertical,
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
  final VoidCallback onFlipHorizontal;
  final VoidCallback onFlipVertical;
  final VoidCallback onRotate;
  final ValueChanged<ImageClipAspectRatio> onAspectRatioChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 500;
        final barHeight = compact ? 202.0 : 236.0;
        final toolGap = compact ? 14.0 : 28.0;
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
                          icon: Icons.flip,
                          label: labels.flipHorizontalButton,
                          theme: theme,
                          enabled: canRun,
                          compact: compact,
                          onPressed: onFlipHorizontal,
                        ),
                        SizedBox(width: toolGap),
                        _CropToolButton(
                          icon: Icons.flip_to_back_outlined,
                          label: labels.flipVerticalButton,
                          theme: theme,
                          enabled: canRun,
                          compact: compact,
                          onPressed: onFlipVertical,
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

    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      enabled: enabled,
      label: label,
      child: InkResponse(
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
