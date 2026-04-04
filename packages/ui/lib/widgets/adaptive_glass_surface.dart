import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Glass-like surface that keeps blur on native but skips it on web.
///
/// Web still gets the same translucent container styling without the expensive
/// backdrop filter, which keeps the shell chrome responsive on weaker devices.
class AdaptiveGlassSurface extends StatelessWidget {
  final Widget child;
  final Decoration decoration;
  final double blurSigma;

  const AdaptiveGlassSurface({
    super.key,
    required this.child,
    required this.decoration,
    this.blurSigma = 24,
  });

  @override
  Widget build(BuildContext context) {
    final surface = Container(decoration: decoration, child: child);

    if (kIsWeb) {
      return surface;
    }

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: surface,
      ),
    );
  }
}
