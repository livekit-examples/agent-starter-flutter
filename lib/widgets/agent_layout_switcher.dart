import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import 'control_bar.dart';

@immutable
class AgentLayoutState {
  final bool isTranscriptionVisible;
  final bool isCameraVisible;
  final bool isScreenshareVisible;

  const AgentLayoutState({
    this.isTranscriptionVisible = false,
    this.isCameraVisible = false,
    this.isScreenshareVisible = false,
  });
}

extension AgentLayoutStateCopyExt on AgentLayoutState {
  AgentLayoutState copyWith({
    bool? isTranscriptionVisible,
    bool? isCameraVisible,
    bool? isScreenshareVisible,
  }) {
    return AgentLayoutState(
      isTranscriptionVisible: isTranscriptionVisible ?? this.isTranscriptionVisible,
      isCameraVisible: isCameraVisible ?? this.isCameraVisible,
      isScreenshareVisible: isScreenshareVisible ?? this.isScreenshareVisible,
    );
  }
}

@immutable
class LayoutPosition {
  final double left;
  final double top;
  final double right;
  final double bottom;

  const LayoutPosition({
    this.left = 0.0,
    this.top = 0.0,
    this.right = 0.0,
    this.bottom = 0.0,
  });
}

class AgentLayoutSwitcher extends StatelessWidget {
  static final _logger = Logger('AgentLayoutSwitcher');

  final AgentLayoutState layoutState;

  final Widget Function(BuildContext ctx) transcriptionsBuilder;
  final Widget Function(BuildContext ctx) buildAgentView;
  final Widget Function(BuildContext ctx) buildCameraView;
  final Widget Function(BuildContext ctx) buildScreenShareView;

  final Duration animationDuration;
  final Curve animationCurve;

  const AgentLayoutSwitcher({
    super.key,
    required this.layoutState,
    // this.isFullVisualizer = true,
    // this.isCamViewEnabled = false,
    // this.isScreenShareViewEnabled = false,
    this.animationDuration = const Duration(milliseconds: 500),
    this.animationCurve = Curves.easeInOutSine,
    required this.transcriptionsBuilder,
    required this.buildAgentView,
    required this.buildCameraView,
    required this.buildScreenShareView,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (ctx, constraints) {
        // Compute positions...
        const double horizontalPadding = 10;
        const double cellSpacing = 5;

        final double topPadding = MediaQuery.of(ctx).viewPadding.top;
        final double bottomPadding = 90 + MediaQuery.of(ctx).viewPadding.bottom;

        final double singleCellWidth = constraints.maxWidth * 0.3;
        final double singleCellHeight = constraints.maxHeight * 0.2;

        _logger.fine('Cell width: $singleCellWidth x $singleCellHeight');

        final double cellBottom = (constraints.maxHeight - singleCellHeight - topPadding);

        int cellCountCamAndScreen = 0;
        if (layoutState.isCameraVisible) cellCountCamAndScreen += 1;
        if (layoutState.isScreenshareVisible) cellCountCamAndScreen += 1;

        int cellCountCam = 0;
        if (layoutState.isCameraVisible) cellCountCam += 1;

        final agentViewPosition = LayoutPosition(
          left: layoutState.isTranscriptionVisible ? horizontalPadding : 0.0,
          top: layoutState.isTranscriptionVisible ? topPadding : 0.0,
          right: layoutState.isTranscriptionVisible
              ? (singleCellWidth * cellCountCamAndScreen) + (cellSpacing * cellCountCamAndScreen) + horizontalPadding
              : 0.0,
          bottom: layoutState.isTranscriptionVisible ? cellBottom : 0.0,
        );

        final cameraViewPosition = LayoutPosition(
          left: constraints.maxWidth - singleCellWidth - horizontalPadding,
          top: layoutState.isTranscriptionVisible
              ? topPadding
              : constraints.maxHeight - (singleCellHeight + bottomPadding),
          right: horizontalPadding,
          bottom: layoutState.isTranscriptionVisible ? cellBottom : bottomPadding,
        );

        final screenshareViewPosition = LayoutPosition(
          left: constraints.maxWidth -
              (singleCellWidth * (cellCountCam + 1)) -
              (cellSpacing * cellCountCam) -
              horizontalPadding,
          top: layoutState.isTranscriptionVisible
              ? topPadding
              : constraints.maxHeight - (singleCellHeight + bottomPadding),
          right: ((singleCellWidth + cellSpacing) * cellCountCam) + horizontalPadding,
          bottom: layoutState.isTranscriptionVisible ? cellBottom : bottomPadding,
        );

        return Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(
                  top: singleCellHeight + topPadding,
                  bottom: 110,
                ),
                child: transcriptionsBuilder(context),
              ),
            ),
            // Overlay for transcriptions
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: layoutState.isTranscriptionVisible ? 0.0 : 1.0,
                  duration: animationDuration,
                  curve: animationCurve,
                  child: Container(
                    color: Theme.of(ctx).canvasColor,
                  ),
                ),
              ),
            ),
            // AgentView
            AnimatedPositioned(
              duration: animationDuration,
              curve: animationCurve,
              left: agentViewPosition.left,
              top: agentViewPosition.top,
              right: agentViewPosition.right,
              bottom: agentViewPosition.bottom,
              child: buildAgentView(ctx),
            ),
            // CameraView
            AnimatedPositioned(
              duration: animationDuration,
              curve: animationCurve,
              left: cameraViewPosition.left,
              top: cameraViewPosition.top,
              right: cameraViewPosition.right,
              bottom: cameraViewPosition.bottom,
              child: AnimatedOpacity(
                opacity: layoutState.isCameraVisible ? 1.0 : 0.0,
                duration: animationDuration,
                curve: animationCurve,
                child: buildCameraView(ctx),
              ),
            ),
            // ScreenshareView
            AnimatedPositioned(
              duration: animationDuration,
              curve: animationCurve,
              left: screenshareViewPosition.left,
              top: screenshareViewPosition.top,
              right: screenshareViewPosition.right,
              bottom: screenshareViewPosition.bottom,
              child: AnimatedOpacity(
                opacity: layoutState.isScreenshareVisible ? 1.0 : 0.0,
                duration: animationDuration,
                curve: animationCurve,
                child: buildScreenShareView(ctx),
              ),
            ),
            // Control bar
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  bottom: max(20, MediaQuery.of(ctx).viewPadding.bottom),
                ),
                child: const ControlBar(),
              ),
            ),
          ],
        );
      });
}
