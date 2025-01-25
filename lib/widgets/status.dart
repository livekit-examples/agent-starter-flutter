import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:livekit_components/livekit_components.dart' hide ParticipantKind;
import 'package:provider/provider.dart';
import 'dart:math';

/// Shows a visualizer for the agent participant in the room
/// In a more complex app, you may want to show more information here
class StatusWidget extends StatefulWidget {
  const StatusWidget({
    super.key,
  });

  @override
  State<StatusWidget> createState() => _StatusWidgetState();
}

class _StatusWidgetState extends State<StatusWidget> {
  @override
  Widget build(BuildContext context) {
    return Consumer<RoomContext>(
      builder: (context, roomContext, child) {
        // Find the agent participant
        RemoteParticipant? agentParticipant = roomContext.room.remoteParticipants.values
            .where((p) => p.kind == ParticipantKind.AGENT)
            .firstOrNull;

        // If no agent participant yet, show nothing    
        if (agentParticipant == null) {
          return const SizedBox.shrink();
        }

        return ChangeNotifierProvider(
          create: (context) => ParticipantContext(agentParticipant),
          child: ParticipantAttributes(
            builder: (context, attributes) {
              final agentState = AgentState.fromString(
                attributes?['lk.agent.state'] ?? 'initializing'
              );

              final audioTrack = agentParticipant.audioTrackPublications.firstOrNull?.track as AudioTrack?;

              // If no audio track yet, show nothing
              if (audioTrack == null) {
                return const SizedBox.shrink();
              }

              return _AnimatedOpacityWidget(
                agentState: agentState,
                child: SoundWaveformWidget(
                  audioTrack: audioTrack,
                  options: AudioVisualizerOptions(
                    width: 32,
                    minHeight: 32,
                    maxHeight: 256,
                    color: Theme.of(context).colorScheme.primary,
                    count: 7,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

enum AgentState {
  initializing,
  speaking, 
  thinking,
  listening;

  static AgentState fromString(String value) {
    return AgentState.values.firstWhere(
      (state) => state.name == value,
      orElse: () => AgentState.initializing,
    );
  }
}

class _AnimatedOpacityWidget extends StatefulWidget {
  final AgentState agentState;
  final Widget child;

  const _AnimatedOpacityWidget({
    required this.agentState,
    required this.child,
  });

  @override
  State<_AnimatedOpacityWidget> createState() => _AnimatedOpacityWidgetState();
}

class _AnimatedOpacityWidgetState extends State<_AnimatedOpacityWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  Duration _getDuration() {
    switch (widget.agentState) {
      case AgentState.thinking:
        return const Duration(milliseconds: 500); // Faster animation for thinking
      default:
        return const Duration(milliseconds: 1000); // Default duration for other states
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _getDuration(),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_AnimatedOpacityWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.agentState != widget.agentState) {
      _controller.duration = _getDuration();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _getOpacity() {
    switch (widget.agentState) {
      case AgentState.initializing:
        return 0.3;
      case AgentState.speaking:
        return 1.0;
      case AgentState.thinking:
        return 0.3 + (0.5 * _controller.value);
      case AgentState.listening:
        return 0.3 + (0.5 * _controller.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Opacity(
        opacity: _getOpacity(),
        child: child,
      ),
      child: widget.child,
    );
  }
}
