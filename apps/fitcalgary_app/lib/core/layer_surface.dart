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
    final radius = BorderRadius.circular(floating ? (apple ? 24 : 18) : 12);
    final content = DecoratedBox(
      decoration: BoxDecoration(
        color: FitColors.white.withValues(alpha: translucent ? .92 : 1),
        borderRadius: radius,
        border: Border.all(
          color: media.highContrast
              ? FitColors.ink
              : FitColors.line.withValues(alpha: .65),
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
                    alpha: floating ? .12 : .055,
                  ),
                  blurRadius: floating ? 24 : 16,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: FitColors.black.withValues(alpha: .025),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: translucent
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: content,
              )
            : content,
      ),
    );
  }
}
