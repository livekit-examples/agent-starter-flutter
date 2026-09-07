import 'package:flutter/material.dart';

import '../ui/color_pallette.dart';

class CameraToggleButton extends StatelessWidget {
  final GestureTapCallback? onTap;
  final bool isEnabled;

  const CameraToggleButton({
    super.key,
    this.isEnabled = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext ctx) => ClipOval(
    child: Material(
      color: LKColorPaletteDark().bg2,
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        child: const Padding(
          padding: EdgeInsets.symmetric(
            vertical: 10,
            horizontal: 10,
          ),
          child: Icon(
            Icons.refresh,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    ),
  );
}
