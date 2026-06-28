package com.example.signbride

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.tensorflow.lite.Interpreter
import java.io.FileInputStream
import java.nio.MappedByteBuffer
import java.nio.channels.FileChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.yourapp/tflite"
    private var interpreter: Interpreter? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->

                when (call.method) {

                    "loadVideoModel" -> {
                        try {
                            loadVideoModel()
                            result.success("Video model loaded")
                        } catch (e: Exception) {
                            result.error("LOAD_ERROR", e.message, null)
                        }
                    }

                    "loadPictureModel" -> {
                        try {
                            loadPictureModel()
                            result.success("Picture model loaded")
                        } catch (e: Exception) {
                            result.error("LOAD_ERROR", e.message, null)
                        }
                    }

                    "runVideoInference" -> {
                        try {
                            val input = call.argument<List<List<List<Double>>>>("input")!!
                            result.success(runVideoInference(input))
                        } catch (e: Exception) {
                            result.error("INFERENCE_ERROR", e.message, null)
                        }
                    }

                    "runPictureInference" -> {
                        try {
                            val input = call.argument<List<List<Double>>>("input")!!
                            result.success(runPictureInference(input))
                        } catch (e: Exception) {
                            result.error("INFERENCE_ERROR", e.message, null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun loadVideoModel() {
        val options = Interpreter.Options().apply {
            setNumThreads(4)
        }
        val model = loadModelFile(this, "video_model.tflite")
        interpreter = Interpreter(model, options)
    }

    private fun loadPictureModel() {
        val options = Interpreter.Options().apply {
            setNumThreads(4) 
        }
        val model = loadModelFile(this, "picture_model.tflite")
        interpreter = Interpreter(model, options)
    }

    private fun loadModelFile(context: Context, modelName: String): MappedByteBuffer {
        val fileDescriptor = context.assets.openFd("model/$modelName")
        val inputStream = FileInputStream(fileDescriptor.fileDescriptor)
        val fileChannel = inputStream.channel
        return fileChannel.map(
            FileChannel.MapMode.READ_ONLY,
            fileDescriptor.startOffset,
            fileDescriptor.declaredLength
        )
    }

    private fun runVideoInference(input: List<List<List<Double>>>): List<Double> {
        val inputArray = Array(1) {
            Array(20) { i ->
                FloatArray(126) { j ->
                    input[0][i][j].toFloat()
                }
            }
        }
        val outputArray = Array(1) { FloatArray(18) }
        interpreter!!.run(inputArray, outputArray)
        return outputArray[0].map { it.toDouble() }
    }

    private fun runPictureInference(input: List<List<Double>>): List<Double> {
        val inputArray = Array(1) {
            FloatArray(63) { i ->
                input[0][i].toFloat()
            }
        }
        val outputArray = Array(1) { FloatArray(31) }
        interpreter!!.run(inputArray, outputArray)
        return outputArray[0].map { it.toDouble() }
    }

    override fun onDestroy() {
        interpreter?.close()
        super.onDestroy()
    }
}