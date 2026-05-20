part of '../image_clip_editor.dart';

/// Result returned after a crop is saved.
class ImageClipResult {
  /// Creates a crop result with source, output, and crop metadata.
  const ImageClipResult({
    required this.source,
    required this.cropped,
    required this.region,
    required this.rotationDegrees,
    CropRegion? previewRegion,
    this.flippedHorizontally = false,
    this.flippedVertically = false,
  }) : previewRegion = previewRegion ?? region;

  /// Decoded image that was displayed in the editor.
  ///
  /// When preview decoding is enabled, this can be smaller than the original
  /// input. Use [region] or [sourceRegion] for persistent crop metadata.
  final EditedImage source;

  /// Cropped image produced by the editor.
  final EditedImage cropped;

  /// Crop rectangle in original source-image pixel coordinates.
  ///
  /// This is the value to persist and later pass back as
  /// [ImageClipEditor.initialCropRegion].
  final CropRegion region;

  /// Alias for [region] that makes the coordinate space explicit.
  CropRegion get sourceRegion => region;

  /// Crop rectangle in the decoded preview coordinate space.
  ///
  /// This is mainly useful for diagnostics or custom preview overlays. It is
  /// not stable across different preview decode sizes.
  final CropRegion previewRegion;

  /// Clockwise preview rotation applied to the saved crop, in degrees.
  final int rotationDegrees;

  /// Whether the saved crop was mirrored around its vertical axis.
  final bool flippedHorizontally;

  /// Whether the saved crop was mirrored around its horizontal axis.
  final bool flippedVertically;

  /// Transform metadata represented by this result.
  ImageClipCropTransform get transform {
    return ImageClipCropTransform(
      rotationDegrees: rotationDegrees,
      flipHorizontal: flippedHorizontally,
      flipVertical: flippedVertically,
    );
  }

  /// Converts the result metadata and images to isolate-safe maps.
  Map<String, Object?> toMap() => <String, Object?>{
    'source': source.toMap(),
    'cropped': cropped.toMap(),
    'region': region.toMap(),
    'previewRegion': previewRegion.toMap(),
    'rotationDegrees': rotationDegrees,
    'flippedHorizontally': flippedHorizontally,
    'flippedVertically': flippedVertically,
  };

  /// Creates a result from [toMap] output.
  static ImageClipResult fromMap(Map<String, Object?> map) {
    final region = CropRegion.fromMap(
      Map<Object?, Object?>.from(map['region']! as Map),
    );
    return ImageClipResult(
      source: EditedImage.fromMap(
        Map<String, Object?>.from(map['source']! as Map),
      ),
      cropped: EditedImage.fromMap(
        Map<String, Object?>.from(map['cropped']! as Map),
      ),
      region: region,
      previewRegion: map['previewRegion'] == null
          ? region
          : CropRegion.fromMap(
              Map<Object?, Object?>.from(map['previewRegion']! as Map),
            ),
      rotationDegrees: _intOf(map['rotationDegrees'], fallback: 0),
      flippedHorizontally: _boolOf(map['flippedHorizontally'], fallback: false),
      flippedVertically: _boolOf(map['flippedVertically'], fallback: false),
    );
  }
}

/// Displays the cropped image and crop metadata after saving.
class ImageClipResultPage extends StatelessWidget {
  /// Creates a result page for a saved crop [result].
  const ImageClipResultPage({
    super.key,
    required this.result,
    this.labels = const ImageClipEditorLabels(),
    this.theme = const ImageClipEditorTheme(),
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
                          label: labels.flipHorizontalButton,
                          value: result.flippedHorizontally ? 'yes' : 'no',
                          theme: theme,
                        ),
                        _MetricTile(
                          label: labels.flipVerticalButton,
                          value: result.flippedVertically ? 'yes' : 'no',
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
    final previewRegion = result.previewRegion;
    final data =
        'rotationDegrees: ${result.rotationDegrees}\n'
        'region.x: ${region.x}\n'
        'region.y: ${region.y}\n'
        'region.width: ${region.width}\n'
        'region.height: ${region.height}\n'
        'previewRegion.x: ${previewRegion.x}\n'
        'previewRegion.y: ${previewRegion.y}\n'
        'previewRegion.width: ${previewRegion.width}\n'
        'previewRegion.height: ${previewRegion.height}\n'
        'flippedHorizontally: ${result.flippedHorizontally}\n'
        'flippedVertically: ${result.flippedVertically}\n'
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

int _intOf(Object? value, {required int fallback}) {
  if (value is num) {
    return value.round();
  }
  return fallback;
}

bool _boolOf(Object? value, {required bool fallback}) {
  if (value is bool) {
    return value;
  }
  return fallback;
}
