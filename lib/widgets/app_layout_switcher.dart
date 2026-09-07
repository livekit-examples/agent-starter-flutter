import 'package:flutter/material.dart';

class AppLayoutSwitcher extends StatelessWidget {
  final bool isFront;
  final Widget Function(BuildContext context) frontBuilder;
  final Widget Function(BuildContext context) backBuilder;

  final Duration animationDuration;
  final Curve animationCurve;

  const AppLayoutSwitcher({
    super.key,
    this.isFront = true,
    this.animationDuration = const Duration(milliseconds: 500),
    this.animationCurve = Curves.easeInOutSine,
    required this.frontBuilder,
    required this.backBuilder,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            ignoring: isFront,
            child: AnimatedOpacity(
              opacity: isFront ? 0.0 : 1.0,
              duration: animationDuration,
              curve: animationCurve,
              child: backBuilder(context),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !isFront,
            child: AnimatedOpacity(
              opacity: isFront ? 1.0 : 0.0,
              duration: animationDuration,
              curve: animationCurve,
              child: frontBuilder(context),
            ),
          ),
        ),
      ],
    ),
  );
}
