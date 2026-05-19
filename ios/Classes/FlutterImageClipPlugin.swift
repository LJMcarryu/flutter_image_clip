import Flutter
import UIKit
import ImageIO
import MobileCoreServices

public class FlutterImageClipPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "flutter_image_clip/decode",
      binaryMessenger: registrar.messenger()
    )
    let instance = FlutterImageClipPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "decode" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard
      let arguments = call.arguments as? [String: Any],
      let typedData = arguments["bytes"] as? FlutterStandardTypedData
    else {
      result(FlutterError(code: "invalid_args", message: "Image bytes are required", details: nil))
      return
    }

    do {
      let targetLongSide = arguments["targetLongSide"] as? Int
      let decoded = try decodeImage(data: typedData.data, targetLongSide: targetLongSide)
      result([
        "bytes": FlutterStandardTypedData(bytes: decoded.bytes),
        "sourceWidth": decoded.sourceWidth,
        "sourceHeight": decoded.sourceHeight,
      ])
    } catch {
      result(FlutterError(code: "decode_failed", message: error.localizedDescription, details: nil))
    }
  }

  private func decodeImage(data: Data, targetLongSide: Int?) throws -> DecodeResult {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
      throw DecodeError.unsupportedFormat
    }
    guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
      throw DecodeError.unsupportedFormat
    }

    let rawWidth = properties[kCGImagePropertyPixelWidth] as? Int ?? 0
    let rawHeight = properties[kCGImagePropertyPixelHeight] as? Int ?? 0
    let orientationValue = properties[kCGImagePropertyOrientation] as? UInt32 ?? 1
    let swapsAxes = [5, 6, 7, 8].contains(Int(orientationValue))
    let sourceWidth = swapsAxes ? rawHeight : rawWidth
    let sourceHeight = swapsAxes ? rawWidth : rawHeight

    let image: UIImage
    if let targetLongSide, targetLongSide > 0, max(rawWidth, rawHeight) > targetLongSide {
      let options: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: targetLongSide,
      ]
      guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
        throw DecodeError.unsupportedFormat
      }
      image = UIImage(cgImage: cgImage)
    } else {
      guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        throw DecodeError.unsupportedFormat
      }
      let orientation = UIImage.Orientation(cgImagePropertyOrientation: orientationValue)
      image = UIImage(cgImage: cgImage, scale: 1, orientation: orientation).normalized()
    }

    guard let png = image.pngData() else {
      throw DecodeError.encodingFailed
    }
    return DecodeResult(bytes: png, sourceWidth: sourceWidth, sourceHeight: sourceHeight)
  }
}

private struct DecodeResult {
  let bytes: Data
  let sourceWidth: Int
  let sourceHeight: Int
}

private enum DecodeError: LocalizedError {
  case unsupportedFormat
  case encodingFailed

  var errorDescription: String? {
    switch self {
    case .unsupportedFormat:
      return "Unsupported image format"
    case .encodingFailed:
      return "Unable to encode decoded image"
    }
  }
}

private extension UIImage {
  func normalized() -> UIImage {
    if imageOrientation == .up {
      return self
    }
    UIGraphicsBeginImageContextWithOptions(size, false, scale)
    draw(in: CGRect(origin: .zero, size: size))
    let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return normalizedImage ?? self
  }
}

private extension UIImage.Orientation {
  init(cgImagePropertyOrientation: UInt32) {
    switch cgImagePropertyOrientation {
    case 2:
      self = .upMirrored
    case 3:
      self = .down
    case 4:
      self = .downMirrored
    case 5:
      self = .leftMirrored
    case 6:
      self = .right
    case 7:
      self = .rightMirrored
    case 8:
      self = .left
    default:
      self = .up
    }
  }
}
