import 'dart:math' as math;

import 'package:flutter/widgets.dart';

abstract final class AppLayout {
  static const guestTabletBreakpoint = 720.0;
  static const guestRailBreakpoint = 1180.0;
  static const opsRailBreakpoint = 1180.0;

  static double guestContentMaxWidth(double screenWidth) {
    if (screenWidth >= guestRailBreakpoint) return 1360;
    if (screenWidth >= guestTabletBreakpoint) return 960;
    return screenWidth;
  }

  static double opsContentMaxWidth(double screenWidth) {
    if (screenWidth >= 1600) return 1480;
    if (screenWidth >= guestTabletBreakpoint) return 1180;
    return screenWidth;
  }

  static double guestRailWidth(double screenWidth) {
    return math.max(288, math.min(336, screenWidth * 0.24));
  }

  static double opsRailWidth(double screenWidth) {
    return math.max(292, math.min(344, screenWidth * 0.23));
  }

  static EdgeInsets contentPadding(double screenWidth) {
    if (screenWidth >= guestRailBreakpoint) {
      return const EdgeInsets.symmetric(horizontal: 32);
    }
    if (screenWidth >= guestTabletBreakpoint) {
      return const EdgeInsets.symmetric(horizontal: 24);
    }
    return EdgeInsets.zero;
  }
}
