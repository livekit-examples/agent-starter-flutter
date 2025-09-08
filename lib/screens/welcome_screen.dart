import 'package:flutter/gestures.dart' show TapGestureRecognizer;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart' show launchUrl;
import 'package:voice_assistant/controllers/app_ctrl.dart' as ctrl;
import 'package:voice_assistant/widgets/button.dart' as buttons;

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext ctx) => Material(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 30,
              children: [
                Image.asset(
                  'assets/terminal.png',
                  width: 80,
                  height: 80,
                  color: Theme.brightnessOf(ctx) == Brightness.light ? Colors.black : Colors.white,
                ),
                Text.rich(
                  textAlign: TextAlign.center,
                  TextSpan(
                    children: [
                      const TextSpan(
                        text: 'Start a call to chat with your voice agent. Need help getting set up? Check out the ',
                      ),
                      TextSpan(
                        text: 'Voice AI quickstart',
                        style: const TextStyle(
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.blue,
                          decorationThickness: 1,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            launchUrl(Uri.parse('https://docs.livekit.io/agents/start/voice-ai/'));
                          },
                      ),
                      const TextSpan(
                        text: '.',
                      ),
                    ],
                  ),
                ),
                // Agent listening indicator
                Consumer<ctrl.AppCtrl>(
                  builder: (ctx, appCtrl, child) => AnimatedOpacity(
                    opacity: appCtrl.isAgentListening ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.mic,
                            color: Colors.green,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Agent is listening',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Builder(
                  builder: (ctx) {
                    final isProgressing = [
                      ctrl.ConnectionState.connecting,
                      ctrl.ConnectionState.connected,
                    ].contains(ctx.watch<ctrl.AppCtrl>().connectionState);
                    return buttons.Button(
                      text: isProgressing ? 'Connecting' : 'Start call',
                      isProgressing: isProgressing,
                      onPressed: () => ctx.read<ctrl.AppCtrl>().connect(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
}
