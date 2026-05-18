import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Generated JPEG fixture with a specific EXIF orientation value.
class MobileImageOrientationFixture {
  /// Creates an orientation fixture.
  const MobileImageOrientationFixture({
    required this.orientation,
    required this.expectedWidth,
    required this.expectedHeight,
  });

  /// EXIF orientation value written into the fixture.
  final int orientation;

  /// Expected decoded width after orientation baking.
  final int expectedWidth;

  /// Expected decoded height after orientation baking.
  final int expectedHeight;

  /// Human-readable fixture label.
  String get label => 'exif-orientation-$orientation.jpg';

  /// Encoded JPEG bytes for this fixture.
  Uint8List get bytes {
    final image = img.Image(width: 3, height: 2)
      ..exif.imageIfd.orientation = orientation;
    image.setPixelRgb(0, 0, 255, 0, 0);
    image.setPixelRgb(1, 0, 0, 255, 0);
    image.setPixelRgb(2, 0, 0, 0, 255);
    image.setPixelRgb(0, 1, 255, 255, 0);
    image.setPixelRgb(1, 1, 0, 255, 255);
    image.setPixelRgb(2, 1, 255, 0, 255);
    return Uint8List.fromList(img.encodeJpg(image, quality: 92));
  }
}

/// Mobile image fixtures used by processing tests.
class MobileImageFixtures {
  const MobileImageFixtures._();

  /// Common EXIF orientation cases emitted by mobile cameras.
  static const orientationCases = <MobileImageOrientationFixture>[
    MobileImageOrientationFixture(
      orientation: 1,
      expectedWidth: 3,
      expectedHeight: 2,
    ),
    MobileImageOrientationFixture(
      orientation: 2,
      expectedWidth: 3,
      expectedHeight: 2,
    ),
    MobileImageOrientationFixture(
      orientation: 3,
      expectedWidth: 3,
      expectedHeight: 2,
    ),
    MobileImageOrientationFixture(
      orientation: 4,
      expectedWidth: 3,
      expectedHeight: 2,
    ),
    MobileImageOrientationFixture(
      orientation: 5,
      expectedWidth: 2,
      expectedHeight: 3,
    ),
    MobileImageOrientationFixture(
      orientation: 6,
      expectedWidth: 2,
      expectedHeight: 3,
    ),
    MobileImageOrientationFixture(
      orientation: 7,
      expectedWidth: 2,
      expectedHeight: 3,
    ),
    MobileImageOrientationFixture(
      orientation: 8,
      expectedWidth: 2,
      expectedHeight: 3,
    ),
  ];

  /// PNG fixture with fully and partially transparent pixels.
  static Uint8List transparentPng() {
    final image = img.Image(width: 4, height: 4, numChannels: 4);
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        image.setPixelRgba(x, y, 20 + x * 20, 80 + y * 20, 160, 255);
      }
    }
    image.setPixelRgba(1, 1, 255, 0, 0, 0);
    image.setPixelRgba(2, 2, 0, 255, 0, 96);
    return Uint8List.fromList(img.encodePng(image));
  }

  /// Truncated JPEG-like bytes used to exercise decode failures.
  static Uint8List corruptJpeg() {
    return Uint8List.fromList(<int>[
      0xFF,
      0xD8,
      0xFF,
      0xE0,
      0x00,
      0x10,
      ...'JFIF'.codeUnits,
      0x00,
      0x01,
      0x02,
    ]);
  }
}
