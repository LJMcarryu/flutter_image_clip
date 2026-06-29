part of '../image_clip_editor.dart';

/// Visual tokens used by [ImageClipEditor] and [ImageClipResultPage].
class ImageClipEditorTheme {
  /// Creates an editor theme.
  const ImageClipEditorTheme({
    this.backgroundColor = const Color(0xFFFFFFFF),
    this.previewBackgroundColor = const Color(0xFFF8F9FA),
    this.surfaceColor = const Color(0xFFFFFFFF),
    this.imageBackgroundColor = const Color(0xFFF8F9FA),
    this.tileColor = const Color(0xFFD6DBDC),
    this.borderColor = const Color(0xFFEFF2F3),
    this.strongBorderColor = const Color(0xFFD6DBDC),
    this.primaryTextColor = const Color(0xFF1E2939),
    this.controlTextColor = const Color(0xFF05120D),
    this.secondaryTextColor = const Color(0xFF6A7282),
    this.disabledTextColor = const Color(0xFF9CA3AF),
    this.inactiveTextColor = const Color(0xFF9CA3AF),
    this.closeIconColor = const Color(0x7333312F),
    this.accentColor = const Color(0xFF10B062),
    this.accentSurfaceColor = const Color(0xFFD6F1E1),
    this.onAccentColor = const Color(0xFFFFFFFF),
    this.progressColor = const Color(0xFF10B062),
    this.cropShadeColor = const Color(0x4D000000),
    this.cropShadeBlurSigma = 15,
    this.cropBorderColor = const Color(0xFFFFFFFF),
    this.cropGridColor = const Color(0x99FFFFFF),
    this.borderRadius = 8,
    this.cropBorderWidth = 1,
    this.aspectRatioBorderWidth = 1,
    this.topBarHeight = 56,
    this.bottomBarHeight = 300,
    this.compactBottomBarHeight = 180,
    this.bottomBarContentHeight = 300,
    this.bottomBarHorizontalPadding = 16,
    this.maxSaveButtonWidth = 343,
    this.saveButtonHeight = 48,
    this.saveButtonTop = 211,
    this.positionHintTop = 15,
    this.toolRowTop = 48,
    this.toolButtonGap = 48,
    this.aspectRatioRowTop = 112,
    this.aspectRatioGap = 24,
    this.aspectRatioGlyphBorderRadius = 2,
  }) : assert(cropShadeBlurSigma >= 0),
       assert(borderRadius >= 0),
       assert(cropBorderWidth >= 0),
       assert(aspectRatioBorderWidth >= 0),
       assert(topBarHeight > 0),
       assert(bottomBarHeight > 0),
       assert(compactBottomBarHeight > 0),
       assert(bottomBarContentHeight > 0),
       assert(bottomBarHorizontalPadding >= 0),
       assert(maxSaveButtonWidth > 0),
       assert(saveButtonHeight > 0),
       assert(saveButtonTop >= 0),
       assert(positionHintTop >= 0),
       assert(toolRowTop >= 0),
       assert(toolButtonGap >= 0),
       assert(aspectRatioRowTop >= 0),
       assert(aspectRatioGap >= 0),
       assert(aspectRatioGlyphBorderRadius >= 0);

  /// Creates the default dark editor theme.
  const ImageClipEditorTheme.dark()
    : this(
        backgroundColor: const Color(0xFF101113),
        previewBackgroundColor: const Color(0xFF101113),
        surfaceColor: const Color(0xFF18191C),
        imageBackgroundColor: const Color(0xFF17181B),
        tileColor: const Color(0xFF222326),
        borderColor: const Color(0xFF2A2B2E),
        strongBorderColor: const Color(0xFF333439),
        primaryTextColor: const Color(0xFFF7F7F7),
        controlTextColor: const Color(0xFFF7F7F7),
        secondaryTextColor: const Color(0xFF9D9EA3),
        disabledTextColor: const Color(0xFF5A5B5E),
        inactiveTextColor: const Color(0xFF6D6E72),
        closeIconColor: const Color(0xFF9D9EA3),
        accentColor: const Color(0xFF10B062),
        accentSurfaceColor: const Color(0xFF173927),
        onAccentColor: const Color(0xFFFFFFFF),
        progressColor: const Color(0xFF10B062),
        cropShadeColor: const Color(0x4D000000),
      );

