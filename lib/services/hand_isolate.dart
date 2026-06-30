/*import 'dart:isolate';
import 'package:camera/camera.dart';
import 'package:hand_landmarker/hand_landmarker.dart';

/// Message sent from main isolate to background isolate
class FrameRequest {
  final CameraImage image;
  final int sensorOrientation;
  final SendPort replyPort; // one-shot reply port per frame

  const FrameRequest(this.image, this.sensorOrientation, this.replyPort);
}

/// The entry point that runs inside the background isolate.
/// [mainSendPort] is used to hand back *our* ReceivePort so main can send frames.
void handIsolateEntry(List<dynamic> args) {
  // args = [SendPort mainSendPort, bool isVideo]
  // Create the plugin once — it lives here for the isolate's lifetime.
  SendPort mainSendPort = args[0];
  bool isVideo = args[1];
  final plugin = HandLandmarkerPlugin.create(
    numHands: isVideo ? 2 : 1, // picture model only takes 1 hand
    minHandDetectionConfidence: 0.7,
    delegate: HandLandmarkerDelegate.gpu,
  );

  final receivePort = ReceivePort();

  // Send our port back so the main isolate knows where to deliver frames.
  mainSendPort.send(receivePort.sendPort);

  receivePort.listen((message) {
    if (message is FrameRequest) {
      try {
        final hands = plugin.detect(message.image, message.sensorOrientation);
        message.replyPort.send(hands);
      } catch (e) {
        message.replyPort.send(<Hand>[]); // send empty on error
      }
    } else if (message == 'dispose') {
      plugin.dispose();
      receivePort.close();
    }
  });
}
*/