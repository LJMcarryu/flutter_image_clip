# 0.11.1

- 放宽默认编辑器 golden 测试对高斯模糊跨平台像素差异的容差，修复 Linux CI 下的发布检查失败。

# 0.11.0

- 将图片编辑区域默认遮罩改为 `#FFFFFF` / `0.6` alpha，并为裁剪框外遮罩加入可配置的高斯模糊。

# 0.10.4

- 移除图片任务运行时的顶部进度条，加载图片时仅保留预览区中央的圆形 loading。

# 0.10.3

- 将图片预览加载态从文本改为圆形 loading，并复用 `ImageClipEditorTheme.progressColor` 支持业务自定义颜色。
- 按 Figma 设计稿调整顶部栏布局：左侧返回箭头与标题作为取消入口，移除右侧关闭图标，并更新标题字号与间距。

# 0.10.2

- 修正 Position 工具栏 Revert 图标的尺寸和位置，使其与 Figma 设计稿的 22px 图标边界一致。

# 0.10.1

- 按 Figma 设计稿替换 Position 工具栏里的 Rotate 和 Revert 图标，保持原有尺寸、颜色状态和交互逻辑不变。

# 0.10.0

- 新增编辑器保存脏状态控制：内置 Save 按钮会在用户调整 Position 后才可点击。
- 新增 `ImageClipEditor.onCancelAttempt` / `showImageClipEditor(onCancelAttempt:)`，业务侧可在返回时根据是否存在未保存修改决定是否弹出 Discard 确认框。
- 新增 `ImageClipEditor.hasCustomPosition`、Revert 工具按钮和 `ImageClipResult.revertedToOriginal`，支持业务在 Save 成功后清空已保存的 Position。
- 新增 `ImageClipEditor.onSaveResult` / `showImageClipEditor(onSaveResult:)`，业务侧可在接口保存成功后再允许编辑器关闭，接口失败时保留编辑页供用户重试。

# 0.9.5

- 将 pub.dev README 调整为纯英文正文，并把语言切换链接改为 GitHub 上的英文与简体中文 README，避免 pub.dev 内部锚点跳转异常。
- 新增 `README.zh-CN.md` 承载简体中文说明。
- 在 pubspec topics 中新增 `position`，提高按图片定位裁剪场景搜索时的可发现性。

# 0.9.4

- 修复显式传入不受支持的裁剪比例时，编辑器会把该比例作为临时新比例插入工具栏的问题；现在会严格从 `aspectRatios` 中选择最接近的预设。
- 保存裁剪结果时继续按选中预设的整数比例锁定输出宽高，避免预览缩放或错误传入比例导致导出尺寸偏离所选比例。

# 0.9.3

- 修复显式传入等价裁剪比例时，编辑器会把 `480:640` 等比例作为临时新比例插入工具栏的问题；现在会优先复用 `aspectRatios` 中数值等价的预设。
- `ImageClipAspectRatio.fromDimensions` 和 `fromCropRegion` 生成自定义比例时会保存约分后的 `width` / `height`，确保比例元数据和展示 label 保持一致。

# 0.9.2

- 调整裁剪元数据恢复策略：`ImageClipResult.region` 现在会保存裁剪框映射到原图坐标后的虚拟矩形，允许 `x` / `y` 为负数或 `width` / `height` 超出图片边界，用同一组 `rotationDegrees + x/y/w/h` 即可恢复 Fit 模式下的左右或上下留白。
- 保存导出时会在内部把虚拟矩形夹到有效源图像素区域，不要求接入方额外传 `visibleRegion` 或 `aspectRatio`。

# 0.9.1

