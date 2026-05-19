import 'dart:typed_data';

import 'models.dart';

/// Result returned by a platform decode adapter.
class ImageClipDecodeAdapterResult {
  /// Creates a normalized decode result.
  const ImageClipDecodeAdapterResult({
    required this.bytes,
    this.sourceWidth,
    this.sourceHeight,
  }) : assert((sourceWidth == null) == (sourceHeight == null));

  /// Encoded bytes that can be decoded by the Dart image pipeline.
  final Uint8List bytes;

  /// Original decoded source width before platform-side sampling, if known.
  final int? sourceWidth;

  /// Original decoded source height before platform-side sampling, if known.
  final int? sourceHeight;
}

/// Adapter used to normalize platform-only image formats before Dart processing.
///
/// Implementations can transcode HEIC/HEIF to PNG/JPEG or perform native
/// sampled decode for large JPEG/PNG inputs. Returning null tells
/// the processor to continue with its Dart fallback.
abstract class ImageClipDecodeAdapter {
  /// Creates a decode adapter.
  const ImageClipDecodeAdapter();

  /// Whether this adapter should be asked to normalize [info].
  bool supports(ImageClipImageInfo info) => !info.canDecodeWithDart;

  /// Returns normalized bytes for [bytes], or null to use the Dart fallback.
  Future<ImageClipDecodeAdapterResult?> decode(
    Uint8List bytes, {
    required ImageClipImageInfo info,
    required String label,
    required ImageClipDecodeSettings settings,
  });
}
