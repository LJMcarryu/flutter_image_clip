part of '../image_clip_editor.dart';

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
