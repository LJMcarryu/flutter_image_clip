# flutter_image_clip

`flutter_image_clip` 是一个 Flutter 图片裁剪与位图处理库，提供可直接打开的裁剪 UI、可嵌入页面的裁剪组件，以及基于后台 isolate 的图像处理 API。

## 功能

- `showImageClipEditor`：一行代码打开完整裁剪界面。
- `ImageClipEditor`：可嵌入业务页面的裁剪 Widget。
- `ImageClipEditorController`：从父组件主动加载图片、重置视图、旋转和触发裁剪。
- 手势支持：拖动、双指缩放、鼠标滚轮缩放、双击复位。
- 裁剪模式：可配置命名比例预设、Fit / Fill、90 度旋转。
- 文案配置：通过 `ImageClipEditorLabels` 覆盖按钮、状态、结果页文案，默认使用英文。
- 输出格式：裁剪结果可输出 PNG 或 JPEG，并可配置 JPEG quality。
- 图像处理：解码、中心裁剪、区域裁剪、旋转、翻转、缩放、调色、PNG/JPEG 导出。
- 批处理 pipeline：多步图像操作可合并为一次后台任务，减少重复编解码。
- 处理任务通过 Flutter `compute` 执行，降低 UI isolate 压力。

## 安装

发布到 pub.dev 后，在业务项目的 `pubspec.yaml` 中添加：

```yaml
dependencies:
  flutter_image_clip: ^0.5.0
```

然后执行：

```sh
flutter pub get
```

如果发布前需要本地调试，可以临时使用 `path` 依赖：

```yaml
dependencies:
  flutter_image_clip:
    path: /Users/admin/Desktop/demos/flutter_image_clip_demo
```

## 使用裁剪 UI

```dart
import 'package:flutter_image_clip/flutter_image_clip.dart';

final result = await showImageClipEditor(
  context,
  imageBytes: bytes,
  imageLabel: 'avatar.jpg',
  initialAspectRatio: ImageClipAspectRatio.square,
  aspectRatios: const [
    ImageClipAspectRatio.square,
    ImageClipAspectRatio.portrait,
    ImageClipAspectRatio.landscape,
    ImageClipAspectRatio.widescreen,
  ],
  outputSettings: const ImageClipOutputSettings.jpeg(jpegQuality: 88),
  processingSettings: const ImageClipProcessingSettings(
    maxInputPixels: 48000000,
    maxOutputPixels: 16000000,
    autoDownscale: true,
  ),
  theme: ImageClipEditorTheme.fromColorScheme(
    Theme.of(context).colorScheme,
  ),
);

if (result != null) {
  final croppedBytes = result.cropped.bytes;
  final region = result.region;
  final rotationDegrees = result.rotationDegrees;
}
```

`ImageClipResult` 返回结构：

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
  rotationDegrees: 90,
}
```

## 嵌入页面

```dart
ImageClipEditor(
  initialImageBytes: bytes,
  initialImageLabel: 'cover.jpg',
  initialAspectRatio: const ImageClipAspectRatio(
    label: 'Banner',
    width: 16,
    height: 9,
  ),
  aspectRatios: const [
    ImageClipAspectRatio.square,
    ImageClipAspectRatio.widescreen,
    ImageClipAspectRatio(label: 'Banner', width: 3, height: 1),
  ],
  outputSettings: const ImageClipOutputSettings.png(),
  showResultPage: false,
  onResult: (result) {
    final croppedBytes = result.cropped.bytes;
  },
)
```

## 使用控制器

`ImageClipEditorController` 适合头像上传、资料编辑器、表单页等需要由业务按钮驱动裁剪流程的场景。

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

await controller.loadImage(bytes, label: 'avatar.jpg');
controller.resetView();
await controller.rotateRight();

final result = await controller.crop();
if (result != null) {
  final croppedBytes = result.cropped.bytes;
}
final region = controller.currentCropRegion();
```

当新的图片加载请求早于旧请求完成时，编辑器会忽略旧请求的回写结果，避免业务快速切换图片时显示过期裁剪状态。

## 自定义编辑器文案

```dart
ImageClipEditor(
  labels: const ImageClipEditorLabels(
    cancelButton: 'Close',
    saveButton: 'Use photo',
    rotateButton: 'Rotate',
    cropCompleteStatus: 'Photo cropped',
  ),
)
```

## 自定义主题

```dart
ImageClipEditor(
  theme: const ImageClipEditorTheme(
    backgroundColor: Color(0xFF111827),
    surfaceColor: Color(0xFF1F2937),
    primaryTextColor: Color(0xFFF9FAFB),
    secondaryTextColor: Color(0xFFCBD5E1),
    cropBorderColor: Color(0xFFF59E0B),
    cropGridColor: Color(0x99F59E0B),
  ),
)
```

也可以从业务 App 的 `ColorScheme` 生成：

```dart
ImageClipEditor(
  theme: ImageClipEditorTheme.fromColorScheme(
    Theme.of(context).colorScheme,
  ),
)
```

## 使用图像处理 API

```dart
final processor = ImageProcessor();

final image = await processor.decodeBytes(bytes, label: 'input.jpg');
final cropped = await processor.cropRegion(
  image,
  const CropRegion(x: 20, y: 20, width: 240, height: 240, cornerRadius: 0),
);
final rotated = await processor.rotate(cropped, degrees: 90);
final adjusted = await processor.adjustColor(
  rotated,
  const ColorAdjustment(brightness: 1.05, contrast: 1.1, saturation: 0.95),
);
final png = await processor.exportPng(adjusted);
final jpeg = await processor.exportJpeg(adjusted, quality: 88);
```

多步处理建议使用 pipeline，这样会在一次后台任务里完成 decode、transform 和 encode：

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

`decodeBytes` 和后续裁剪/旋转处理会自动烘焙 EXIF orientation，手机拍摄的旋转照片会按视觉方向进入裁剪流程。

## 大图保护与异常处理

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

默认配置会拒绝超过 4800 万像素的输入，并把超过 1600 万像素的输出自动 downscale。需要完全关闭限制时可使用：

```dart
const ImageClipProcessingSettings.unrestricted()
```

## 本地开发

```sh
flutter pub get
dart format lib test example
flutter analyze
flutter test
dart doc --output doc/api
flutter pub publish --dry-run
flutter run -t example/lib/main.dart
```

## 许可证

MIT License。详见 `LICENSE`。
