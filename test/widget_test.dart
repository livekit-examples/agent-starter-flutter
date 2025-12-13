// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_assistant/app.dart';

void main() {
  testWidgets('App builds successfully', (WidgetTester tester) async {
    await dotenv.load(
      fileName: '.env',
      isOptional: true,
      mergeWith: const {
        'LIVEKIT_SANDBOX_ID': 'test',
      },
    );

    // Build our app and trigger a frame.
    await tester.pumpWidget(const VoiceAssistantApp());
    // Dispose resources started by the global controller to avoid pending timers.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      await appCtrl.cleanUp();
    });
  });
}
