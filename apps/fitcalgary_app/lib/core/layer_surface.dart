import 'dart:ui';

import 'package:flutter/material.dart';

import 'theme.dart';

/// A restrained material surface, not a replacement for native platform APIs.
/// Blur is limited to floating Apple controls; content surfaces remain opaque.
class FitLayerSurface extends StatelessWidget {
  const FitLayerSurface({
    required this.child,
    this.floating = false,
    super.key,
  });
  final Widget child;
  final bool floating;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final apple =
        Theme.of(context).platform == TargetPlatform.iOS ||
        Theme.of(context).platform == TargetPlatform.macOS;
    final translucent =
        floating &&
        apple &&
        !media.highContrast &&
        !media.accessibleNavigation &&
        !media.disableAnimations;
    final radius = BorderRadius.circular(floating ? (apple ? 28 : 22) : 18);
    final content = DecoratedBox(
      decoration: BoxDecoration(
        color: context.fitSurface.withValues(alpha: translucent ? .78 : 1),
        borderRadius: radius,
        border: Border.all(
          color: media.highContrast
              ? context.fitInk
              : (Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: floating ? .18 : .12)
                    : Colors.white.withValues(alpha: floating ? .85 : .65)),
        ),
      ),
      child: child,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: media.highContrast
            ? []
            : [
                BoxShadow(
                  color: FitColors.black.withValues(
                    alpha: floating ? .14 : .06,
                  ),
                  blurRadius: floating ? 32 : 18,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: FitColors.black.withValues(alpha: .09),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: translucent
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: content,
              )
            : content,
      ),
    );
  }
}
