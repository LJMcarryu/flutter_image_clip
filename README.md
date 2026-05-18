# flutter_image_clip

`flutter_image_clip` 是一个 Flutter 图片裁剪与位图处理库，提供可直接打开的裁剪 UI、可嵌入页面的裁剪组件，以及纯 Dart 图像处理 API。

## 功能

- `showImageClipEditor`：一行代码打开完整裁剪界面。
- `ImageClipEditor`：可嵌入业务页面的裁剪 Widget。
- 手势支持：拖动、双指缩放、鼠标滚轮缩放、双击复位。
- 裁剪模式：Portrait / Landscape、Fit / Fill、90 度旋转。
- 图像处理：解码、中心裁剪、区域裁剪、旋转、翻转、缩放、调色、PNG 导出。
- 处理任务通过 Flutter `compute` 执行，降低 UI isolate 压力。

## 安装

发布到 pub.dev 后，在业务项目的 `pubspec.yaml` 中添加：

```yaml
dependencies:
  flutter_image_clip: ^0.1.0
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
  showResultPage: false,
  onResult: (result) {
    final croppedBytes = result.cropped.bytes;
  },
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
```

## 本地开发

```sh
flutter pub get
dart format lib test example
flutter analyze
flutter test
flutter pub publish --dry-run
flutter run -t example/lib/main.dart
```

## 许可证

MIT License。详见 `LICENSE`。
