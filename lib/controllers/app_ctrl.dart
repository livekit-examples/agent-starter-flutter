import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:livekit_client/livekit_client.dart' as sdk;
import 'package:livekit_components/livekit_components.dart' as components;
import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';

import '../services/token_service.dart';

enum AppScreenState { welcome, agent }

enum AgentScreenState { visualizer, transcription }

enum ConnectionState { disconnected, connecting, connected }

class AppCtrl extends ChangeNotifier {
  static const uuid = Uuid();

  // States
  AppScreenState appScreenState = AppScreenState.welcome;
  ConnectionState connectionState = ConnectionState.disconnected;
  AgentScreenState agentScreenState = AgentScreenState.visualizer;

  //Test
  bool isUserCameEnabled = false;
  bool isScreenshareEnabled = false;

  final messageCtrl = TextEditingController();
  final messageFocusNode = FocusNode();

  late final sdk.Room room = sdk.Room(roomOptions: const sdk.RoomOptions(enableVisualizer: true));
  late final roomContext = components.RoomContext(room: room);

  final tokenService = TokenService();

  bool isSendButtonEnabled = false;

  AppCtrl() {
    final format = DateFormat('HH:mm:ss');
    // configure logs for debugging
    Logger.root.level = Level.FINE;
    Logger.root.onRecord.listen((record) {
      print('${format.format(record.time)}: ${record.message}');
    });

    messageCtrl.addListener(() {
      final newValue = messageCtrl.text.isNotEmpty;
      if (newValue != isSendButtonEnabled) {
        isSendButtonEnabled = newValue;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    messageCtrl.dispose();
    super.dispose();
  }

  void sendMessage() async {
    isSendButtonEnabled = false;

    final text = messageCtrl.text;
    messageCtrl.clear();
    notifyListeners();

    final lp = room.localParticipant;
    if (lp == null) return;

    final nowUtc = DateTime.now().toUtc();
    final segment = sdk.TranscriptionSegment(
        id: uuid.v4(), text: text, firstReceivedTime: nowUtc, lastReceivedTime: nowUtc, isFinal: true, language: 'en');
    roomContext.insertTranscription(components.TranscriptionForParticipant(segment, lp));

    await lp.sendText(text, options: sdk.SendTextOptions(topic: 'lk.chat'));
  }

  void toggleUserCamera(components.MediaDeviceContext? deviceCtx) {
    isUserCameEnabled = !isUserCameEnabled;
    isUserCameEnabled ? deviceCtx?.enableCamera() : deviceCtx?.disableCamera();
    notifyListeners();
  }

  void toggleScreenShare() {
    isScreenshareEnabled = !isScreenshareEnabled;
    notifyListeners();
  }

  void toggleAgentScreenMode() {
    agentScreenState =
        agentScreenState == AgentScreenState.visualizer ? AgentScreenState.transcription : AgentScreenState.visualizer;
    notifyListeners();
  }

  void connect() async {
    print("Connect....");
    connectionState = ConnectionState.connecting;
    notifyListeners();

    try {
      print("Starting pre-connect audio...");

      await room.withPreConnectAudio(() async {
        print("Pre-connect audio started...");

        // Generate random room and participant names
        // In a real app, you'd likely use meaningful names
        final roomName = 'room-${(1000 + DateTime.now().millisecondsSinceEpoch % 9000)}';
        final participantName = 'user-${(1000 + DateTime.now().millisecondsSinceEpoch % 9000)}';

        // Get connection details from token service
        final connectionDetails = await tokenService.fetchConnectionDetails(
          roomName: roomName,
          participantName: participantName,
        );

        print("Fetched Connection Details: $connectionDetails, connecting to room...");

        await room.connect(
          connectionDetails.serverUrl,
          connectionDetails.participantToken,
        );

        print("Connected to room");

        await room.localParticipant?.setMicrophoneEnabled(true);

        print("Microphone enabled");
      });
      connectionState = ConnectionState.connected;
      appScreenState = AppScreenState.agent;
      notifyListeners();
    } catch (error) {
      print('Connection error: $error');

      connectionState = ConnectionState.disconnected;
      appScreenState = AppScreenState.welcome;
      notifyListeners();
    }
  }

  void disconnect() {
    room.disconnect();

    // Update states
    connectionState = ConnectionState.disconnected;
    appScreenState = AppScreenState.welcome;
    agentScreenState = AgentScreenState.visualizer;

    notifyListeners();
  }
}
