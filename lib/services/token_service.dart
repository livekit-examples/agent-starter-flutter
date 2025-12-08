import 'dart:math';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:livekit_client/livekit_client.dart' as sdk;

/// Data class representing the connection details needed to join a LiveKit room
/// This includes the server URL, room name, participant info, and auth token
class ConnectionDetails {
  final String serverUrl;
  final String roomName;
  final String participantName;
  final String participantToken;

  ConnectionDetails({
    required this.serverUrl,
    required this.roomName,
    required this.participantName,
    required this.participantToken,
  });

  factory ConnectionDetails.fromJson(Map<String, dynamic> json) {
    return ConnectionDetails(
      serverUrl: json['serverUrl'],
      roomName: json['roomName'],
      participantName: json['participantName'],
      participantToken: json['participantToken'],
    );
  }
}

/// An example service for fetching LiveKit authentication tokens
///
/// To use the LiveKit Cloud sandbox (development only)
/// - Enable your sandbox here https://cloud.livekit.io/projects/p_/sandbox/templates/token-server
/// - Create .env file with your LIVEKIT_SANDBOX_ID
///
/// To use a hardcoded token (development only)
/// - Generate a token: https://docs.livekit.io/home/cli/cli-setup/#generate-access-token
/// - Set `hardcodedServerUrl` and `hardcodedToken` below
///
/// To use your own server (production applications)
/// - Add a token endpoint to your server with a LiveKit Server SDK https://docs.livekit.io/home/server/generating-tokens/
/// - Modify or replace this class as needed to connect to your new token server
/// - Rejoice in your new production-ready LiveKit application!
///
/// See https://docs.livekit.io/home/get-started/authentication for more information
class TokenService {
  // For hardcoded token usage (development only)
  final String? hardcodedServerUrl = null;
  final String? hardcodedToken = null;

  // Get the sandbox ID from environment variables
  String? get sandboxId {
    final value = dotenv.env['LIVEKIT_SANDBOX_ID'];
    if (value != null) {
      // Remove unwanted double quotes if present
      return value.replaceAll('"', '');
    }
    return null;
  }

  ConnectionDetails? fetchHardcodedConnectionDetails({
    required String roomName,
    required String participantName,
  }) {
    if (hardcodedServerUrl == null || hardcodedToken == null) {
      return null;
    }

    return ConnectionDetails(
      serverUrl: hardcodedServerUrl!,
      roomName: roomName,
      participantName: participantName,
      participantToken: hardcodedToken!,
    );
  }
}

/// Bridges [TokenService] to the LiveKit Session API by implementing [TokenSourceConfigurable].
class TokenServiceTokenSource implements sdk.TokenSourceConfigurable {
  TokenServiceTokenSource(this._service);

  final TokenService _service;
  final Random _random = Random();

  @override
  Future<sdk.TokenSourceResponse> fetch(sdk.TokenRequestOptions options) async {
    final roomName = options.roomName ?? _randomRoomName();
    final participantName = options.participantName ?? _randomParticipantName();

    // If hardcoded creds are provided (development only), return them as-is.
    final hardcoded = _service.fetchHardcodedConnectionDetails(
      roomName: roomName,
      participantName: participantName,
    );
    if (hardcoded != null) {
      return sdk.TokenSourceResponse(
        serverUrl: hardcoded.serverUrl,
        participantToken: hardcoded.participantToken,
        participantName: hardcoded.participantName,
        roomName: hardcoded.roomName,
      );
    }

    final sandboxId = _service.sandboxId;
    if (sandboxId == null) {
      throw Exception('Sandbox ID is not set and no hardcoded token is configured.');
    }

    final resolvedOptions = sdk.TokenRequestOptions(
      roomName: roomName,
      participantName: participantName,
      participantIdentity: options.participantIdentity,
      participantMetadata: options.participantMetadata,
      participantAttributes: options.participantAttributes,
      agentName: options.agentName,
      agentMetadata: options.agentMetadata,
    );

    // Use the SDK’s sandbox token source so agent dispatch options (agent name/metadata)
    // are forwarded correctly to the token server.
    final source = sdk.SandboxTokenSource(sandboxId: sandboxId);
    return await source.fetch(resolvedOptions);
  }

  String _randomRoomName() => 'room-${1000 + _random.nextInt(9000)}';
  String _randomParticipantName() => 'user-${1000 + _random.nextInt(9000)}';
}
