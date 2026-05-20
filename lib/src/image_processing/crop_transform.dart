import 'models.dart';

/// Pixel dimensions used by crop transform helpers.
class ImageClipDimensions {
  /// Creates image dimensions in pixels.
  const ImageClipDimensions({required this.width, required this.height})
    : assert(width > 0),
      assert(height > 0);

  /// Width in pixels.
  final int width;

  /// Height in pixels.
  final int height;

  @override
  bool operator ==(Object other) {
    return other is ImageClipDimensions &&
        other.width == width &&
        other.height == height;
  }

  @override
  int get hashCode => Object.hash(width, height);
}

/// Quarter-turn and flip state used to map editor preview crops to source pixels.
class ImageClipCropTransform {
  /// Creates a preview transform.
  const ImageClipCropTransform({
    this.rotationDegrees = 0,
    this.flipHorizontal = false,
    this.flipVertical = false,
  });

  /// Clockwise rotation in degrees.
  ///
  /// Preview mapping supports quarter-turn rotations only.
  final int rotationDegrees;

  /// Whether the rotated preview is mirrored around its vertical axis.
  final bool flipHorizontal;

  /// Whether the rotated preview is mirrored around its horizontal axis.
  final bool flipVertical;

  /// Normalized clockwise rotation in the range 0..359.
  int get normalizedRotation {
    final normalized = rotationDegrees % 360;
    return normalized < 0 ? normalized + 360 : normalized;
  }

  /// Whether [degrees] can be represented as whole quarter turns.
  static bool isQuarterTurnRotation(int degrees) => degrees % 90 == 0;

  /// Whether [rotationDegrees] can be represented as whole quarter turns.
  bool get hasQuarterTurnRotation => isQuarterTurnRotation(normalizedRotation);

  /// Number of clockwise quarter turns represented by [rotationDegrees].
  int get quarterTurns {
    final rotation = normalizedRotation;
    if (rotation % 90 != 0) {
      throw ArgumentError.value(
        rotationDegrees,
        'rotationDegrees',
        'Only quarter-turn rotations are supported.',
      );
    }
    return rotation ~/ 90;
  }

  /// Whether the transform leaves pixels in their original orientation.
  bool get isIdentity {
    return normalizedRotation == 0 && !flipHorizontal && !flipVertical;
  }

  /// Returns the dimensions of the transformed preview.
  ImageClipDimensions visualSize({
    required int sourceWidth,
    required int sourceHeight,
  }) {
    final turns = quarterTurns;
    if (turns.isOdd) {
      return ImageClipDimensions(width: sourceHeight, height: sourceWidth);
    }
    return ImageClipDimensions(width: sourceWidth, height: sourceHeight);
  }

  /// Maps [previewRegion] in transformed preview coordinates back to source pixels.
  CropRegion sourceRegionForPreview({
    required int sourceWidth,
    required int sourceHeight,
    required CropRegion previewRegion,
  }) {
    final visual = visualSize(
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
    );
    final boundedPreviewRegion = previewRegion.clampToBounds(
      sourceWidth: visual.width,
      sourceHeight: visual.height,
    );
    var x = boundedPreviewRegion.x;
    var y = boundedPreviewRegion.y;
    var width = boundedPreviewRegion.width;
    var height = boundedPreviewRegion.height;

    if (flipHorizontal) {
      x = visual.width - x - width;
    }
    if (flipVertical) {
      y = visual.height - y - height;
    }

    return switch (normalizedRotation) {
      90 => _boundedCropRegion(
        x: y,
        y: sourceHeight - x - width,
        width: height,
        height: width,
        sourceWidth: sourceWidth,
        sourceHeight: sourceHeight,
        cornerRadius: boundedPreviewRegion.cornerRadius,
      ),
      180 => _boundedCropRegion(
        x: sourceWidth - x - width,
        y: sourceHeight - y - height,
        width: width,
        height: height,
        sourceWidth: sourceWidth,
        sourceHeight: sourceHeight,
        cornerRadius: boundedPreviewRegion.cornerRadius,
      ),
      270 => _boundedCropRegion(
        x: sourceWidth - y - height,
        y: x,
        width: height,
        height: width,
        sourceWidth: sourceWidth,
        sourceHeight: sourceHeight,
        cornerRadius: boundedPreviewRegion.cornerRadius,
      ),
      _ => _boundedCropRegion(
        x: x,
        y: y,
        width: width,
        height: height,
        sourceWidth: sourceWidth,
        sourceHeight: sourceHeight,
        cornerRadius: boundedPreviewRegion.cornerRadius,
      ),
    };
  }

  /// Maps [sourceRegion] in source-image coordinates into transformed preview
  /// coordinates.
  ///
  /// This is the inverse of [sourceRegionForPreview] and is useful when an
  /// editor needs to restore a crop position from previously saved metadata.
  CropRegion previewRegionForSource({
    required int sourceWidth,
    required int sourceHeight,
    required CropRegion sourceRegion,
  }) {
    final visual = visualSize(
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
    );
    final boundedSourceRegion = sourceRegion.clampToBounds(
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
    );
    var x = boundedSourceRegion.x;
    var y = boundedSourceRegion.y;
    var width = boundedSourceRegion.width;
    var height = boundedSourceRegion.height;

    switch (normalizedRotation) {
      case 90:
        final nextWidth = height;
        x = sourceHeight - boundedSourceRegion.y - boundedSourceRegion.height;
        y = boundedSourceRegion.x;
        width = nextWidth;
        height = boundedSourceRegion.width;
      case 180:
        x = sourceWidth - boundedSourceRegion.x - boundedSourceRegion.width;
        y = sourceHeight - boundedSourceRegion.y - boundedSourceRegion.height;
      case 270:
        final nextWidth = height;
        x = boundedSourceRegion.y;
        y = sourceWidth - boundedSourceRegion.x - boundedSourceRegion.width;
        width = nextWidth;
        height = boundedSourceRegion.width;
    }

    if (flipHorizontal) {
      x = visual.width - x - width;
    }
    if (flipVertical) {
      y = visual.height - y - height;
    }

    return _boundedCropRegion(
      x: x,
      y: y,
      width: width,
      height: height,
      sourceWidth: visual.width,
      sourceHeight: visual.height,
      cornerRadius: boundedSourceRegion.cornerRadius,
    );
  }

  /// Returns a copy with selected fields replaced.
  ImageClipCropTransform copyWith({
    int? rotationDegrees,
    bool? flipHorizontal,
    bool? flipVertical,
  }) {
    return ImageClipCropTransform(
      rotationDegrees: rotationDegrees ?? this.rotationDegrees,
      flipHorizontal: flipHorizontal ?? this.flipHorizontal,
      flipVertical: flipVertical ?? this.flipVertical,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ImageClipCropTransform &&
        other.rotationDegrees == rotationDegrees &&
        other.flipHorizontal == flipHorizontal &&
        other.flipVertical == flipVertical;
  }

  @override
  int get hashCode =>
      Object.hash(rotationDegrees, flipHorizontal, flipVertical);
}

CropRegion _boundedCropRegion({
  required int x,
  required int y,
  required int width,
  required int height,
  required int sourceWidth,
  required int sourceHeight,
  required double cornerRadius,
}) {
  return CropRegion(
    x: x,
    y: y,
    width: width,
    height: height,
    cornerRadius: cornerRadius,
  ).clampToBounds(sourceWidth: sourceWidth, sourceHeight: sourceHeight);
}
