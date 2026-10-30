import 'package:flutter/widgets.dart';

abstract class AppRadius {
  AppRadius._();

  static const double xs = 6, sm = 9, md = 12, lg = 16;

  static const BorderRadius xsAll = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));

  static const BorderRadius sheet = BorderRadius.vertical(
    top: Radius.circular(lg),
  );
}
