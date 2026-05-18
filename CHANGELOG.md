# 0.3.0

- Added `ImageClipEditorTheme` for configurable editor and result page colors, borders, crop overlays, and framed surface radius.
- Added EXIF orientation baking during image decoding so rotated camera photos crop with the expected dimensions.
- Added `ImageClipProcessingSettings` for input pixel limits, output pixel limits, and automatic downscaling.
- Added typed exceptions for decode failures, processing failures, invalid crop regions, and oversized images.
- Improved configurable crop ratio presets so custom ratio frames inherit editor theme tokens.
- Added GitHub Actions CI for formatting, analysis, tests, API docs, and pub dry-run validation.

# 0.2.0

- Added `ImageClipEditorLabels` for configurable editor, status, and result page copy.
- Added `ImageClipAspectRatio` so the editor can show custom named crop ratio presets such as square or widescreen crops.
- Added `ImageClipOutputSettings` and `ImageClipOutputFormat` for configurable PNG or JPEG crop output.
- Added `ImageProcessor.exportImage` and `ImageProcessor.exportJpeg`.
- Changed built-in editor and processor messages to English defaults.

# 0.1.1

- Updated the changelog to use English content for pub.dev language checks.
- Added dartdoc comments for the public libraries, image processing APIs, and crop editor APIs.

# 0.1.0

- Initial release of `flutter_image_clip`.
- Added `showImageClipEditor`, a ready-to-use crop editor route API.
- Added `ImageClipEditor`, an embeddable Flutter crop editor widget.
- Added `ImageProcessor` image processing APIs for decoding, cropping, rotating, flipping, resizing, color adjustment, and PNG export.
- Added `ImageClipResult` with source image data, cropped image data, crop region metadata, and rotation metadata.
