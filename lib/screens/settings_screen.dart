import 'package:flutter/material.dart';
import 'package:flutter_embed_unity/flutter_embed_unity.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: 200, width: 200, child: EmbedUnity()),
            ElevatedButton(
              onPressed: () {
                // Call the method to send a message to Unity
                sendToUnity(
                  'AppManager',
                  'ReceiveSentenceFromFlutter',
                  'السلام',
                );
              },
              child: const Text('Send Message to Unity'),
            ),
          ],
        ),
      ),
    );
  }
}
