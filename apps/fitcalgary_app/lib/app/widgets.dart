import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';

class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key, this.showActions = true});
  final bool showActions;
  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 440;
        final largeText = MediaQuery.textScalerOf(context).scale(12) > 18;
        final branding = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'FITCALGARY',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: -.6,
                ),
              ),
            ),
            Text(
              'INDEX',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 8,
                letterSpacing: 2.4,
                color: context.fitMuted,
              ),
            ),
          ],
        );
        final actions = Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            OutlinedButton(
              onPressed: () => context.push('/signin'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 9),
                textStyle: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: const Text('SIGN IN'),
            ),
            FilledButton(
              onPressed: () => context.push('/submit'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 9),
                textStyle: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: Text(compact ? 'POST RESULT' : 'POST A RESULT'),
            ),
          ],
        );
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 20,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: context.fitInk)),
          ),
          child: largeText && showActions
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [branding, const SizedBox(height: 12), actions],
                )
              : Row(
                  children: [
                    Expanded(child: branding),
                    if (showActions) ...[const SizedBox(width: 10), actions],
                  ],
                ),
        );
      },
    ),
  );
}

class Overline extends StatelessWidget {
  const Overline(this.text, {super.key, this.light = false});
  final String text;
  final bool light;
  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w800,
      letterSpacing: 2,
      color: light
          ? const Color(0xFFE07A69)
          : Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFF08A79)
          : FitColors.coralDark,
    ),
  );
}

class ErrorPanel extends StatelessWidget {
  const ErrorPanel({required this.message, required this.onRetry, super.key});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.cloud_off_outlined, size: 32),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 14),
        OutlinedButton(onPressed: onRetry, child: const Text('TRY AGAIN')),
      ],
    ),
  );
}

class EmptyPanel extends StatelessWidget {
  const EmptyPanel({required this.title, required this.body, super.key});
  final String title, body;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(border: Border.all(color: context.fitLine)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(body, style: TextStyle(color: context.fitMuted, height: 1.5)),
      ],
    ),
  );
}