- 修复 Fit 模式下图片左右或上下留白时，保存后再传入初始裁剪信息会恢复成无留白位置的问题。
- 新增 `ImageClipResult.visibleRegion` 和 `ImageClipResult.aspectRatio`，用于持久化并恢复编辑器里的可见区域与裁剪比例。
- `ImageClipEditor.initialAspectRatio` 现在会优先于 `initialCropRegion` 的自动比例推导，方便业务按保存时的比例恢复 Position。
- README 改为英文优先的中英文文档，并缩小示例图为一行两张。

# 0.9.0

- 新增 `ImageClipEditor.initialImagePath`、`showImageClipEditor(imagePath:)` 和 `ImageClipEditorController.loadImageFile()`，相册本地文件可走 file-backed preview/save 链路，减少 UI isolate 原图 bytes 占用。
- `ImageClipPlatformDecodeAdapter` 支持从本地文件路径触发 Android/iOS 平台采样解码，示例首页选择相册后优先保留文件路径，只有路径不可用时才退回 `readAsBytes()`。
- `ImageProcessor.probeFile` 改为只读取文件头做格式探测，避免为了元数据把大图完整读入 UI isolate。
- 平台采样预览会在无透明通道时返回 JPEG、有透明通道时返回 PNG，减少照片预览的通道传输字节数。
- `showImageClipEditor` 默认启用 `ImageClipPlatformDecodeAdapter`，fullscreen 入口保持少参数也能使用平台 HEIC/HEIF 和 sampled decode 能力。
- 新增可选的 `ImageClipFileProcessingAdapter` 能力，内置平台适配器可对支持的本地文件 JPEG 裁剪保存走原生 `cropFile`，不支持或 PNG 输出时自动回退 Dart isolate。
- 示例首页新增 Pick/probe、Preview task、Save task 耗时指标，方便直接观察相册选择、预览和保存阶段的性能。
- 修正预览图缩小后映射回原图的保存区域，避免 10:16 等比例因独立 round 宽高而产生像素比例误差。
- 按 Figma 设计稿更新编辑器 Fit、Fill 和 Rotate 工具图标。

# 0.8.1

- 初始裁剪区域恢复时不再插入临时比例，会在支持的 `aspectRatios` 中选择精确或最接近的比例。

# 0.8.0

- 支持通过初始旋转角度和原图裁剪坐标恢复编辑器 Position。
- 传入初始裁剪坐标时，编辑器会根据宽高自动选中或插入对应比例。
- 新增 `ImageClipAspectRatio.fromDimensions` 与 `ImageClipAspectRatio.fromCropRegion`，方便业务侧复用比例推导规则。
- 新增 `CropRegion.hasPositiveSize` 与 `CropRegion.clampToBounds`，统一裁剪坐标边界处理。
- 新增 `ImageClipResult.sourceRegion` 和 `ImageClipResult.transform`，明确保存结果里的坐标系和变换元数据。
- `ImageClipTaskProgress` 增加完成状态 helper、相等比较和稳定的 `fraction` 夹取逻辑。
- 补齐 `CropSettings` 与 `ColorAdjustment` 的 map、copy 和相等比较 helper。
- 编辑器会忽略非正宽高的 `initialCropRegion`，越界坐标会在图片加载后夹到原图范围内。
- 输出、解码和处理设置从 map 读取时会清理非正数或越界值。
- 示例首页新增完整参数面板，fullscreen 入口保留最少参数。

# 0.7.4

- 改用 pub.dev README 会稳定渲染的 Markdown 图片语法展示两张截图。
- 进一步压缩发布截图到 `360x800`，减小页面展示尺寸和下载体积。

# 0.7.3

- 将发布截图替换为更小的 WebP 资源，降低 README 和 pub.dev 图片加载体积。
- README 预览区同时展示全屏编辑器和嵌入式示例两张截图。

# 0.7.2

- Move the iOS plugin source into the Swift Package Manager layout while keeping CocoaPods support.
- Run Android and iOS native decode work on background queues before returning MethodChannel results.
- Add the missing `ImageClipEditorController` constructor dartdoc.
- Document real-device release validation and repository security hardening tasks.
- Add pub.dev screenshots for the fullscreen editor and embedded example lab.

