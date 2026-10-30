import 'package:flutter/material.dart';

import '../services/remote_content.dart';

Widget artImage(String ref, {BoxFit fit = BoxFit.contain}) =>
    ref.startsWith('file:')
    ? Image.file(
        RemoteContent.artFile(ref),
        fit: fit,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      )
    : Image.asset(ref, fit: fit);
