/// Base exception type thrown by `flutter_image_clip`.
class ImageClipException implements Exception {
  /// Creates an image clip exception with a readable [message].
  const ImageClipException(this.message, {this.cause});

  /// Human-readable error message.
  final String message;

  /// Optional lower-level error that caused this exception.
  final Object? cause;

  @override
  String toString() {
    if (cause == null) {
      return '$runtimeType: $message';
    }
    return '$runtimeType: $message ($cause)';
  }
}

/// Thrown when encoded image bytes cannot be decoded.
class ImageClipDecodeException extends ImageClipException {
  /// Creates a decode exception.
  const ImageClipDecodeException(super.message, {super.cause});
}

/// Thrown when the input format is recognized but not supported.
class ImageClipUnsupportedFormatException extends ImageClipException {
  /// Creates an unsupported format exception.
  const ImageClipUnsupportedFormatException(
    super.message, {
    required this.format,
  });

  /// Unsupported encoded format that was detected.
  final String format;
}

/// Thrown when an image processing operation fails.
class ImageClipProcessingException extends ImageClipException {
  /// Creates a processing exception.
  const ImageClipProcessingException(super.message, {super.cause});
}

/// Thrown when a crop region is invalid.
class ImageClipInvalidCropRegionException extends ImageClipException {
  /// Creates an invalid crop region exception.
  const ImageClipInvalidCropRegionException(super.message);
}

/// Thrown when an image exceeds configured pixel limits.
class ImageClipImageTooLargeException extends ImageClipException {
  /// Creates an image size limit exception.
  const ImageClipImageTooLargeException(
    super.message, {
    required this.width,
    required this.height,
    required this.maxPixels,
  });

  /// Image width in pixels.
  final int width;

  /// Image height in pixels.
  final int height;

  /// Configured pixel limit that was exceeded.
  final int maxPixels;
}

/// Thrown when an image task is canceled before it finishes.
class ImageClipTaskCanceledException extends ImageClipException {
  /// Creates a task cancellation exception.
  const ImageClipTaskCanceledException([
    super.message = 'Image processing task was canceled',
  ]);
}

/// Thrown when an image task exceeds its configured timeout.
class ImageClipTaskTimeoutException extends ImageClipException {
  /// Creates a task timeout exception.
  const ImageClipTaskTimeoutException(super.message, {required this.timeout});

  /// Timeout duration that was exceeded.
  final Duration timeout;
}
