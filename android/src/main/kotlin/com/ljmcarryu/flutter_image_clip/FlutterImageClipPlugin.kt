package com.ljmcarryu.flutter_image_clip

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageDecoder
import android.graphics.Matrix
import android.media.ExifInterface
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.File
import java.nio.ByteBuffer
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import kotlin.math.max
import kotlin.math.roundToInt

/** Android platform implementation for flutter_image_clip. */
class FlutterImageClipPlugin : FlutterPlugin, MethodCallHandler {
    private var channel: MethodChannel? = null
    private var decodeExecutor: ExecutorService = newDecodeExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        if (decodeExecutor.isShutdown) {
            decodeExecutor = newDecodeExecutor()
        }
        channel = MethodChannel(binding.binaryMessenger, "flutter_image_clip/decode")
        channel?.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        decodeExecutor.shutdownNow()
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "decode" -> handleDecode(call, result)
            "cropFile" -> handleCropFile(call, result)
            else -> result.notImplemented()
        }
    }

    private fun handleDecode(call: MethodCall, result: Result) {
        val bytes = call.argument<ByteArray>("bytes")
        val path = call.argument<String>("path")
        if (bytes == null && path.isNullOrBlank()) {
            result.error("invalid_args", "Image bytes or file path are required", null)
            return
        }

        val targetLongSide = call.argument<Int>("targetLongSide")
        decodeExecutor.execute {
            try {
                val decoded = if (!path.isNullOrBlank()) {
                    decodeImageFile(path, targetLongSide)
                } else {
                    decodeImage(bytes!!, targetLongSide)
                }
                mainHandler.post {
                    result.success(
                        mapOf(
                            "bytes" to decoded.bytes,
                            "sourceWidth" to decoded.sourceWidth,
                            "sourceHeight" to decoded.sourceHeight
                        )
                    )
                }
            } catch (error: UnsupportedImageFormatException) {
                mainHandler.post {
                    result.error("unsupported_format", error.message ?: "Unsupported image format", null)
                }
            } catch (error: IllegalArgumentException) {
                mainHandler.post {
                    result.error("invalid_args", error.message ?: "Invalid decode arguments", null)
                }
            } catch (error: Throwable) {
                mainHandler.post {
                    result.error("decode_failed", error.message ?: "Unable to decode image", null)
                }
            }
        }
    }

    private fun handleCropFile(call: MethodCall, result: Result) {
        val path = call.argument<String>("path")
        if (path.isNullOrBlank()) {
            result.error("invalid_args", "Image file path is required", null)
            return
        }
        val regionMap = call.argument<Map<String, Any?>>("region")
        val transformMap = call.argument<Map<String, Any?>>("transform") ?: emptyMap()
        val outputMap = call.argument<Map<String, Any?>>("output") ?: emptyMap()
        val processingMap = call.argument<Map<String, Any?>>("processing") ?: emptyMap()
        if (regionMap == null) {
            result.error("invalid_args", "Crop region is required", null)
            return
        }

        val region = CropRect(
            x = intValue(regionMap["x"], 0),
            y = intValue(regionMap["y"], 0),
            width = intValue(regionMap["width"], 0),
            height = intValue(regionMap["height"], 0)
        )
        if (region.width <= 0 || region.height <= 0) {
            result.error("invalid_args", "Crop region width and height must be greater than zero", null)
            return
        }
        val transform = CropTransform(
            rotationDegrees = normalizeRotation(intValue(transformMap["rotationDegrees"], 0)),
            flipHorizontal = boolValue(transformMap["flipHorizontal"], false),
            flipVertical = boolValue(transformMap["flipVertical"], false)
        )
        val output = OutputSettings(
            format = stringValue(outputMap["format"], "png"),
            jpegQuality = intValue(outputMap["jpegQuality"], 90).coerceIn(1, 100)
        )
        val processing = ProcessingSettings(
            maxInputPixels = positiveIntValue(processingMap["maxInputPixels"]),
            maxOutputPixels = positiveIntValue(processingMap["maxOutputPixels"]),
            autoDownscale = boolValue(processingMap["autoDownscale"], true)
        )

        decodeExecutor.execute {
            try {
                val cropped = cropImageFile(path, region, transform, output, processing)
                mainHandler.post {
                    result.success(
                        mapOf(
                            "bytes" to cropped.bytes,
                            "width" to cropped.width,
                            "height" to cropped.height,
                            "format" to cropped.format,
                            "sourceWidth" to cropped.sourceWidth,
                            "sourceHeight" to cropped.sourceHeight
                        )
                    )
                }
            } catch (error: ImageTooLargeException) {
                mainHandler.post {
                    result.error(
                        "image_too_large",
                        error.message ?: "Image is too large",
                        mapOf(
                            "width" to error.width,
                            "height" to error.height,
                            "maxPixels" to error.maxPixels
                        )
                    )
                }
            } catch (error: UnsupportedImageFormatException) {
                mainHandler.post {
                    result.error("unsupported_format", error.message ?: "Unsupported image format", null)
                }
            } catch (error: IllegalArgumentException) {
                mainHandler.post {
                    result.error("invalid_args", error.message ?: "Invalid crop arguments", null)
                }
            } catch (error: Throwable) {
                mainHandler.post {
                    result.error("decode_failed", error.message ?: "Unable to process image", null)
                }
            }
        }
    }

    private fun decodeImage(bytes: ByteArray, targetLongSide: Int?): DecodeResult {
        val orientation = readOrientation(bytes)
        val sourceSize = readSourceSize(bytes, orientation)
        val bitmap = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            decodeWithImageDecoder(bytes, targetLongSide)
        } else {
            decodeWithBitmapFactory(bytes, targetLongSide)
        } ?: throw UnsupportedImageFormatException("Unsupported image format")

        val oriented = applyOrientation(bitmap, orientation)
        if (oriented !== bitmap) {
            bitmap.recycle()
        }

        val encoded = encodePreviewBitmap(oriented)
        val sourceWidth = sourceSize?.first ?: oriented.width
        val sourceHeight = sourceSize?.second ?: oriented.height
        oriented.recycle()

        return DecodeResult(encoded, sourceWidth, sourceHeight)
    }

    private fun decodeImageFile(path: String, targetLongSide: Int?): DecodeResult {
        val file = File(path)
        if (!file.exists() || !file.isFile) {
            throw IllegalArgumentException("Image file does not exist")
        }

        val orientation = readOrientation(path)
        val sourceSize = readSourceSize(path, orientation)
        val bitmap = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            decodeWithImageDecoder(file, targetLongSide)
        } else {
            decodeWithBitmapFactory(path, targetLongSide)
        } ?: throw UnsupportedImageFormatException("Unsupported image format")

        val oriented = applyOrientation(bitmap, orientation)
        if (oriented !== bitmap) {
            bitmap.recycle()
        }

        val encoded = encodePreviewBitmap(oriented)
        val sourceWidth = sourceSize?.first ?: oriented.width
        val sourceHeight = sourceSize?.second ?: oriented.height
        oriented.recycle()

        return DecodeResult(encoded, sourceWidth, sourceHeight)
    }

    private fun cropImageFile(
        path: String,
        region: CropRect,
        transform: CropTransform,
        output: OutputSettings,
        processing: ProcessingSettings
    ): CropFileResult {
        val file = File(path)
        if (!file.exists() || !file.isFile) {
            throw IllegalArgumentException("Image file does not exist")
        }

        val orientation = readOrientation(path)
        val sourceSize = readSourceSize(path, orientation)
        if (sourceSize != null) {
            checkPixelLimit(sourceSize.first, sourceSize.second, processing.maxInputPixels)
        }
        val bitmap = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            decodeWithImageDecoder(file, null)
        } else {
            decodeWithBitmapFactory(path, null)
        } ?: throw UnsupportedImageFormatException("Unsupported image format")

        val oriented = applyOrientation(bitmap, orientation)
        if (oriented !== bitmap) {
            bitmap.recycle()
        }
        checkPixelLimit(oriented.width, oriented.height, processing.maxInputPixels)

        val orientedWidth = oriented.width
        val orientedHeight = oriented.height
        val safeRegion = region.clampTo(orientedWidth, orientedHeight)
        var current = Bitmap.createBitmap(
            oriented,
            safeRegion.x,
            safeRegion.y,
            safeRegion.width,
            safeRegion.height
        )
        oriented.recycle()

        current = applyCropTransform(current, transform)

        val prepared = prepareOutputBitmap(current, processing)
        if (prepared !== current) {
            current.recycle()
        }

        val encoded = encodeOutputBitmap(prepared, output)
        val width = prepared.width
        val height = prepared.height
        val sourceWidth = sourceSize?.first ?: orientedWidth
        val sourceHeight = sourceSize?.second ?: orientedHeight
        prepared.recycle()

        return CropFileResult(
            bytes = encoded,
            width = width,
            height = height,
            format = output.safeFormat,
            sourceWidth = sourceWidth,
            sourceHeight = sourceHeight
        )
    }

    private fun readSourceSize(bytes: ByteArray, orientation: Int): Pair<Int, Int>? {
        val bounds = BitmapFactory.Options().apply {
            inJustDecodeBounds = true
        }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) {
            return null
        }
        val swapsAxes = orientation == ExifInterface.ORIENTATION_TRANSPOSE ||
            orientation == ExifInterface.ORIENTATION_ROTATE_90 ||
            orientation == ExifInterface.ORIENTATION_TRANSVERSE ||
            orientation == ExifInterface.ORIENTATION_ROTATE_270
        return if (swapsAxes) {
            Pair(bounds.outHeight, bounds.outWidth)
        } else {
            Pair(bounds.outWidth, bounds.outHeight)
        }
    }

    private fun readSourceSize(path: String, orientation: Int): Pair<Int, Int>? {
        val bounds = BitmapFactory.Options().apply {
            inJustDecodeBounds = true
        }
        BitmapFactory.decodeFile(path, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) {
            return null
        }
        val swapsAxes = orientation == ExifInterface.ORIENTATION_TRANSPOSE ||
            orientation == ExifInterface.ORIENTATION_ROTATE_90 ||
            orientation == ExifInterface.ORIENTATION_TRANSVERSE ||
            orientation == ExifInterface.ORIENTATION_ROTATE_270
        return if (swapsAxes) {
            Pair(bounds.outHeight, bounds.outWidth)
        } else {
            Pair(bounds.outWidth, bounds.outHeight)
        }
    }

    private fun decodeWithImageDecoder(bytes: ByteArray, targetLongSide: Int?): Bitmap? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
            return null
        }
        val source = ImageDecoder.createSource(ByteBuffer.wrap(bytes))
        return ImageDecoder.decodeBitmap(source) { decoder, info, _ ->
            decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
            val target = targetLongSide
            if (target != null && target > 0) {
                val width = info.size.width
                val height = info.size.height
                val longSide = max(width, height)
                if (longSide > target) {
                    val scale = target.toDouble() / longSide.toDouble()
                    decoder.setTargetSize(
                        max(1, (width * scale).roundToInt()),
                        max(1, (height * scale).roundToInt())
                    )
                }
            }
        }
    }

    private fun decodeWithImageDecoder(file: File, targetLongSide: Int?): Bitmap? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
            return null
        }
        val source = ImageDecoder.createSource(file)
        return ImageDecoder.decodeBitmap(source) { decoder, info, _ ->
            decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
            val target = targetLongSide
            if (target != null && target > 0) {
                val width = info.size.width
                val height = info.size.height
                val longSide = max(width, height)
                if (longSide > target) {
                    val scale = target.toDouble() / longSide.toDouble()
                    decoder.setTargetSize(
                        max(1, (width * scale).roundToInt()),
                        max(1, (height * scale).roundToInt())
                    )
                }
            }
        }
    }

    private fun decodeWithBitmapFactory(bytes: ByteArray, targetLongSide: Int?): Bitmap? {
        val bounds = BitmapFactory.Options().apply {
            inJustDecodeBounds = true
        }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) {
            return null
        }

        val options = BitmapFactory.Options().apply {
            inPreferredConfig = Bitmap.Config.ARGB_8888
            inSampleSize = sampleSize(bounds.outWidth, bounds.outHeight, targetLongSide)
        }
        return BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options)
    }

    private fun decodeWithBitmapFactory(path: String, targetLongSide: Int?): Bitmap? {
        val bounds = BitmapFactory.Options().apply {
            inJustDecodeBounds = true
        }
        BitmapFactory.decodeFile(path, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) {
            return null
        }

        val options = BitmapFactory.Options().apply {
            inPreferredConfig = Bitmap.Config.ARGB_8888
            inSampleSize = sampleSize(bounds.outWidth, bounds.outHeight, targetLongSide)
        }
        return BitmapFactory.decodeFile(path, options)
    }

    private fun sampleSize(width: Int, height: Int, targetLongSide: Int?): Int {
        val target = targetLongSide ?: return 1
        if (target <= 0) {
            return 1
        }
        val longSide = max(width, height)
        var sample = 1
        while (longSide / (sample * 2) >= target) {
            sample *= 2
        }
        return sample
    }

    private fun readOrientation(bytes: ByteArray): Int {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
            return ExifInterface.ORIENTATION_NORMAL
        }
        return try {
            ExifInterface(ByteArrayInputStream(bytes)).getAttributeInt(
                ExifInterface.TAG_ORIENTATION,
                ExifInterface.ORIENTATION_NORMAL
            )
        } catch (_: Throwable) {
            ExifInterface.ORIENTATION_NORMAL
        }
    }

    private fun readOrientation(path: String): Int {
        return try {
            ExifInterface(path).getAttributeInt(
                ExifInterface.TAG_ORIENTATION,
                ExifInterface.ORIENTATION_NORMAL
            )
        } catch (_: Throwable) {
            ExifInterface.ORIENTATION_NORMAL
        }
    }

    private fun applyOrientation(bitmap: Bitmap, orientation: Int): Bitmap {
        val matrix = Matrix()
        when (orientation) {
            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> matrix.postScale(-1f, 1f)
            ExifInterface.ORIENTATION_ROTATE_180 -> matrix.postRotate(180f)
            ExifInterface.ORIENTATION_FLIP_VERTICAL -> matrix.postScale(1f, -1f)
            ExifInterface.ORIENTATION_TRANSPOSE -> {
                matrix.postRotate(90f)
                matrix.postScale(-1f, 1f)
            }
            ExifInterface.ORIENTATION_ROTATE_90 -> matrix.postRotate(90f)
            ExifInterface.ORIENTATION_TRANSVERSE -> {
                matrix.postRotate(270f)
                matrix.postScale(-1f, 1f)
            }
            ExifInterface.ORIENTATION_ROTATE_270 -> matrix.postRotate(270f)
            else -> return bitmap
        }
        return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
    }

    private fun encodePreviewBitmap(bitmap: Bitmap): ByteArray {
        val output = ByteArrayOutputStream()
        val format = if (bitmap.hasAlpha()) {
            Bitmap.CompressFormat.PNG
        } else {
            Bitmap.CompressFormat.JPEG
        }
        val quality = if (format == Bitmap.CompressFormat.JPEG) 90 else 100
        bitmap.compress(format, quality, output)
        return output.toByteArray()
    }

    private fun applyCropTransform(bitmap: Bitmap, transform: CropTransform): Bitmap {
        var current = bitmap
        if (transform.rotationDegrees != 0) {
            val rotated = transformBitmap(current) {
                postRotate(transform.rotationDegrees.toFloat())
            }
            if (rotated !== current) {
                current.recycle()
            }
            current = rotated
        }
        if (transform.flipHorizontal || transform.flipVertical) {
            val flipped = transformBitmap(current) {
                postScale(
                    if (transform.flipHorizontal) -1f else 1f,
                    if (transform.flipVertical) -1f else 1f
                )
            }
            if (flipped !== current) {
                current.recycle()
            }
            current = flipped
        }
        return current
    }

    private fun transformBitmap(bitmap: Bitmap, configure: Matrix.() -> Unit): Bitmap {
        val matrix = Matrix().apply(configure)
        return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
    }

    private fun prepareOutputBitmap(bitmap: Bitmap, processing: ProcessingSettings): Bitmap {
        val maxPixels = processing.maxOutputPixels ?: return bitmap
        val pixels = bitmap.width.toLong() * bitmap.height.toLong()
        if (pixels <= maxPixels.toLong()) {
            return bitmap
        }
        if (!processing.autoDownscale) {
            throw ImageTooLargeException(bitmap.width, bitmap.height, maxPixels)
        }
        val scale = kotlin.math.sqrt(maxPixels.toDouble() / pixels.toDouble())
        return Bitmap.createScaledBitmap(
            bitmap,
            max(1, (bitmap.width * scale).toInt()),
            max(1, (bitmap.height * scale).toInt()),
            true
        )
    }

    private fun encodeOutputBitmap(bitmap: Bitmap, output: OutputSettings): ByteArray {
        val bytes = ByteArrayOutputStream()
        val format = if (output.safeFormat == "jpeg") {
            Bitmap.CompressFormat.JPEG
        } else {
            Bitmap.CompressFormat.PNG
        }
        val quality = if (format == Bitmap.CompressFormat.JPEG) output.jpegQuality else 100
        if (!bitmap.compress(format, quality, bytes)) {
            throw IllegalStateException("Unable to encode image")
        }
        return bytes.toByteArray()
    }

    private fun checkPixelLimit(width: Int, height: Int, maxPixels: Int?) {
        if (maxPixels == null) {
            return
        }
        val pixels = width.toLong() * height.toLong()
        if (pixels > maxPixels.toLong()) {
            throw ImageTooLargeException(width, height, maxPixels)
        }
    }

    private fun normalizeRotation(degrees: Int): Int {
        val normalized = degrees % 360
        return if (normalized < 0) normalized + 360 else normalized
    }

    private fun intValue(value: Any?, fallback: Int): Int {
        return when (value) {
            is Int -> value
            is Long -> value.toInt()
            is Number -> value.toInt()
            else -> fallback
        }
    }

    private fun positiveIntValue(value: Any?): Int? {
        val parsed = intValue(value, 0)
        return if (parsed > 0) parsed else null
    }

    private fun boolValue(value: Any?, fallback: Boolean): Boolean {
        return if (value is Boolean) value else fallback
    }

    private fun stringValue(value: Any?, fallback: String): String {
        return if (value is String) value else fallback
    }

    private data class CropRect(
        val x: Int,
        val y: Int,
        val width: Int,
        val height: Int
    ) {
        fun clampTo(sourceWidth: Int, sourceHeight: Int): CropRect {
            val safeX = x.coerceIn(0, sourceWidth - 1)
            val safeY = y.coerceIn(0, sourceHeight - 1)
            return CropRect(
                x = safeX,
                y = safeY,
                width = width.coerceIn(1, sourceWidth - safeX),
                height = height.coerceIn(1, sourceHeight - safeY)
            )
        }
    }

    private data class CropTransform(
        val rotationDegrees: Int,
        val flipHorizontal: Boolean,
        val flipVertical: Boolean
    )

    private data class OutputSettings(
        val format: String,
        val jpegQuality: Int
    ) {
        val safeFormat: String
            get() = if (format == "jpeg") "jpeg" else "png"
    }

    private data class ProcessingSettings(
        val maxInputPixels: Int?,
        val maxOutputPixels: Int?,
        val autoDownscale: Boolean
    )

    private data class DecodeResult(
        val bytes: ByteArray,
        val sourceWidth: Int,
        val sourceHeight: Int
    )

    private data class CropFileResult(
        val bytes: ByteArray,
        val width: Int,
        val height: Int,
        val format: String,
        val sourceWidth: Int,
        val sourceHeight: Int
    )

    private class UnsupportedImageFormatException(message: String) : Exception(message)

    private class ImageTooLargeException(
        val width: Int,
        val height: Int,
        val maxPixels: Int
    ) : Exception(
        "Image has ${width.toLong() * height.toLong()} pixels, which exceeds the configured limit of $maxPixels pixels"
    )

    private fun newDecodeExecutor(): ExecutorService {
        return Executors.newSingleThreadExecutor()
    }
}
