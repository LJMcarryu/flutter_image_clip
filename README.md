# flutter_image_clip

`flutter_image_clip` is a Flutter image clipping and bitmap processing library for Android and iOS. It includes a ready-to-use fullscreen crop editor, an embeddable crop widget, and isolate-backed image processing APIs for file-backed and byte-backed workflows.

[English](#flutter_image_clip) | [简体中文](#简体中文)

<table>
  <tr>
    <td align="center" width="50%">
      <img src="screenshots/fullscreen-editor.webp" alt="Fullscreen crop editor" width="220">
      <br>
      <sub>Fullscreen editor</sub>
    </td>
    <td align="center" width="50%">
      <img src="screenshots/embedded-lab.webp" alt="Embedded image clip lab" width="220">
      <br>
      <sub>Embedded lab</sub>
    </td>
  </tr>
</table>

## Features

- `showImageClipEditor`: open the complete crop editor with one call.
- `ImageClipEditor`: embed the crop editor in your own page or form.
- `ImageClipEditorController`: load images, reset the view, rotate, flip, crop, and cancel work from parent widgets.
- Platform support: Android and iOS.
- Gestures: drag, pinch to zoom, and double-tap to reset.
- Crop modes: configurable aspect-ratio presets, Fit / Fill, and 90-degree rotation.
- Labels: override editor buttons, status text, and result-page copy with `ImageClipEditorLabels`. The default labels are English.
- Output: export PNG or JPEG, with configurable JPEG quality.
- Image operations: decode, center crop, region crop, rotate, flip, resize, adjust color, and export PNG/JPEG.
- Input probing: detect PNG, JPEG, GIF, WebP, HEIC, and HEIF before full decode.
- Preview decode: generate smaller previews with `ImageClipDecodeSettings.preview` while preserving original source dimensions.
- Native adapter: use the built-in `ImageClipPlatformDecodeAdapter`, or plug in a custom `ImageClipDecodeAdapter` for HEIC/HEIF conversion or platform sampled decode.
- File-backed pipeline: `decodeFile`, `processFile`, and `writeImageToFile` keep large local files out of the UI isolate.
- Batch pipeline: combine multiple image operations into one background task to avoid repeated decode/encode work.
- Sessions: `ImageClipSession` and `ImageClipDecodedSession` help keep editing state across multiple operations.
- Cancellable tasks: `ImageClipTask` exposes progress, cancellation, and timeout controls.
- Background processing: heavy work runs in a background isolate and uses `TransferableTypedData` for large byte transfers.

## Installation

After the package is published to pub.dev, add it to your app:

```yaml
dependencies:
  flutter_image_clip: ^0.9.2
```

Then run:

```sh
flutter pub get
```

For local development before publishing, use a path dependency:

```yaml
dependencies:
  flutter_image_clip:
    path: /Users/admin/Desktop/demos/flutter_image_clip_demo
```

## Documentation

- [Integration recipes](guides/接入配方.md): avatars, covers, `image_picker`, HEIC, file paths, large images, and error handling.
- [Platform and CI matrix](guides/平台矩阵.md): Android/iOS native decode support, device coverage, and release checks.
- [Accessibility checklist](guides/可访问性检查清单.md): VoiceOver, TalkBack, large text, keyboard, and contrast validation.
- [Troubleshooting](guides/故障排查.md): HEIC, large-image memory, EXIF, golden tests, iOS privacy, and pub.dev publishing.
- [Migration guide](guides/迁移指南.md): compatibility changes and upgrade notes by version.
- [Release process](guides/发布流程.md): tags, release checks, pub.dev OIDC publishing, and failure handling.
- [Real-device validation](guides/真实设备验收.md): Android/iOS sample images and pre-release validation.
- [Real-device validation records](guides/真实设备验收记录.md): versioned real-device validation status.
- [Repository trust and security](guides/仓库信任与安全配置.md): verified publisher, Dependency graph, and security gates.

## Crop UI

The default editor uses a mobile bottom-action layout: the top bar shows the `Position` title and close button, the center area shows the image positioning preview, and the bottom bar contains Fit / Fill, Rotate, aspect-ratio presets, and the save button. Aspect ratios are configured with `ImageClipAspectRatio(label, width, height)`: `label` only controls the UI text, while `width / height` controls the actual crop ratio.

Use `imagePath` / `initialImagePath` for local gallery images whenever possible. That lets preview and save operations enter the file-backed pipeline directly, so the business page does not need to keep a full original image in memory as `Uint8List`. Use `imageBytes` for network images, in-memory images, or inputs without a stable file path.

`showImageClipEditor` enables `ImageClipPlatformDecodeAdapter` by default. Fullscreen usage usually only needs the image path and business-level settings; pass a custom `processor` or `previewDecodeSettings` only when you need stricter limits or custom platform behavior.

If your app persists crop metadata, pass `initialRotationDegrees` and `initialCropRegion` to restore the previous visible position. Use `result.region` for `initialCropRegion`. The region may use negative `x` / `y` or a width / height larger than the source image to encode Fit-mode left/right or top/bottom blank space. If `initialAspectRatio` is not provided, the editor maps `initialCropRegion` into the rotated preview and selects the nearest supported aspect ratio from `aspectRatios`. `initialRotationDegrees` supports 90-degree increments; non-positive crop sizes are ignored.

```dart
import 'package:flutter_image_clip/flutter_image_clip.dart';

final result = await showImageClipEditor(
  context,
  imageBytes: bytes,
  imageLabel: 'avatar.jpg',
  initialAspectRatio: ImageClipAspectRatio.square,
  initialRotationDegrees: 90,
  initialCropRegion: const CropRegion(
    x: 120,
    y: 80,
    width: 480,
    height: 640,
    cornerRadius: 0,
  ),
  aspectRatios: const [
    ImageClipAspectRatio.square,
    ImageClipAspectRatio.portrait,
    ImageClipAspectRatio.landscape,
    ImageClipAspectRatio.widescreen,
    ImageClipAspectRatio.ratio16x10,
    ImageClipAspectRatio.ratio10x16,
  ],
  outputSettings: const ImageClipOutputSettings.jpeg(jpegQuality: 88),
  previewDecodeSettings: const ImageClipDecodeSettings.preview(
    targetLongSide: 1600,
  ),
  processingSettings: const ImageClipProcessingSettings(
    maxInputPixels: 48000000,
    maxOutputPixels: 16000000,
    autoDownscale: true,
  ),
  theme: ImageClipEditorTheme.fromColorScheme(
    Theme.of(context).colorScheme,
  ),
  cropAreaHeight: 456,
  onProgress: (progress) {
    debugPrint('${progress.stage.name}: ${progress.fraction}');
  },
);

if (result != null) {
  final croppedBytes = result.cropped.bytes;
  final sourceRegion = result.region;
  final previewRegion = result.previewRegion;
  final rotationDegrees = result.rotationDegrees;
  final flippedHorizontally = result.flippedHorizontally;
  final flippedVertically = result.flippedVertically;
}
```

Local file input:

```dart
final result = await showImageClipEditor(
  context,
  imagePath: picked.path,
  imageLabel: picked.name,
  previewDecodeSettings: const ImageClipDecodeSettings.preview(
    targetLongSide: 1200,
  ),
);
```

`ImageClipResult` contains source/cropped images, source-space crop metadata, preview-space crop metadata, and transform metadata:

```dart
{
  source: EditedImage(...),
  cropped: EditedImage(...),
  region: CropRegion(
    x: 120,
    y: 0,
    width: 480,
    height: 640,
    cornerRadius: 0,
  ),
  previewRegion: CropRegion(
    x: 0,
    y: 120,
    width: 640,
    height: 480,
    cornerRadius: 0,
  ),
  rotationDegrees: 90,
  flippedHorizontally: true,
  flippedVertically: false,
}
```

## Embedded Editor

```dart
ImageClipEditor(
  initialImagePath: picked.path,
  initialImageLabel: picked.name,
  initialAspectRatio: const ImageClipAspectRatio(
    label: 'Banner',
    width: 16,
    height: 9,
  ),
  aspectRatios: const [
    ImageClipAspectRatio.square,
    ImageClipAspectRatio.widescreen,
    ImageClipAspectRatio.ratio16x10,
    ImageClipAspectRatio.ratio10x16,
    ImageClipAspectRatio(label: 'Banner', width: 3, height: 1),
  ],
  outputSettings: const ImageClipOutputSettings.png(),
  cropAreaHeight: 420,
  previewDecodeSettings: const ImageClipDecodeSettings.preview(
    targetLongSide: 1280,
  ),
  showResultPage: false,
  onResult: (result) {
    final croppedBytes = result.cropped.bytes;
  },
)
```

`previewDecodeSettings` only controls the interactive preview. As long as the editor still has the original bytes or a local file path, saving maps the preview crop area back to the source image before export.

## Controller API

`ImageClipEditorController` is useful for avatar upload, profile forms, and other flows where business controls trigger crop actions.

```dart
final controller = ImageClipEditorController();

ImageClipEditor(
  controller: controller,
  loadSampleOnStart: false,
  showResultPage: false,
  onResult: (result) {
    final bytes = result.cropped.bytes;
  },
);

await controller.loadImageFile(picked.path, label: picked.name);
// Use bytes only when there is no stable file path:
// await controller.loadImage(bytes, label: 'avatar.jpg');
controller.resetView();
await controller.rotateRight();
await controller.flipHorizontal();

final result = await controller.crop();
if (result != null) {
  final croppedBytes = result.cropped.bytes;
}
final region = controller.currentCropRegion();
controller.cancelTask();
```

When a new image load request finishes after a newer request has already started, the editor ignores the stale result to avoid showing outdated crop state.

## Labels

```dart
ImageClipEditor(
  labels: const ImageClipEditorLabels(
    editorTitle: 'Position',
    positionHint: 'Pinch to zoom • Drag to reposition',
    cancelButton: 'Close',
    saveButton: 'Use photo',
    fitButton: 'Fit',
    fillButton: 'Fill',
    rotateButton: 'Rotate',
    cropCompleteStatus: 'Photo cropped',
  ),
)
```

`flipHorizontalButton` and `flipVerticalButton` are still used by result-page metadata. The default editor toolbar does not show flip buttons; use `ImageClipEditorController.flipHorizontal()` and `ImageClipEditorController.flipVertical()` when your app needs those actions.

## Theme

```dart
ImageClipEditor(
  theme: const ImageClipEditorTheme(
    backgroundColor: Color(0xFFFFFFFF),
    previewBackgroundColor: Color(0xFFF8F9FA),
    surfaceColor: Color(0xFFFFFFFF),
    imageBackgroundColor: Color(0xFFF8F9FA),
    primaryTextColor: Color(0xFF05120D),
    secondaryTextColor: Color(0xFF6A7282),
    accentColor: Color(0xFF10B062),
    accentSurfaceColor: Color(0xFFD6F1E1),
    onAccentColor: Color(0xFFFFFFFF),
    cropShadeColor: Color(0x80000000),
    cropBorderColor: Color(0xFFFFFFFF),
  ),
)
```

For the older dark look, start from `const ImageClipEditorTheme.dark()` and override individual tokens. You can also derive a theme from the host app:

```dart
ImageClipEditor(
  theme: ImageClipEditorTheme.fromColorScheme(
    Theme.of(context).colorScheme,
  ),
)
```

Layout tokens are part of the same theme object:

```dart
ImageClipEditor(
  theme: const ImageClipEditorTheme(
    topBarHeight: 60,
    bottomBarHeight: 320,
    compactBottomBarHeight: 200,
    bottomBarContentHeight: 320,
    maxSaveButtonWidth: 280,
    saveButtonHeight: 44,
    toolButtonGap: 36,
    aspectRatioGap: 18,
  ),
)
```

## Image Processing APIs

```dart
final processor = ImageProcessor();

final info = processor.probeBytes(bytes);
debugPrint('${info.format.name} ${info.dimensionsLabel}');
if (!info.canDecodeWithDart) {
  // HEIC/HEIF should be converted by the platform picker or native layer first.
}

final image = await processor.decodeBytes(bytes, label: 'input.jpg');
final preview = await processor.decodePreviewBytes(
  bytes,
  label: 'input.jpg',
  targetLongSide: 1080,
);
debugPrint('${preview.dimensionsLabel} from ${preview.sourceWidth}x${preview.sourceHeight}');
final cropped = await processor.cropRegion(
  image,
  const CropRegion(x: 20, y: 20, width: 240, height: 240, cornerRadius: 0),
);
final rotated = await processor.rotate(
  cropped,
  degrees: 90,
  outputSettings: const ImageClipOutputSettings.jpeg(jpegQuality: 88),
);
final adjusted = await processor.adjustColor(
  rotated,
  const ColorAdjustment(brightness: 1.05, contrast: 1.1, saturation: 0.95),
);
final png = await processor.exportPng(adjusted);
final jpeg = await processor.exportJpeg(adjusted, quality: 88);
```

Use file paths for local gallery images to avoid loading full originals into the UI isolate:

```dart
final result = await processor.processFile(
  '/path/to/camera.jpg',
  steps: const [
    ImageClipPipelineStep.cropRegion(
      CropRegion(x: 120, y: 80, width: 1200, height: 900, cornerRadius: 0),
    ),
  ],
  outputSettings: const ImageClipOutputSettings.jpeg(jpegQuality: 88),
);

await processor.writeImageToFile(result, '/path/to/cropped.jpg');
```

Use a pipeline when multiple operations can be completed in one background task:

```dart
final result = await processor.processBytes(
  bytes,
  label: 'input.jpg',
  steps: const [
    ImageClipPipelineStep.rotate(),
    ImageClipPipelineStep.cropRegion(
      CropRegion(x: 20, y: 20, width: 240, height: 240, cornerRadius: 0),
    ),
    ImageClipPipelineStep.adjustColor(
      ColorAdjustment(brightness: 1.05, contrast: 1.1, saturation: 0.95),
    ),
  ],
  outputSettings: const ImageClipOutputSettings.jpeg(jpegQuality: 88),
);
```

Clean saved coordinates before use:

```dart
final safeRegion = savedRegion.clampToBounds(
  sourceWidth: imageWidth,
  sourceHeight: imageHeight,
);
```

`ImageClipResult.region` / `sourceRegion` represent the crop frame mapped into source-image coordinates and can extend outside the source bounds to preserve Fit-mode blank space. Persist `region`, `rotationDegrees`, `flippedHorizontally`, and `flippedVertically`; pass `region` back as `initialCropRegion`. `previewRegion` represents the current preview size and should usually stay internal to the UI.

Reuse the editor's aspect-ratio inference outside the editor:

```dart
final ratio = ImageClipAspectRatio.fromCropRegion(
  safeRegion,
  rotationDegrees: savedRotationDegrees,
  presets: ImageClipAspectRatio.defaults,
);
```

Use `ImageClipSession` for continuous edits:

```dart
final source = await processor.decodeBytes(bytes, label: 'input.jpg');
final session = ImageClipSession(image: source, processor: processor);

await session.rotate();
await session.flipHorizontal();
await session.cropRegion(
  const CropRegion(x: 20, y: 20, width: 240, height: 240, cornerRadius: 0),
);
final jpeg = await session.exportImage(
  outputSettings: const ImageClipOutputSettings.jpeg(jpegQuality: 88),
);
```

Use `ImageClipCropTransform` if your app owns the editing preview and only needs the coordinate mapping:

```dart
const transform = ImageClipCropTransform(
  rotationDegrees: 90,
  flipHorizontal: true,
);

final sourceRegion = transform.sourceRegionForPreview(
  sourceWidth: source.width,
  sourceHeight: source.height,
  previewRegion: previewRegion,
);
```

For work that already runs in a background isolate, or for small images, use `ImageClipDecodedSession` to avoid repeated intermediate encodes:

```dart
final session = ImageClipDecodedSession.decode(bytes, label: 'input.jpg');
session.rotate();
session.cropRegion(
  const CropRegion(x: 20, y: 20, width: 240, height: 240, cornerRadius: 0),
);
final jpeg = session.exportImage(
  outputSettings: const ImageClipOutputSettings.jpeg(jpegQuality: 88),
);
```

Task API:

```dart
final task = processor.processBytesTask(
  bytes,
  label: 'input.jpg',
  steps: const [
    ImageClipPipelineStep.rotate(),
    ImageClipPipelineStep.cropRegion(
      CropRegion(x: 20, y: 20, width: 240, height: 240, cornerRadius: 0),
    ),
  ],
  options: ImageClipTaskOptions(
    timeout: Duration(seconds: 8),
    onProgress: (progress) {
      debugPrint('${progress.message}: ${progress.fraction}');
    },
  ),
);

// task.cancel();
final result = await task.result;
```

`decodeBytes` and later crop/rotate operations automatically bake EXIF orientation, so rotated mobile photos enter the crop flow in their visual orientation.

## Native Decode Adapter

`ImageClipPlatformDecodeAdapter` calls the built-in Android/iOS native implementation before the Dart image pipeline. It can convert HEIC/HEIF or run sampled decode for large images. Photo previews prefer JPEG, while images with alpha use PNG to preserve transparency:

```dart
final processor = ImageProcessor(
  decodeAdapter: const ImageClipPlatformDecodeAdapter(),
);
```

When a file-backed pipeline only contains region crop, 90-degree rotation, flips, and JPEG output, the built-in platform adapter can try the native `cropFile` fast path. Unsupported platforms, unsupported parameters, PNG output, or unavailable native channels automatically fall back to the Dart isolate pipeline.

Custom adapter example:

```dart
class NativeDecodeAdapter extends ImageClipDecodeAdapter {
  const NativeDecodeAdapter();

  @override
  bool supportsDecode(
    ImageClipImageInfo info,
    ImageClipDecodeSettings settings,
  ) {
    return settings.usePlatformAdapter &&
        (!info.canDecodeWithDart || info.hasDimensions);
  }

  @override
  Future<ImageClipDecodeAdapterResult?> decode(
    Uint8List bytes, {
    required ImageClipImageInfo info,
    required String label,
    required ImageClipDecodeSettings settings,
  }) async {
    final normalizedBytes = await normalizeOnPlatform(
      bytes,
      targetLongSide: settings.targetLongSide,
    );
    return ImageClipDecodeAdapterResult(
      bytes: normalizedBytes.bytes,
      sourceWidth: normalizedBytes.sourceWidth,
      sourceHeight: normalizedBytes.sourceHeight,
    );
  }
}
```

Platform failures are mapped to typed Dart exceptions: unsupported formats throw `ImageClipUnsupportedFormatException`, invalid parameters or channel precondition failures throw `ImageClipPlatformException`, and native decode/encode failures throw `ImageClipDecodeException`.

## Benchmarks and Checks

```sh
dart run benchmark/image_processor_benchmark.dart
dart run benchmark/image_processor_benchmark.dart --json
dart run benchmark/image_processor_benchmark.dart --check benchmark/baseline.json
dart run tool/check_api_snapshot.dart
dart run tool/check_public_api_docs.dart
```

The benchmark reports average and median time, process RSS delta, output dimensions, and output bytes for decode, rotate/crop/export JPEG, large-image downscale, JPEG preview decode, and file-path crop export. `--check` compares median time, memory delta, and output bytes with `benchmark/baseline.json` for CI regression detection.

## Large Image Protection

```dart
final processor = ImageProcessor(
  processingSettings: const ImageClipProcessingSettings(
    maxInputPixels: 48000000,
    maxOutputPixels: 16000000,
    autoDownscale: true,
  ),
);

try {
  final image = await processor.decodeBytes(bytes, label: 'camera.jpg');
  final cropped = await processor.cropRegion(
    image,
    const CropRegion(x: 0, y: 0, width: 1200, height: 1200, cornerRadius: 0),
  );
} on ImageClipImageTooLargeException catch (error) {
  debugPrint('Image is too large: ${error.width} x ${error.height}');
} on ImageClipDecodeException catch (error) {
  debugPrint(error.message);
}
```

The default settings reject inputs above 48 million pixels and automatically downscale outputs above 16 million pixels. Use `const ImageClipProcessingSettings.unrestricted()` only when your app owns the memory risk.

## Compatibility

Import public APIs from `package:flutter_image_clip/flutter_image_clip.dart`. Avoid depending on files under `src/`.

The package requires Dart `>=3.10.0 <4.0.0` and Flutter `>=3.38.1`. CI covers both the minimum supported Flutter version and the latest stable version. The editor inherits the host app's font and does not bundle a custom typeface.

Breaking public API changes should bump the major version, new capabilities should bump the minor version, and fixes should bump the patch version. Document migration notes in `CHANGELOG.md`.

## Local Development

```sh
flutter pub get
dart format lib test benchmark tool example/lib example/integration_test
flutter analyze
flutter test
dart run tool/check_api_snapshot.dart
dart run tool/check_public_api_docs.dart
dart run benchmark/image_processor_benchmark.dart --check benchmark/baseline.json
dart doc --output doc/api
dart pub publish --dry-run
cd example
flutter pub get
flutter test integration_test
flutter run
```

## License

MIT License. See `LICENSE`.

## 简体中文

`flutter_image_clip` 是一个面向 Android 和 iOS 的 Flutter 图片裁剪与位图处理库，提供可直接打开的全屏裁剪 UI、可嵌入业务页面的裁剪组件，以及基于后台 isolate 的图像处理 API。README 默认以英文展示，本节提供中文说明。

### 功能

- `showImageClipEditor`：一行代码打开完整裁剪界面。
- `ImageClipEditor`：把裁剪器嵌入业务页面、表单或上传流程。
- `ImageClipEditorController`：由父组件主动加载图片、重置视图、旋转、翻转、裁剪和取消任务。
- 支持 Android 和 iOS。
- 支持拖动、双指缩放、双击复位。
- 支持命名比例预设、Fit / Fill、90 度旋转。
- 通过 `ImageClipEditorLabels` 覆盖编辑器按钮、状态和结果页文案，默认文案为英文。
- 裁剪结果可输出 PNG 或 JPEG，并可配置 JPEG quality。
- 支持解码、中心裁剪、区域裁剪、旋转、翻转、缩放、调色、PNG/JPEG 导出。
- 可在完整解码前探测 PNG、JPEG、GIF、WebP、HEIC、HEIF。
- 可用 `ImageClipDecodeSettings.preview` 生成小图预览，同时保留原图尺寸元数据。
- 内置 `ImageClipPlatformDecodeAdapter`，也可以通过 `ImageClipDecodeAdapter` 接入自定义 HEIC/HEIF 转码或平台 sampled decode。
- 支持 `decodeFile`、`processFile` 和 `writeImageToFile`，本地大图可直接进入文件链路。
- 多步图像操作可合并为一次后台任务，减少重复编解码。
- `ImageClipSession` 和 `ImageClipDecodedSession` 适合连续编辑状态管理。
- `ImageClipTask` 支持进度监听、取消和超时。

### 安装

发布到 pub.dev 后，在业务项目的 `pubspec.yaml` 中添加：

```yaml
dependencies:
  flutter_image_clip: ^0.9.2
```

执行：

```sh
flutter pub get
```

发布前本地调试可以使用 `path` 依赖：

```yaml
dependencies:
  flutter_image_clip:
    path: /Users/admin/Desktop/demos/flutter_image_clip_demo
```

### 文档导航

- [常见接入配方](guides/接入配方.md)：头像、封面、`image_picker`、HEIC、文件路径、大图和异常处理。
- [平台与 CI 矩阵](guides/平台矩阵.md)：Android/iOS 原生解码能力、设备测试覆盖和发布前校验。
- [可访问性检查清单](guides/可访问性检查清单.md)：VoiceOver、TalkBack、大字体、键盘和对比度验收项。
- [故障排查](guides/故障排查.md)：HEIC、大图内存、EXIF、golden、iOS privacy 和 pub.dev 自动发布问题。
- [迁移指南](guides/迁移指南.md)：按版本说明兼容性变化和升级检查项。
- [发布流程](guides/发布流程.md)：tag、release checks、pub.dev OIDC 自动发布和失败处理。
- [真实设备验收](guides/真实设备验收.md)：Android/iOS 真机图片样本和发布前验收记录。
- [真实设备验收记录](guides/真实设备验收记录.md)：逐版本真机验收状态表。
- [仓库信任与安全配置](guides/仓库信任与安全配置.md)：verified publisher、Dependency graph 和安全门禁配置。

### 快速使用

全屏裁剪建议优先传 `imagePath`，这样相册本地文件可以走 file-backed preview/save 链路，避免业务页提前持有完整原图 bytes。只有网络图、内存图或没有稳定本地路径时再传 `imageBytes`。

如果需要保存后下次恢复编辑器位置，持久化 `result.region`、`result.rotationDegrees`、`result.flippedHorizontally` 和 `result.flippedVertically`。恢复时把 `region` 传给 `initialCropRegion`。`region` 可能包含负数 `x` / `y`，或者超出原图边界的 `width` / `height`，用于表达 Fit 模式下左右或上下留白。

```dart
final result = await showImageClipEditor(
  context,
  imagePath: picked.path,
  imageLabel: picked.name,
  initialAspectRatio: ImageClipAspectRatio.square,
  outputSettings: const ImageClipOutputSettings.jpeg(jpegQuality: 88),
  previewDecodeSettings: const ImageClipDecodeSettings.preview(
    targetLongSide: 1200,
  ),
);

if (result != null) {
  final croppedBytes = result.cropped.bytes;
  final sourceRegion = result.region;
  final previewRegion = result.previewRegion;
}
```

嵌入式页面：

```dart
ImageClipEditor(
  initialImagePath: picked.path,
  initialImageLabel: picked.name,
  initialAspectRatio: ImageClipAspectRatio.square,
  aspectRatios: const [
    ImageClipAspectRatio.square,
    ImageClipAspectRatio.portrait,
    ImageClipAspectRatio.landscape,
    ImageClipAspectRatio.widescreen,
  ],
  showResultPage: false,
  onResult: (result) {
    final croppedBytes = result.cropped.bytes;
  },
)
```

控制器适合由业务按钮驱动裁剪流程：

```dart
final controller = ImageClipEditorController();

ImageClipEditor(
  controller: controller,
  loadSampleOnStart: false,
  showResultPage: false,
  onResult: (result) {
    final bytes = result.cropped.bytes;
  },
);

await controller.loadImageFile(picked.path, label: picked.name);
await controller.rotateRight();
final result = await controller.crop();
controller.cancelTask();
```

### 图像处理

本地文件可直接走文件路径处理，减少 UI isolate 的大字节数组占用：

```dart
final processor = ImageProcessor();

final result = await processor.processFile(
  '/path/to/camera.jpg',
  steps: const [
    ImageClipPipelineStep.cropRegion(
      CropRegion(x: 120, y: 80, width: 1200, height: 900, cornerRadius: 0),
    ),
  ],
  outputSettings: const ImageClipOutputSettings.jpeg(jpegQuality: 88),
);

await processor.writeImageToFile(result, '/path/to/cropped.jpg');
```

多步处理建议使用 pipeline，在一次后台任务里完成 decode、transform 和 encode：

```dart
final result = await processor.processBytes(
  bytes,
  label: 'input.jpg',
  steps: const [
    ImageClipPipelineStep.rotate(),
    ImageClipPipelineStep.cropRegion(
      CropRegion(x: 20, y: 20, width: 240, height: 240, cornerRadius: 0),
    ),
  ],
  outputSettings: const ImageClipOutputSettings.jpeg(jpegQuality: 88),
);
```

### 原生解码适配

`ImageClipPlatformDecodeAdapter` 会在进入 Dart 图像管线前调用库内置的 Android/iOS 原生实现，用于 HEIC/HEIF 转码或大图 sampled decode。`showImageClipEditor` 默认启用该适配器；自定义处理器时可以显式配置：

```dart
final processor = ImageProcessor(
  decodeAdapter: const ImageClipPlatformDecodeAdapter(),
);
```

当文件管线只包含区域裁剪、90 度倍数旋转、翻转且输出为 JPEG 时，内置平台适配器会尝试走原生 `cropFile` 快路径；平台不支持、参数超出能力、PNG 输出或通道不可用时会自动回退到 Dart isolate 管线。

### 大图保护与异常

默认配置会拒绝超过 4800 万像素的输入，并把超过 1600 万像素的输出自动 downscale。需要自定义限制时：

```dart
final processor = ImageProcessor(
  processingSettings: const ImageClipProcessingSettings(
    maxInputPixels: 48000000,
    maxOutputPixels: 16000000,
    autoDownscale: true,
  ),
);
```

需要完全关闭限制时可使用 `const ImageClipProcessingSettings.unrestricted()`，但业务侧需要自行承担内存风险。

### 本地开发

```sh
flutter pub get
dart format lib test benchmark tool example/lib example/integration_test
flutter analyze
flutter test
dart run tool/check_api_snapshot.dart
dart run tool/check_public_api_docs.dart
dart run benchmark/image_processor_benchmark.dart --check benchmark/baseline.json
dart doc --output doc/api
dart pub publish --dry-run
cd example
flutter pub get
flutter test integration_test
flutter run
```

### 兼容性与许可证

业务侧应从 `package:flutter_image_clip/flutter_image_clip.dart` 导入公开 API，避免直接依赖 `src/` 下的内部实现。根包兼容 Dart `>=3.10.0 <4.0.0`、Flutter `>=3.38.1`。

MIT License。详见 `LICENSE`。
