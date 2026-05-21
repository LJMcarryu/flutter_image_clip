import 'dart:typed_data';

import 'crop_transform.dart';
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

/// Result returned by a platform file-processing adapter.
class ImageClipFileProcessingAdapterResult {
  /// Creates a normalized file-processing result.
  const ImageClipFileProcessingAdapterResult({
    required this.bytes,
    required this.width,
    required this.height,
    required this.format,
    this.sourceWidth,
    this.sourceHeight,
  }) : assert((sourceWidth == null) == (sourceHeight == null));

  /// Encoded result bytes.
  final Uint8List bytes;

  /// Result width in pixels.
  final int width;

  /// Result height in pixels.
  final int height;

  /// Encoded output format for [bytes].
  final ImageClipOutputFormat format;

  /// Original decoded source width before crop, if known.
  final int? sourceWidth;

  /// Original decoded source height before crop, if known.
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

  /// Whether this adapter should normalize [info] for [settings].
  ///
  /// Existing adapters can continue overriding [supports]. Implementations that
  /// need decode settings, such as sampled preview decoders, can override this
  /// method instead.
  bool supportsDecode(
    ImageClipImageInfo info,
    ImageClipDecodeSettings settings,
  ) {
    return supports(info);
  }

  /// Returns normalized bytes for [bytes], or null to use the Dart fallback.
  Future<ImageClipDecodeAdapterResult?> decode(
    Uint8List bytes, {
    required ImageClipImageInfo info,
    required String label,
    required ImageClipDecodeSettings settings,
  });

  /// Returns normalized bytes for a local image file [path], or null to use
  /// the Dart fallback.
  ///
  /// The default implementation returns null. Platform adapters can override
  /// this to avoid reading large gallery files into the UI isolate before
  /// sampled decode or format normalization.
  Future<ImageClipDecodeAdapterResult?> decodeFile(
    String path, {
    required ImageClipImageInfo info,
    required String label,
    required ImageClipDecodeSettings settings,
  }) async {
    return null;
  }
}

/// Optional adapter capability for processing local image files natively.
///
/// Implementations may return null when a file, format, or operation should
/// fall back to the Dart isolate pipeline.
abstract interface class ImageClipFileProcessingAdapter {
  /// Crops [path] using original source-image pixel [region], then applies
  /// [transform] and encodes with [outputSettings].
  Future<ImageClipFileProcessingAdapterResult?> cropFile(
    String path, {
    required CropRegion region,
    required ImageClipCropTransform transform,
    required ImageClipOutputSettings outputSettings,
    required ImageClipProcessingSettings processingSettings,
    required String label,
  });
}
