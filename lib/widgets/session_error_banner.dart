import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as sdk;
import 'package:provider/provider.dart';

/// Displays the latest session or agent error as a small banner.
class SessionErrorBanner extends StatelessWidget {
  const SessionErrorBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<sdk.Session>(
      builder: (context, session, _) {
        final sdk.SessionError? sessionError = session.error;
        final sdk.AgentFailure? agentError = session.agent.error;

        final String? message = sessionError?.message ?? agentError?.message;
        if (message == null) {
          return const SizedBox.shrink();
        }

        Future<void> handleDismiss() async {
          if (sessionError != null) {
            session.dismissError();
          } else {
            await session.end();
          }
        }

        return SafeArea(
          minimum: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                color: Colors.red.withValues(alpha: 0.9),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.white),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          message,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      IconButton(
                        onPressed: handleDismiss,
                        icon: const Icon(Icons.close, color: Colors.white),
                        tooltip: 'Dismiss',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
