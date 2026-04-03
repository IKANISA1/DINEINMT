import 'package:flutter/widgets.dart';

bool reduceMotionOf(BuildContext context) {
  final mediaQuery = MediaQuery.maybeOf(context);
  return mediaQuery?.disableAnimations ?? false;
}