# 0.7.1

- Fixed release-check golden flakiness on remote Linux / Flutter stable by allowing a 1% pixel tolerance while keeping layout and semantics tests as stronger guards.
- Added a gated `Publish to pub.dev` job to the release workflow. Tagged packages publish through pub.dev GitHub Actions OIDC only after validation passes and `PUB_DEV_AUTOMATED_PUBLISHING` is enabled.
- Added process RSS delta tracking to the benchmark baseline to catch large-image memory regressions.
- Added a public API dartdoc check so new public APIs cannot be added without documentation.
- Added Dependabot, Dependency Review, issue forms, a pull request template, and `SECURITY.md`.
- Added release, troubleshooting, migration, and real-device validation guides.

# 0.7.0

- Moved Android integration tests into `example/integration_test` so generated root app scaffolding no longer interferes with plugin compilation.
- Moved the integration test dependency into the example app and removed it from the root package.
- Removed the bundled Inter font from the editor. The editor now inherits the host app font, reducing package size and style intrusion.
- Updated compatibility constraints to Dart `>=3.10.0 <4.0.0` and Flutter `>=3.38.1`.
- Added CI coverage for both the minimum supported Flutter version and the latest stable Flutter version.
- Added iOS simulator integration tests. Android and iOS integration tests both cover the editor flow and native sampled decode.
- Mapped `ImageClipPlatformDecodeAdapter` platform errors to `ImageClipUnsupportedFormatException`, `ImageClipPlatformException`, or `ImageClipDecodeException`.
- Preserved original source dimensions in Android native sampled decode so preview crop coordinates map back to the source image reliably.
- Added layout tokens to `ImageClipEditorTheme` for the top bar, bottom bar, save button, and aspect-ratio controls.
- Added the iOS `PrivacyInfo.xcprivacy` manifest.
- Tightened `.pubignore` so test, benchmark, tool, and generated integration scaffolding files are not published.
- Added integration recipes, a platform matrix, and an accessibility checklist.
- Reworked the public API snapshot to use analyzer-based exported API discovery.
- Added command-level and test-level timeouts to Android integration tests with clearer timeout failures.
- Expanded README compatibility and public import guidance.

# 0.6.6

- Converted the package into an Android/iOS Flutter plugin with the built-in `ImageClipPlatformDecodeAdapter`.
- Added platform-side sampled decode and format normalization entry points for HEIC/HEIF and other system-supported image formats.
- Added `ImageProcessor.probeFile`, `decodeFile`, `processFile`, and `writeImageToFile`. File input is read inside the worker isolate to reduce UI-isolate byte copying.
- Added Android emulator integration tests for loading, preview thumbnails, rotation, flipping, saving, and Chinese labels.
- Added JPEG preview decode and file-path crop/export cases to the benchmark suite.
- Added `tool/check_api_snapshot.dart` and `tool/api_snapshot.json` to guard key public APIs in CI.
- Split the editor save flow into `editor_save.dart` to reduce the maintenance load in `editor.dart`.
- Added `ImageClipEditorLabels.english` and `ImageClipEditorLabels.zhHans`.
- Added tag-triggered release checks that run format, analysis, tests, benchmarks, API docs, and pub dry-run before publishing.

# 0.6.5

- Added `ImageClipDecodeSettings` for preview decode target long-side configuration.
- Added `sourceWidth` and `sourceHeight` metadata to `EditedImage`.
- Added `ImageProcessor.decodePreviewBytes` and `decodePreviewBytesTask`.
- Added `ImageClipDecodeAdapter` so callers can normalize platform-only formats or run platform sampled decode before Dart decoding.
- Added `ImageClipEditor.previewDecodeSettings`. The editor can use a smaller preview image while saving still maps the crop region back to original source bytes.
- Added map, copy, and equality helpers to `ImageClipResult`, `CropRegion`, and core settings models.
- Added benchmark regression checking through `--check benchmark/baseline.json`.
- Added Android debug APK and iOS no-codesign debug builds to CI.
- Added tests for preview-to-source export, large text landscape layout, decode adapters, and model stability.

