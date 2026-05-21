import Flutter
import UIKit
import ImageIO
import MobileCoreServices

public class FlutterImageClipPlugin: NSObject, FlutterPlugin {
  private let decodeQueue = DispatchQueue(
    label: "flutter_image_clip.decode",
    qos: .userInitiated
  )

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "flutter_image_clip/decode",
      binaryMessenger: registrar.messenger()
    )
    let instance = FlutterImageClipPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "decode":
      handleDecode(call, result: result)
    case "cropFile":
      handleCropFile(call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func handleDecode(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let arguments = call.arguments as? [String: Any] else {
      result(FlutterError(code: "invalid_args", message: "Image bytes or file path are required", details: nil))
      return
    }

    let data = (arguments["bytes"] as? FlutterStandardTypedData)?.data
    let path = (arguments["path"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    guard data != nil || path?.isEmpty == false else {
      result(FlutterError(code: "invalid_args", message: "Image bytes or file path are required", details: nil))
      return
    }

    let targetLongSide = arguments["targetLongSide"] as? Int
    decodeQueue.async { [self] in
      do {
        let decoded: DecodeResult
        if let data {
          decoded = try decodeImage(data: data, targetLongSide: targetLongSide)
        } else {
          decoded = try decodeImage(path: path!, targetLongSide: targetLongSide)
        }
        DispatchQueue.main.async {
          result([
            "bytes": FlutterStandardTypedData(bytes: decoded.bytes),
            "sourceWidth": decoded.sourceWidth,
            "sourceHeight": decoded.sourceHeight,
          ])
        }
      } catch DecodeError.unsupportedFormat {
        DispatchQueue.main.async {
          result(FlutterError(code: "unsupported_format", message: DecodeError.unsupportedFormat.localizedDescription, details: nil))
        }
      } catch DecodeError.encodingFailed {
        DispatchQueue.main.async {
          result(FlutterError(code: "encode_failed", message: DecodeError.encodingFailed.localizedDescription, details: nil))
        }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "decode_failed", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  private func handleCropFile(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let arguments = call.arguments as? [String: Any],
      let path = (arguments["path"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
      !path.isEmpty
    else {
      result(FlutterError(code: "invalid_args", message: "Image file path is required", details: nil))
      return
    }
    guard let regionMap = arguments["region"] as? [String: Any] else {
      result(FlutterError(code: "invalid_args", message: "Crop region is required", details: nil))
      return
    }

    let transformMap = arguments["transform"] as? [String: Any] ?? [:]
    let outputMap = arguments["output"] as? [String: Any] ?? [:]
    let processingMap = arguments["processing"] as? [String: Any] ?? [:]
    let region = CropRect(
      x: intValue(regionMap["x"], fallback: 0),
      y: intValue(regionMap["y"], fallback: 0),
      width: intValue(regionMap["width"], fallback: 0),
      height: intValue(regionMap["height"], fallback: 0)
    )
    guard region.width > 0 && region.height > 0 else {
      result(FlutterError(code: "invalid_args", message: "Crop region width and height must be greater than zero", details: nil))
      return
    }

    let transform = CropTransform(
      rotationDegrees: normalizeRotation(intValue(transformMap["rotationDegrees"], fallback: 0)),
      flipHorizontal: boolValue(transformMap["flipHorizontal"], fallback: false),
      flipVertical: boolValue(transformMap["flipVertical"], fallback: false)
    )
    let output = OutputSettings(
      format: stringValue(outputMap["format"], fallback: "png"),
      jpegQuality: min(100, max(1, intValue(outputMap["jpegQuality"], fallback: 90)))
    )
    let processing = ProcessingSettings(
      maxInputPixels: positiveIntValue(processingMap["maxInputPixels"]),
      maxOutputPixels: positiveIntValue(processingMap["maxOutputPixels"]),
      autoDownscale: boolValue(processingMap["autoDownscale"], fallback: true)
    )

    decodeQueue.async { [self] in
      do {
        let cropped = try cropImage(
          path: path,
          region: region,
          transform: transform,
          output: output,
          processing: processing
        )
        DispatchQueue.main.async {
          result([
            "bytes": FlutterStandardTypedData(bytes: cropped.bytes),
            "width": cropped.width,
            "height": cropped.height,
            "format": cropped.format,
            "sourceWidth": cropped.sourceWidth,
            "sourceHeight": cropped.sourceHeight,
          ])
        }
      } catch DecodeError.imageTooLarge(let width, let height, let maxPixels) {
        DispatchQueue.main.async {
          result(FlutterError(
            code: "image_too_large",
            message: DecodeError.imageTooLarge(width: width, height: height, maxPixels: maxPixels).localizedDescription,
            details: ["width": width, "height": height, "maxPixels": maxPixels]
          ))
        }
      } catch DecodeError.invalidArguments(let message) {
        DispatchQueue.main.async {
          result(FlutterError(code: "invalid_args", message: message, details: nil))
        }
      } catch DecodeError.unsupportedFormat {
        DispatchQueue.main.async {
          result(FlutterError(code: "unsupported_format", message: DecodeError.unsupportedFormat.localizedDescription, details: nil))
        }
      } catch DecodeError.encodingFailed {
        DispatchQueue.main.async {
          result(FlutterError(code: "encode_failed", message: DecodeError.encodingFailed.localizedDescription, details: nil))
        }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "decode_failed", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  private func decodeImage(data: Data, targetLongSide: Int?) throws -> DecodeResult {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
      throw DecodeError.unsupportedFormat
    }
    return try decodeImage(source: source, targetLongSide: targetLongSide)
  }

  private func decodeImage(path: String, targetLongSide: Int?) throws -> DecodeResult {
    let url = URL(fileURLWithPath: path)
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
      throw DecodeError.unsupportedFormat
    }
    return try decodeImage(source: source, targetLongSide: targetLongSide)
  }

  private func decodeImage(source: CGImageSource, targetLongSide: Int?) throws -> DecodeResult {
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

    guard let encoded = encodePreviewImage(image) else {
      throw DecodeError.encodingFailed
    }
    return DecodeResult(bytes: encoded, sourceWidth: sourceWidth, sourceHeight: sourceHeight)
  }

  private func cropImage(
    path: String,
    region: CropRect,
    transform: CropTransform,
    output: OutputSettings,
    processing: ProcessingSettings
  ) throws -> CropFileResult {
    let url = URL(fileURLWithPath: path)
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
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
    try checkPixelLimit(width: sourceWidth, height: sourceHeight, maxPixels: processing.maxInputPixels)

    guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
      throw DecodeError.unsupportedFormat
    }
    let orientation = UIImage.Orientation(cgImagePropertyOrientation: orientationValue)
    let normalized = UIImage(cgImage: cgImage, scale: 1, orientation: orientation).normalized()
    guard let normalizedCgImage = normalized.cgImage else {
      throw DecodeError.unsupportedFormat
    }
    try checkPixelLimit(width: normalizedCgImage.width, height: normalizedCgImage.height, maxPixels: processing.maxInputPixels)

    let safeRegion = region.clamped(sourceWidth: normalizedCgImage.width, sourceHeight: normalizedCgImage.height)
    let cropRect = CGRect(x: safeRegion.x, y: safeRegion.y, width: safeRegion.width, height: safeRegion.height)
    guard let croppedCgImage = normalizedCgImage.cropping(to: cropRect) else {
      throw DecodeError.invalidArguments("Crop region is outside image bounds")
    }
    var image = UIImage(cgImage: croppedCgImage, scale: 1, orientation: .up)
    image = image.rotated(clockwiseDegrees: transform.rotationDegrees)
    image = image.flipped(horizontal: transform.flipHorizontal, vertical: transform.flipVertical)
    image = try image.preparedForOutput(processing: processing)

    guard let data = encodeOutputImage(image, output: output), let outputCgImage = image.cgImage else {
      throw DecodeError.encodingFailed
    }
    return CropFileResult(
      bytes: data,
      width: outputCgImage.width,
      height: outputCgImage.height,
      format: output.safeFormat,
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight
    )
  }

  private func encodePreviewImage(_ image: UIImage) -> Data? {
    if image.hasAlpha {
      return image.pngData()
    }
    return image.jpegData(compressionQuality: 0.9)
  }

  private func encodeOutputImage(_ image: UIImage, output: OutputSettings) -> Data? {
    if output.safeFormat == "jpeg" {
      return image.jpegData(compressionQuality: CGFloat(output.jpegQuality) / 100)
    }
    return image.pngData()
  }

  private func checkPixelLimit(width: Int, height: Int, maxPixels: Int?) throws {
    guard let maxPixels else {
      return
    }
    if width * height > maxPixels {
      throw DecodeError.imageTooLarge(width: width, height: height, maxPixels: maxPixels)
    }
  }
}

private struct DecodeResult {
  let bytes: Data
  let sourceWidth: Int
  let sourceHeight: Int
}

private struct CropFileResult {
  let bytes: Data
  let width: Int
  let height: Int
  let format: String
  let sourceWidth: Int
  let sourceHeight: Int
}

private struct CropRect {
  let x: Int
  let y: Int
  let width: Int
  let height: Int

  func clamped(sourceWidth: Int, sourceHeight: Int) -> CropRect {
    let safeX = min(max(0, x), sourceWidth - 1)
    let safeY = min(max(0, y), sourceHeight - 1)
    return CropRect(
      x: safeX,
      y: safeY,
      width: min(max(1, width), sourceWidth - safeX),
      height: min(max(1, height), sourceHeight - safeY)
    )
  }
}

private struct CropTransform {
  let rotationDegrees: Int
  let flipHorizontal: Bool
  let flipVertical: Bool
}

private struct OutputSettings {
  let format: String
  let jpegQuality: Int

  var safeFormat: String {
    format == "jpeg" ? "jpeg" : "png"
  }
}

private struct ProcessingSettings {
  let maxInputPixels: Int?
  let maxOutputPixels: Int?
  let autoDownscale: Bool
}

private enum DecodeError: LocalizedError {
  case unsupportedFormat
  case encodingFailed
  case invalidArguments(String)
  case imageTooLarge(width: Int, height: Int, maxPixels: Int)

  var errorDescription: String? {
    switch self {
    case .unsupportedFormat:
      return "Unsupported image format"
    case .encodingFailed:
      return "Unable to encode decoded image"
    case .invalidArguments(let message):
      return message
    case .imageTooLarge(let width, let height, let maxPixels):
      return "Image has \(width * height) pixels, which exceeds the configured limit of \(maxPixels) pixels"
    }
  }
}

private func normalizeRotation(_ degrees: Int) -> Int {
  let normalized = degrees % 360
  return normalized < 0 ? normalized + 360 : normalized
}

private func intValue(_ value: Any?, fallback: Int) -> Int {
  if let value = value as? Int {
    return value
  }
  if let value = value as? NSNumber {
    return value.intValue
  }
  return fallback
}

private func positiveIntValue(_ value: Any?) -> Int? {
  let parsed = intValue(value, fallback: 0)
  return parsed > 0 ? parsed : nil
}

private func boolValue(_ value: Any?, fallback: Bool) -> Bool {
  if let value = value as? Bool {
    return value
  }
  return fallback
}

private func stringValue(_ value: Any?, fallback: String) -> String {
  if let value = value as? String {
    return value
  }
  return fallback
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

  var hasAlpha: Bool {
    guard let alphaInfo = cgImage?.alphaInfo else {
      return false
    }
    switch alphaInfo {
    case .first, .last, .premultipliedFirst, .premultipliedLast:
      return true
    default:
      return false
    }
  }

  func rotated(clockwiseDegrees degrees: Int) -> UIImage {
    let normalizedDegrees = normalizeRotation(degrees)
    if normalizedDegrees == 0 {
      return self
    }
    let swapsAxes = normalizedDegrees == 90 || normalizedDegrees == 270
    let outputSize = CGSize(
      width: swapsAxes ? size.height : size.width,
      height: swapsAxes ? size.width : size.height
    )
    let radians = CGFloat(normalizedDegrees) * .pi / 180
    let renderer = UIGraphicsImageRenderer.pixelRenderer(size: outputSize)
    return renderer.image { context in
      let cgContext = context.cgContext
      cgContext.translateBy(x: outputSize.width / 2, y: outputSize.height / 2)
      cgContext.rotate(by: radians)
      draw(in: CGRect(
        x: -size.width / 2,
        y: -size.height / 2,
        width: size.width,
        height: size.height
      ))
    }
  }

  func flipped(horizontal: Bool, vertical: Bool) -> UIImage {
    if !horizontal && !vertical {
      return self
    }
    let renderer = UIGraphicsImageRenderer.pixelRenderer(size: size)
    return renderer.image { context in
      let cgContext = context.cgContext
      cgContext.translateBy(
        x: horizontal ? size.width : 0,
        y: vertical ? size.height : 0
      )
      cgContext.scaleBy(x: horizontal ? -1 : 1, y: vertical ? -1 : 1)
      draw(in: CGRect(origin: .zero, size: size))
    }
  }

  func preparedForOutput(processing: ProcessingSettings) throws -> UIImage {
    guard let maxPixels = processing.maxOutputPixels, let cgImage else {
      return self
    }
    let pixels = cgImage.width * cgImage.height
    if pixels <= maxPixels {
      return self
    }
    if !processing.autoDownscale {
      throw DecodeError.imageTooLarge(
        width: cgImage.width,
        height: cgImage.height,
        maxPixels: maxPixels
      )
    }
    let scale = sqrt(CGFloat(maxPixels) / CGFloat(pixels))
    let outputSize = CGSize(
      width: max(CGFloat(1), floor(size.width * scale)),
      height: max(CGFloat(1), floor(size.height * scale))
    )
    let renderer = UIGraphicsImageRenderer.pixelRenderer(size: outputSize)
    return renderer.image { _ in
      draw(in: CGRect(origin: .zero, size: outputSize))
    }
  }
}

private extension UIGraphicsImageRenderer {
  static func pixelRenderer(size: CGSize) -> UIGraphicsImageRenderer {
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = 1
    return UIGraphicsImageRenderer(size: size, format: format)
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