  /// Creates a theme from a Flutter [ColorScheme].
  factory ImageClipEditorTheme.fromColorScheme(ColorScheme colorScheme) {
    final dark = colorScheme.brightness == Brightness.dark;
    return ImageClipEditorTheme(
      backgroundColor: colorScheme.surface,
      previewBackgroundColor: dark
          ? colorScheme.surface
          : const Color(0xFFF8F9FA),
      surfaceColor: dark
          ? colorScheme.surfaceContainerLow
          : const Color(0xFFFFFFFF),
      imageBackgroundColor: dark
          ? colorScheme.surfaceContainerLowest
          : const Color(0xFFF8F9FA),
      tileColor: colorScheme.surfaceContainerHigh,
      borderColor: colorScheme.outlineVariant,
      strongBorderColor: colorScheme.outline,
      primaryTextColor: colorScheme.onSurface,
      controlTextColor: colorScheme.onSurface,
      secondaryTextColor: colorScheme.onSurfaceVariant,
      disabledTextColor: _imageClipColorWithOpacity(
        colorScheme.onSurface,
        0.38,
      ),
      inactiveTextColor: _imageClipColorWithOpacity(
        colorScheme.onSurfaceVariant,
        0.72,
      ),
      closeIconColor: _imageClipColorWithOpacity(
        colorScheme.onSurfaceVariant,
        0.72,
      ),
      accentColor: colorScheme.primary,
      accentSurfaceColor: colorScheme.primaryContainer,
      onAccentColor: colorScheme.onPrimary,
      progressColor: colorScheme.primary,
      cropShadeColor: const Color(0x4D000000),
      cropBorderColor: dark ? colorScheme.primary : const Color(0xFFFFFFFF),
      cropGridColor: dark
          ? _imageClipColorWithOpacity(colorScheme.primary, 0.62)
          : const Color(0x99FFFFFF),
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

  /// Enabled toolbar and ratio-label text color.
  final Color controlTextColor;

  /// Secondary label text color.
  final Color secondaryTextColor;

  /// Disabled control color.
  final Color disabledTextColor;

  /// Unselected control color.
  final Color inactiveTextColor;

  /// Close icon color used in the editor top bar.
  final Color closeIconColor;

  /// Primary action and selected-control color.
  final Color accentColor;

  /// Subtle fill used behind selected controls.
  final Color accentSurfaceColor;

  /// Text color shown on [accentColor].
  final Color onAccentColor;

  /// Loading indicator color.
  final Color progressColor;

  /// Overlay color outside the crop frame.
  final Color cropShadeColor;

  /// Gaussian blur sigma applied behind the overlay outside the crop frame.
  final double cropShadeBlurSigma;

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

  /// Height of the editor top bar.
  final double topBarHeight;

  /// Preferred height of the bottom toolbar on normal-height screens.
  final double bottomBarHeight;

  /// Minimum compact bottom toolbar height on short screens.
  final double compactBottomBarHeight;

  /// Intrinsic scrollable content height inside the bottom toolbar.
  final double bottomBarContentHeight;

  /// Horizontal padding used by the bottom save action.
  final double bottomBarHorizontalPadding;

  /// Maximum width of the bottom save action.
  final double maxSaveButtonWidth;

  /// Height of the bottom save action.
  final double saveButtonHeight;

  /// Top offset of the save action inside the toolbar content.
  final double saveButtonTop;

  /// Top offset of the toolbar position hint.
  final double positionHintTop;

  /// Top offset of the Fit/Fill and Rotate tool row.
  final double toolRowTop;

  /// Horizontal gap between tool buttons.
  final double toolButtonGap;

  /// Top offset of the aspect ratio selector row.
  final double aspectRatioRowTop;

  /// Horizontal gap between aspect ratio choices.
  final double aspectRatioGap;

  /// Corner radius for aspect ratio preview glyphs.
  final double aspectRatioGlyphBorderRadius;

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
    Color? controlTextColor,
    Color? secondaryTextColor,
    Color? disabledTextColor,
    Color? inactiveTextColor,
    Color? closeIconColor,
    Color? accentColor,
    Color? accentSurfaceColor,
    Color? onAccentColor,
    Color? progressColor,
    Color? cropShadeColor,
    double? cropShadeBlurSigma,
    Color? cropBorderColor,
    Color? cropGridColor,
    double? borderRadius,
    double? cropBorderWidth,
    double? aspectRatioBorderWidth,
    double? topBarHeight,
    double? bottomBarHeight,
    double? compactBottomBarHeight,
    double? bottomBarContentHeight,
    double? bottomBarHorizontalPadding,
    double? maxSaveButtonWidth,
    double? saveButtonHeight,
    double? saveButtonTop,
    double? positionHintTop,
    double? toolRowTop,
    double? toolButtonGap,
    double? aspectRatioRowTop,
    double? aspectRatioGap,
    double? aspectRatioGlyphBorderRadius,
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
      controlTextColor: controlTextColor ?? this.controlTextColor,
      secondaryTextColor: secondaryTextColor ?? this.secondaryTextColor,
      disabledTextColor: disabledTextColor ?? this.disabledTextColor,
      inactiveTextColor: inactiveTextColor ?? this.inactiveTextColor,
      closeIconColor: closeIconColor ?? this.closeIconColor,
      accentColor: accentColor ?? this.accentColor,
      accentSurfaceColor: accentSurfaceColor ?? this.accentSurfaceColor,
      onAccentColor: onAccentColor ?? this.onAccentColor,
      progressColor: progressColor ?? this.progressColor,
      cropShadeColor: cropShadeColor ?? this.cropShadeColor,
      cropShadeBlurSigma: cropShadeBlurSigma ?? this.cropShadeBlurSigma,
      cropBorderColor: cropBorderColor ?? this.cropBorderColor,
      cropGridColor: cropGridColor ?? this.cropGridColor,
      borderRadius: borderRadius ?? this.borderRadius,
      cropBorderWidth: cropBorderWidth ?? this.cropBorderWidth,
      aspectRatioBorderWidth:
          aspectRatioBorderWidth ?? this.aspectRatioBorderWidth,
      topBarHeight: topBarHeight ?? this.topBarHeight,
      bottomBarHeight: bottomBarHeight ?? this.bottomBarHeight,
      compactBottomBarHeight:
          compactBottomBarHeight ?? this.compactBottomBarHeight,
      bottomBarContentHeight:
          bottomBarContentHeight ?? this.bottomBarContentHeight,
      bottomBarHorizontalPadding:
          bottomBarHorizontalPadding ?? this.bottomBarHorizontalPadding,
      maxSaveButtonWidth: maxSaveButtonWidth ?? this.maxSaveButtonWidth,
      saveButtonHeight: saveButtonHeight ?? this.saveButtonHeight,
      saveButtonTop: saveButtonTop ?? this.saveButtonTop,
      positionHintTop: positionHintTop ?? this.positionHintTop,
      toolRowTop: toolRowTop ?? this.toolRowTop,
      toolButtonGap: toolButtonGap ?? this.toolButtonGap,
      aspectRatioRowTop: aspectRatioRowTop ?? this.aspectRatioRowTop,
      aspectRatioGap: aspectRatioGap ?? this.aspectRatioGap,
      aspectRatioGlyphBorderRadius:
          aspectRatioGlyphBorderRadius ?? this.aspectRatioGlyphBorderRadius,
    );
  }
}

Color _imageClipColorWithOpacity(Color color, double opacity) {
  final alpha = (opacity.clamp(0.0, 1.0) * 255).round();
  return color.withAlpha(alpha);
}
