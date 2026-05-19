# flutter_image_clip

`flutter_image_clip` 是一个 Flutter 图片裁剪与位图处理库，提供可直接打开的裁剪 UI、可嵌入页面的裁剪组件，以及基于后台 isolate 的图像处理 API。

## 功能

- `showImageClipEditor`：一行代码打开完整裁剪界面。
- `ImageClipEditor`：可嵌入业务页面的裁剪 Widget。
- `ImageClipEditorController`：从父组件主动加载图片、重置视图、旋转和触发裁剪。
- 平台支持：Android 和 iOS。
- 手势支持：拖动、双指缩放、双击复位。
- 裁剪模式：可配置命名比例预设、Fit / Fill、90 度旋转。
- 文案配置：通过 `ImageClipEditorLabels` 覆盖按钮、状态、结果页文案，默认使用英文。
- 输出格式：裁剪结果可输出 PNG 或 JPEG，并可配置 JPEG quality。
- 图像处理：解码、中心裁剪、区域裁剪、旋转、翻转、缩放、调色、PNG/JPEG 导出。
- 输入探测：可在完整解码前识别 PNG、JPEG、GIF、WebP、HEIC、HEIF，用于移动端大图保护和格式提示。
- 预览解码：通过 `ImageClipDecodeSettings.preview` 为编辑器或业务预览生成小图，同时保留原图尺寸元数据。
- 原生解码适配：通过 `ImageClipDecodeAdapter` 接入 HEIC/HEIF 转码或平台 sampled decode。
- 批处理 pipeline：多步图像操作可合并为一次后台任务，减少重复编解码。
- 编辑会话：通过 `ImageClipSession` 持有连续编辑状态，减少业务层手动传递中间结果。
- 解码会话：通过 `ImageClipDecodedSession` 保留已解码像素，适合后台 isolate 或小图连续处理。
- 可取消任务：通过 `ImageClipTask` 监听进度、取消任务或设置超时。
- 处理任务通过后台 isolate 执行，并使用 `TransferableTypedData` 传输大字节数组，降低 UI isolate 压力。

## 安装

发布到 pub.dev 后，在业务项目的 `pubspec.yaml` 中添加：

```yaml
dependencies:
  flutter_image_clip: ^0.6.5
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
  onProgress: (progress) {
    debugPrint('${progress.stage.name}: ${progress.fraction}');
  },
);

if (result != null) {
  final croppedBytes = result.cropped.bytes;
  // 原图坐标：实际用于裁剪 source 的像素区域。
  final region = result.region;
  // 预览坐标：用户在旋转预览中看到的裁剪区域。
  final previewRegion = result.previewRegion;
  final rotationDegrees = result.rotationDegrees;
  final flippedHorizontally = result.flippedHorizontally;
  final flippedVertically = result.flippedVertically;
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
  previewDecodeSettings: const ImageClipDecodeSettings.preview(
    targetLongSide: 1280,
  ),
  showResultPage: false,
  onResult: (result) {
    final croppedBytes = result.cropped.bytes;
  },
)
```

`previewDecodeSettings` 只约束编辑器交互预览。只要编辑器还持有原始输入 bytes，保存时会把预览裁剪框映射回原图坐标，并从原图导出最终结果。

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
// 只更新编辑器预览，不会立即重编码整张图。
await controller.rotateRight();
await controller.flipHorizontal();

final result = await controller.crop();
if (result != null) {
  final croppedBytes = result.cropped.bytes;
}
final region = controller.currentCropRegion();
controller.cancelTask();
```

当新的图片加载请求早于旧请求完成时，编辑器会忽略旧请求的回写结果，避免业务快速切换图片时显示过期裁剪状态。

## 自定义编辑器文案

```dart
ImageClipEditor(
  labels: const ImageClipEditorLabels(
    cancelButton: 'Close',
    saveButton: 'Use photo',
    flipHorizontalButton: 'Flip H',
    flipVerticalButton: 'Flip V',
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

连续编辑可以使用 session 持有当前图像状态：

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

如果业务自己做编辑预览，可以使用 `ImageClipCropTransform` 复用编辑器的坐标映射逻辑：

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

如果连续处理已经运行在后台 isolate 中，或图片较小，可以使用 decoded session 避免中间结果重复编码：

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

如果需要进度、取消或超时控制，可以使用 task API：

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

`decodeBytes` 和后续裁剪/旋转处理会自动烘焙 EXIF orientation，手机拍摄的旋转照片会按视觉方向进入裁剪流程。

## 原生解码适配

`ImageClipDecodeAdapter` 用来在进入 Dart 图像管线前接入平台能力，例如 HEIC/HEIF 转码、大图 sampled decode 或厂商相册返回格式归一化。纯 Dart fallback 会在完整解码后再缩放预览；如果需要真正减少大图解码内存，应在 adapter 内按 `ImageClipDecodeSettings.targetLongSide` 做平台侧采样。

```dart
class NativeDecodeAdapter extends ImageClipDecodeAdapter {
  const NativeDecodeAdapter();

  @override
  bool supports(ImageClipImageInfo info) {
    return !info.canDecodeWithDart || info.hasDimensions;
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

final processor = ImageProcessor(
  decodeAdapter: const NativeDecodeAdapter(),
);
```

## 性能基准

```sh
dart run benchmark/image_processor_benchmark.dart
dart run benchmark/image_processor_benchmark.dart --json
dart run benchmark/image_processor_benchmark.dart --check benchmark/baseline.json
```

基准脚本会输出解码、旋转裁剪导出 JPEG、大图 downscale 的平均耗时、中位耗时、输出尺寸和字节数。`--check` 会按 `benchmark/baseline.json` 检查中位耗时和输出字节数，适合放进 CI 防止性能回退。

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
dart run benchmark/image_processor_benchmark.dart --check benchmark/baseline.json
dart doc --output doc/api
flutter pub publish --dry-run
flutter run -t example/lib/main.dart
```

## 许可证

MIT License。详见 `LICENSE`。
