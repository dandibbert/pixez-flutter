import 'package:material_ui/material_ui.dart';

/// Motion tokens of the watercolor style: three durations and two curves.
abstract final class WcMotion {
  static const Duration short = Duration(milliseconds: 120);
  static const Duration medium = Duration(milliseconds: 240);
  static const Duration long = Duration(milliseconds: 360);

  /// Settles without overshoot.
  static const Curve standard = Cubic(0.2, 0, 0, 1);

  /// Overshoots a little, like pigment spreading past its edge and settling.
  static const Curve bounce = Cubic(0.3, 1.4, 0.5, 1);

  /// True when the system asks for reduced motion; animations then become
  /// plain fades.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}
