import 'package:flutter/material.dart';
import '../app_assets.dart';

/// StaffHub branded logo (PNG on dark navy background).
class StaffHubLogo extends StatelessWidget {
  const StaffHubLogo({
    super.key,
    this.height = 120,
    this.width,
    this.fit = BoxFit.contain,
  });

  final double height;
  final double? width;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppAssets.staffhubLogo,
      height: height,
      width: width,
      fit: fit,
      semanticLabel: 'StaffHub',
    );
  }
}
