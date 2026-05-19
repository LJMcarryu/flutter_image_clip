# 0.6.3

- 新增 HEIC/HEIF header 识别，并在纯 Dart 解码前抛出 `ImageClipUnsupportedFormatException`，提示业务先做平台转码。
- 新增 `ImageClipDecodedSession`，支持在内存中保留已解码像素，连续处理时避免中间步骤反复 decode/encode。
- 为编辑器预览、裁剪框、工具按钮和比例选项补充 Semantics，提升 TalkBack/VoiceOver 可访问性。
- 新增默认编辑器 golden 测试，覆盖核心裁剪 UI 的视觉回归。

# 0.6.2

- 新增 `ImageClipSession`，用于在连续编辑流程中持有当前图片状态，并支持 session 级任务取消。
- 将 example 整理为独立 Flutter app，示例依赖迁移到 `example/pubspec.yaml`，避免污染库本身依赖面。
- 补充移动端图片 fixture 测试，覆盖 EXIF orientation 1-8、透明 PNG 和损坏 JPEG。

# 0.6.1

- 新增 `ImageProcessor.probeBytes` 和 `ImageClipImageInfo`，可在完整解码前识别 PNG、JPEG、GIF、WebP 的格式与尺寸。
- 解码前会优先通过图片 header 执行输入像素上限检查，减少异常超大图片带来的内存压力。
- 后台 isolate 的图片字节请求和结果改用 `TransferableTypedData` 传输，降低大图处理时的跨 isolate 拷贝成本。
- `ImageClipTask.fromFuture` 现在同样支持 `ImageClipTaskOptions.timeout`。
- `ImageClipEditor` 新增 `onProgress` 回调，并将编辑器进度条接入后台任务进度。
- example 更新为移动端接入示例，支持相册选图、样例图、任务取消、输入探测信息和导出结果预览。
- benchmark 新增 `--json` 输出，便于后续接入性能回归比对。

# 0.6.0

- 将发布包平台声明收敛为仅支持 Android 和 iOS。
- 更新 README 和 pubspec 描述，移除面向桌面/Web 的平台暗示。
- 拆分编辑器 UI 层，将控制器、编辑器主体、预览面板、工具栏、结果页、主题、文案和裁剪遮罩 painter 拆到独立文件。
- 新增 `ImageClipTask`、`ImageClipTaskOptions` 和 `ImageClipTaskProgress`，支持任务取消、进度监听和超时取消。
- `ImageClipEditorController` 新增 `cancelTask()`，可取消当前编辑器后台处理任务。
- 新增 `benchmark/image_processor_benchmark.dart`，覆盖解码、旋转裁剪导出 JPEG 和大图 downscale 的耗时基准。
- 补充任务进度和取消测试。

# 0.5.0

- 新增 `ImageClipPipeline` 和 `ImageClipPipelineStep`，支持把解码、旋转、裁剪、翻转、缩放、调色和导出合并为一次后台任务。
- 新增 `ImageProcessor.processPipeline` 和 `ImageProcessor.processBytes`，减少多步处理时的重复 decode/encode 和 isolate 往返。
- 重构图像处理层文件结构，将异常、模型、pipeline 描述、isolate job、像素操作和示例图生成拆分到独立模块。
- 保留 `cropRegion`、`rotate`、`adjustColor`、`exportJpeg` 等既有单步 API，旧调用方式无需迁移。
- 补充 pipeline 多步处理测试，覆盖从原始字节和已有 `EditedImage` 两种入口运行。

# 0.4.0

- 新增 `ImageClipEditorController`，支持父组件主动加载图片、清空图片、重置裁剪视图、旋转图片、读取当前裁剪区域并触发裁剪。
- 优化编辑器异步任务生命周期：新的图片加载请求会使旧任务结果失效，避免快速切换图片时旧结果覆盖新状态。
- 裁剪保存任务也加入过期结果保护，避免图片被替换后继续回写旧裁剪结果。
- 补充控制器驱动流程和乱序异步加载的 Widget 测试。
- 更新 README 的控制器集成示例。

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
