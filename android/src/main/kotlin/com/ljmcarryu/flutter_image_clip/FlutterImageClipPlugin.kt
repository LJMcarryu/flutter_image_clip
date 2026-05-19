package com.ljmcarryu.flutter_image_clip

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageDecoder
import android.graphics.Matrix
import android.os.Build
import android.media.ExifInterface
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import kotlin.math.max
import kotlin.math.roundToInt

/** Android platform implementation for flutter_image_clip. */
class FlutterImageClipPlugin : FlutterPlugin, MethodCallHandler {
    private var channel: MethodChannel? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "flutter_image_clip/decode")
        channel?.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        if (call.method != "decode") {
            result.notImplemented()
            return
        }

        val bytes = call.argument<ByteArray>("bytes")
        if (bytes == null) {
            result.error("invalid_args", "Image bytes are required", null)
            return
        }

        try {
            val targetLongSide = call.argument<Int>("targetLongSide")
            val decoded = decodeImage(bytes, targetLongSide)
            result.success(
                mapOf(
                    "bytes" to decoded.bytes,
                    "sourceWidth" to decoded.sourceWidth,
                    "sourceHeight" to decoded.sourceHeight
                )
            )
        } catch (error: Throwable) {
            result.error("decode_failed", error.message ?: "Unable to decode image", null)
        }
    }

    private fun decodeImage(bytes: ByteArray, targetLongSide: Int?): DecodeResult {
        val orientation = readOrientation(bytes)
        val bitmap = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            decodeWithImageDecoder(bytes, targetLongSide)
        } else {
            decodeWithBitmapFactory(bytes, targetLongSide)
        } ?: throw IllegalArgumentException("Unsupported image format")

        val oriented = applyOrientation(bitmap, orientation)
        if (oriented !== bitmap) {
            bitmap.recycle()
        }

        val output = ByteArrayOutputStream()
        oriented.compress(Bitmap.CompressFormat.PNG, 100, output)
        val encoded = output.toByteArray()
        val sourceWidth = oriented.width
        val sourceHeight = oriented.height
        oriented.recycle()

        return DecodeResult(encoded, sourceWidth, sourceHeight)
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

    private data class DecodeResult(
        val bytes: ByteArray,
        val sourceWidth: Int,
        val sourceHeight: Int
    )
}
