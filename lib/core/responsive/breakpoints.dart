import 'package:flutter/widgets.dart';

enum ScreenSize { phone, tablet, desktop }

abstract final class Breakpoints {
  static const double tablet = 600;
  static const double desktop = 1024;

  static ScreenSize of(double width) => width >= desktop
      ? ScreenSize.desktop
      : width >= tablet
          ? ScreenSize.tablet
          : ScreenSize.phone;

  static ScreenSize ofContext(BuildContext c) => of(MediaQuery.sizeOf(c).width);

  /// Responsive column count for card grids.
  static int columns(double width) => width >= 1280
      ? 4
      : width >= desktop
          ? 3
          : width >= tablet
              ? 2
              : 1;
}
