# flutter_image_clip

`flutter_image_clip` 是一个面向 Android 和 iOS 的 Flutter 图片裁剪与位图处理库，提供可直接打开的全屏裁剪 UI、可嵌入业务页面的裁剪组件，以及基于后台 isolate 的图像处理 API。

[English](https://github.com/LJMcarryu/flutter_image_clip/blob/main/README.md) | [简体中文](#flutter_image_clip)

<table>
  <tr>
    <td align="center" width="50%">
      <img src="screenshots/fullscreen-editor.webp" alt="Fullscreen crop editor" width="220">
      <br>
      <sub>全屏编辑器</sub>
    </td>
    <td align="center" width="50%">
      <img src="screenshots/embedded-lab.webp" alt="Embedded image clip lab" width="220">
      <br>
      <sub>嵌入式示例</sub>
    </td>
  </tr>
</table>

## 功能

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

## 安装

在业务项目的 `pubspec.yaml` 中添加：

```yaml
dependencies:
  flutter_image_clip: ^0.11.0
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

## 文档导航

- [常见接入配方](guides/接入配方.md)：头像、封面、`image_picker`、HEIC、文件路径、大图和异常处理。
- [平台与 CI 矩阵](guides/平台矩阵.md)：Android/iOS 原生解码能力、设备测试覆盖和发布前校验。
- [可访问性检查清单](guides/可访问性检查清单.md)：VoiceOver、TalkBack、大字体、键盘和对比度验收项。
- [故障排查](guides/故障排查.md)：HEIC、大图内存、EXIF、golden、iOS privacy 和 pub.dev 自动发布问题。
- [迁移指南](guides/迁移指南.md)：按版本说明兼容性变化和升级检查项。
- [发布流程](guides/发布流程.md)：tag、release checks、pub.dev OIDC 自动发布和失败处理。
- [真实设备验收](guides/真实设备验收.md)：Android/iOS 真机图片样本和发布前验收记录。
- [真实设备验收记录](guides/真实设备验收记录.md)：逐版本真机验收状态表。
- [仓库信任与安全配置](guides/仓库信任与安全配置.md)：verified publisher、Dependency graph 和安全门禁配置。

## 快速使用

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

主题色可以通过 `ImageClipEditorTheme` 覆盖。`progressColor` 控制图片预览解码期间显示的圆形 loading：

```dart
ImageClipEditor(
  theme: const ImageClipEditorTheme(
    progressColor: Color(0xFF10B062),
    cropShadeColor: Color(0x99FFFFFF),
    cropShadeBlurSigma: 20,
  ),
)
```

## 图像处理

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

## 原生解码适配

`ImageClipPlatformDecodeAdapter` 会在进入 Dart 图像管线前调用库内置的 Android/iOS 原生实现，用于 HEIC/HEIF 转码或大图 sampled decode。`showImageClipEditor` 默认启用该适配器；自定义处理器时可以显式配置：

```dart
final processor = ImageProcessor(
  decodeAdapter: const ImageClipPlatformDecodeAdapter(),
);
```

当文件管线只包含区域裁剪、90 度倍数旋转、翻转且输出为 JPEG 时，内置平台适配器会尝试走原生 `cropFile` 快路径；平台不支持、参数超出能力、PNG 输出或通道不可用时会自动回退到 Dart isolate 管线。

## 大图保护与异常

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

## 本地开发

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

## 兼容性与许可证

业务侧应从 `package:flutter_image_clip/flutter_image_clip.dart` 导入公开 API，避免直接依赖 `src/` 下的内部实现。根包兼容 Dart `>=3.10.0 <4.0.0`、Flutter `>=3.38.1`。

MIT License。详见 `LICENSE`。
