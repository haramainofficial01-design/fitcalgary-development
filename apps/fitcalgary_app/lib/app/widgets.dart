import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';

class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key, this.showActions = true});
  final bool showActions;
  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: Container(
      height: 74,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: FitColors.ink)),
      ),
      child: Row(
        children: [
          const Text(
            'FITCALGARY',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              letterSpacing: -.6,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'INDEX',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 9,
              letterSpacing: 2.4,
              color: FitColors.muted,
            ),
          ),
          const Spacer(),
          if (showActions)
            FilledButton(
              onPressed: () => context.push('/submit'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              child: const Text('POST A RESULT'),
            ),
        ],
      ),
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
      color: light ? const Color(0xFFE07A69) : FitColors.coralDark,
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
    decoration: BoxDecoration(border: Border.all(color: FitColors.line)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(body, style: const TextStyle(color: FitColors.muted, height: 1.5)),
      ],
    ),
  );
}
