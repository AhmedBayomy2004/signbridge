import 'package:flutter/services.dart';

class TFLiteService {
  static const _channel = MethodChannel('com.yourapp/tflite');

  static Future<void> loadModel({required bool isVideo}) async {
    await _channel.invokeMethod(
      isVideo ? 'loadVideoModel' : 'loadPictureModel',
    );
  }

  static Future<List<double>> runVideoInference(
    List<List<List<double>>> input, // 3D: [1][20][126]
  ) async {
    try {
      final result = await _channel.invokeMethod('runVideoInference', {
        'input': input,
      });
      return List<double>.from(result ?? []);
    } catch (e) {
      print("runVideoInference error: $e");
      return [];
    }
  }

  static Future<List<double>> runPictureInference(
    List<List<double>> input, // 2D: [1][63]
  ) async {
    try {
      final result = await _channel.invokeMethod('runPictureInference', {
        'input': input,
      });
      return List<double>.from(result ?? []);
    } catch (e) {
      print("runPictureInference error: $e");
      return [];
    }
  }
}