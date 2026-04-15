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
    // Cap decoded bitmap size so a large source PNG cannot freeze the UI on first paint.
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    final maxLogical = (width ?? height * 2).clamp(48.0, 240.0);
    final cachePx = (maxLogical * dpr).round().clamp(128, 512);

    return Image.asset(
      AppAssets.staffhubLogo,
      height: height,
      width: width,
      fit: fit,
      cacheWidth: cachePx,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'StaffHub',
    );
  }
}
