import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as sdk;
import 'package:livekit_components/livekit_components.dart' as components;
import 'package:provider/provider.dart' show Selector, ChangeNotifierProvider;

import '../exts.dart';

class AgentParticipantSelector extends StatelessWidget {
  final Widget Function(BuildContext context, sdk.Participant? agentParticipant) builder;

  const AgentParticipantSelector({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext ctx) => Selector<components.RoomContext, sdk.Participant?>(
        selector: (context, roomCtx) => roomCtx.agentParticipant,
        builder: (context, agentParticipant, child) => ChangeNotifierProvider<components.ParticipantContext?>(
          key: ValueKey('AgentParticipantSelector-${agentParticipant?.sid}'),
          create: (context) => agentParticipant == null ? null : components.ParticipantContext(agentParticipant),
          child: builder(context, agentParticipant),
        ),
      );
}
