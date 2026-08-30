import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/widgets.dart';
import '../../core/theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [
      const SliverToBoxAdapter(child: BrandHeader()),
      SliverToBoxAdapter(
        child: Container(
          color: FitColors.black,
          padding: const EdgeInsets.fromLTRB(24, 62, 24, 54),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Overline('Calgary · Community verified', light: true),
              const SizedBox(height: 30),
              const Text(
                'The city,\nranked.',
                style: TextStyle(
                  color: FitColors.white,
                  fontSize: 64,
                  height: .92,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -4,
                ),
              ),
              const SizedBox(height: 26),
              const Text(
                'Find the real cost of membership. Post a mark. Every result is reviewed against a published standard before it lands.',
                style: TextStyle(
                  color: Color(0xFFD5D4CF),
                  fontSize: 18,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => context.push('/submit'),
                      child: const Text('POST A RESULT →'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => context.go('/gyms'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: FitColors.white),
                        foregroundColor: FitColors.white,
                      ),
                      child: const Text('BROWSE GYMS →'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 46),
              const _Pillars(),
            ],
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 34),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Overline('The real number'),
              const SizedBox(height: 18),
              const Text(
                'Compare the all-in.',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -2,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Biweekly means 26 payments each year. Mandatory fees stay visible and incomplete pricing stays honest.',
                style: TextStyle(height: 1.55, color: FitColors.muted),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go('/gyms'),
                child: const Text('OPEN THE GYM INDEX →'),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _Pillars extends StatelessWidget {
  const _Pillars();
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      border: Border(
        top: BorderSide(color: Color(0xFF505154)),
        left: BorderSide(color: Color(0xFF505154)),
      ),
    ),
    child: const Column(
      children: [
        _Pillar('01', 'DISCOVER', 'Gyms, clubs and events'),
        _Pillar('02', 'COMPARE', 'Transparent normalized pricing'),
        _Pillar('03', 'COMPETE', 'Trusted local leaderboards'),
      ],
    ),
  );
}

class _Pillar extends StatelessWidget {
  const _Pillar(this.number, this.title, this.body);
  final String number, title, body;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: const BoxDecoration(
      border: Border(
        right: BorderSide(color: Color(0xFF505154)),
        bottom: BorderSide(color: Color(0xFF505154)),
      ),
    ),
    child: Row(
      children: [
        SizedBox(
          width: 42,
          child: Text(
            number,
            style: const TextStyle(color: Color(0xFFE07A69), fontSize: 10),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: FitColors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                body,
                style: const TextStyle(color: Color(0xFF92938F), fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
