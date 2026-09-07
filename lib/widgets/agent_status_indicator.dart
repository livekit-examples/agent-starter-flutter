import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as sdk;
import 'package:provider/provider.dart';

/// Shows the agent connection status while a session is active:
/// "Waiting for agent" until an agent participant has joined and is ready,
/// then "Agent is listening". Hidden when there is no active session or the
/// agent has failed (the session error banner covers that case).
class AgentStatusIndicator extends StatelessWidget {
  const AgentStatusIndicator({super.key, this.hideWhenConnected = false});

  /// Hides the indicator once the agent is connected instead of showing
  /// "Agent is listening".
  final bool hideWhenConnected;

  @override
  Widget build(BuildContext context) => Consumer<sdk.Session>(
    builder: (context, session, child) {
      final agent = session.agent;
      final bool isListening = agent.isConnected;
      final bool isWaiting = agent.isPending || agent.isBuffering;
      final bool visible = isWaiting || (isListening && !hideWhenConnected);
      final Color color = isListening ? Colors.green : Theme.of(context).colorScheme.outline;

      return IgnorePointer(
        child: AnimatedOpacity(
          opacity: visible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: isListening
                      ? const Icon(Icons.mic, color: Colors.green, size: 18)
                      : isWaiting
                      ? Center(
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: color),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Text(
                  isListening ? 'Agent is listening' : 'Waiting for agent',
                  style: TextStyle(color: color, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