# 0.6.4

- Changed editor rotate and flip actions to update preview state immediately. The final save maps the preview crop area back to source pixels and exports once.
- Added `ImageClipCropTransform` and `ImageClipDimensions` for reusable rotation/flip crop coordinate mapping.
- Added `previewRegion`, `flippedHorizontally`, and `flippedVertically` metadata to `ImageClipResult`.
- Added `outputSettings` support to `ImageProcessor.rotate`, `rotateRight`, `flipHorizontal`, `flipVertical`, and their task APIs.
- Added async `flipHorizontal` and `flipVertical` APIs to `ImageClipSession`, and added `outputSettings` support to `rotate`.

# 0.6.3

- Added HEIC/HEIF header detection and typed `ImageClipUnsupportedFormatException` failures before pure Dart decoding.
- Added `ImageClipDecodedSession` for keeping decoded pixels in memory across multiple small-image operations.
- Added Semantics for the editor preview, crop frame, tool buttons, and aspect-ratio controls.
- Added a default editor golden test for visual regression coverage.

# 0.6.2

- Added `ImageClipSession` for holding current image state across continuous editing flows.
- Added session-level task cancellation.
- Organized the example as a standalone Flutter app with its own `example/pubspec.yaml`.
- Added mobile image fixture tests for EXIF orientation values 1-8, transparent PNG, and corrupt JPEG input.

# 0.6.1

- Added `ImageProcessor.probeBytes` and `ImageClipImageInfo` for detecting PNG, JPEG, GIF, and WebP format and dimensions before full decoding.
- Added header-based input pixel limit checks before decode to reduce memory pressure from oversized images.
- Switched large isolate byte messages to `TransferableTypedData`.
- Added timeout support to `ImageClipTask.fromFuture`.
- Added `ImageClipEditor.onProgress` and wired editor progress UI to background task progress.
- Updated the example with gallery selection, sample loading, task cancellation, input probe details, and export preview.
- Added `--json` output to the benchmark command.

# 0.6.0

- Limited published platform support to Android and iOS.
- Updated README and pubspec descriptions to remove desktop and web support implications.
- Split editor UI code into controller, editor, preview panel, toolbar, result page, theme, labels, and painter files.
- Added `ImageClipTask`, `ImageClipTaskOptions`, and `ImageClipTaskProgress` for cancellation, progress, and timeouts.
- Added `ImageClipEditorController.cancelTask()`.
- Added `benchmark/image_processor_benchmark.dart` covering decode, rotate/crop/JPEG export, and large-image downscale cases.
- Added tests for task progress and cancellation.

# 0.5.0

- Added `ImageClipPipeline` and `ImageClipPipelineStep` for batching decode, rotate, crop, flip, resize, color adjustment, and export into one background task.
- Added `ImageProcessor.processPipeline` and `processBytes` to reduce repeated decode/encode work.
- Refactored image processing into dedicated exception, model, pipeline, isolate job, pixel operation, and sample image modules.
- Kept existing single-step APIs such as `cropRegion`, `rotate`, `adjustColor`, and `exportJpeg`.
- Added pipeline tests for raw byte input and existing `EditedImage` input.

# 0.4.0

- Added `ImageClipEditorController` for loading images, clearing images, resetting the crop viewport, rotating images, reading the crop region, and triggering crop operations from parent widgets.
- Improved editor async lifecycle handling so newer image load requests invalidate older task results.
- Added stale-result protection to crop saving when the current image is replaced while a save is still running.
- Added widget tests for controller-driven flows and out-of-order async image loading.
- Updated README controller integration examples.

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
