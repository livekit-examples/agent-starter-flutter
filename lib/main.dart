import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app.dart';

// Load environment variables before starting the app
// This is used to configure the LiveKit sandbox ID for development
// The file is optional; without it the app connects to a default agent (see app_ctrl.dart)
void main() async {
  await dotenv.load(fileName: 'assets/.env', isOptional: true);
  runApp(const VoiceAssistantApp());
}
