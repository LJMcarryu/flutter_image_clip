import 'package:flutter_image_clip/flutter_image_clip.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('runs the image processing pipeline off the UI isolate', () async {
    final processor = ImageProcessor();

    final sample = await processor.createSample();
    expect(sample.width, 960);
    expect(sample.height, 640);
    expect(sample.bytes, isNotEmpty);

    final cropped = await processor.cropCenter(
      sample,
      const CropSettings(widthRatio: 0.5, heightRatio: 0.25, cornerRadius: 16),
    );
    expect(cropped.width, 480);
    expect(cropped.height, 160);

    final gestureCropped = await processor.cropRegion(
      sample,
      const CropRegion(x: 120, y: 80, width: 300, height: 220, cornerRadius: 8),
    );
    expect(gestureCropped.operation, 'Crop region');
    expect(gestureCropped.width, 300);
    expect(gestureCropped.height, 220);

    final rotated = await processor.rotateRight(cropped);
    expect(rotated.width, 160);
    expect(rotated.height, 480);

    final adjusted = await processor.adjustColor(
      rotated,
      const ColorAdjustment(brightness: 1.08, contrast: 1.1, saturation: 0.9),
    );
    expect(adjusted.operation, 'Adjust color');
    expect(adjusted.bytes, isNotEmpty);

    final exported = await processor.exportPng(adjusted);
    expect(exported.operation, 'Export PNG');
    expect(exported.format, ImageClipOutputFormat.png);
    expect(exported.bytes, isNotEmpty);

    final jpeg = await processor.exportJpeg(adjusted, quality: 82);
    expect(jpeg.operation, 'Export JPEG');
    expect(jpeg.format, ImageClipOutputFormat.jpeg);
    expect(jpeg.mimeType, 'image/jpeg');
    expect(jpeg.bytes.sublist(0, 2), <int>[0xFF, 0xD8]);
  });
}
