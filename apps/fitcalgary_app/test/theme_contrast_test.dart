import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitcalgary_app/core/theme.dart';

double contrast(Color first, Color second) {
  final a = first.computeLuminance();
  final b = second.computeLuminance();
  return (math.max(a, b) + .05) / (math.min(a, b) + .05);
}

void main() {
  for (final dark in [false, true]) {
    test(
      '${dark ? 'Dark' : 'Light'} theme keeps small text and primary actions legible',
      () {
        final theme = dark ? fitDarkTheme() : fitTheme();
        final scheme = theme.colorScheme;
        final style = theme.filledButtonTheme.style!;
        final foreground = style.foregroundColor!.resolve({})!;
        final background = style.backgroundColor!.resolve({})!;
        expect(contrast(foreground, background), greaterThanOrEqualTo(4.5));
        expect(
          contrast(scheme.onSurfaceVariant, scheme.surface),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrast(scheme.onSurfaceVariant, theme.scaffoldBackgroundColor),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrast(scheme.primary, scheme.surface),
          greaterThanOrEqualTo(4.5),
        );
      },
    );
  }
}
