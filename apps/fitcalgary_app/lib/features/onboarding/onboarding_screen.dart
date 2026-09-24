import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    required this.onExplore,
    required this.onAccount,
    super.key,
  });

  final Future<void> Function() onExplore;
  final VoidCallback onAccount;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final controller = PageController();
  int page = 0;
  bool finishing = false;

  static const pages = [
    (
      eyebrow: 'CALGARY · VIDEO-VERIFIED',
      title: 'The city,\nranked.',
      body: 'Explore Calgary fitness, compare real costs, and see verified local performance in one place.',
      icon: Icons.stacked_bar_chart_rounded,
    ),
    (
      eyebrow: 'THE REAL NUMBER',
      title: 'Know what\nyou pay.',
      body: 'Compare advertised rates. All-in costs appear when mandatory fees are confirmed.',
      icon: Icons.price_check_rounded,
    ),
    (
      eyebrow: 'YOUR MARK',
      title: 'Ready to\nmake a mark?',
      body: 'Browse without an account. Sign in when you are ready to save gyms, post a result, or manage your profile.',
      icon: Icons.play_circle_fill_rounded,
    ),
  ];

  Future<void> next() async {
    if (page < pages.length - 1) {
      await controller.nextPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> back() async {
    if (page > 0) {
      await controller.previousPage(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> explore() async {
    setState(() => finishing = true);
    await widget.onExplore();
    if (mounted) setState(() => finishing = false);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = page == pages.length - 1;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: FitColors.ink,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'FITCALGARY',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.6,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'INDEX',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.5,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${page + 1} / ${pages.length}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    Expanded(
                      child: PageView.builder(
                        controller: controller,
                        itemCount: pages.length,
                        onPageChanged: (value) => setState(() => page = value),
                        itemBuilder: (context, index) {
                          final item = pages[index];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 92,
                                height: 92,
                                decoration: BoxDecoration(
                                  color: FitColors.coral,
                                  borderRadius: BorderRadius.circular(28),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x443B0F09),
                                      blurRadius: 30,
                                      offset: Offset(0, 14),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  item.icon,
                                  color: Colors.white,
                                  size: 42,
                                ),
                              ),
                              const SizedBox(height: 34),
                              Text(
                                item.eyebrow,
                                style: const TextStyle(
                                  color: FitColors.coral,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2.1,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                item.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 54,
                                  height: 0.94,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -3.4,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                item.body,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.74),
                                  fontSize: 17,
                                  height: 1.55,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: last
                          ? Column(
                              key: const ValueKey('actions'),
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                FilledButton(
                                  onPressed: finishing
                                      ? null
                                      : widget.onAccount,
                                  child: const Text(
                                    'CREATE ACCOUNT OR SIGN IN →',
                                  ),
                                ),
                                const SizedBox(height: 10),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: BorderSide(
                                      color: Colors.white.withValues(
                                        alpha: 0.42,
                                      ),
                                    ),
                                  ),
                                  onPressed: finishing ? null : explore,
                                  child: Text(
                                    finishing
                                        ? 'OPENING…'
                                        : 'EXPLORE FITCALGARY',
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              key: const ValueKey('navigation'),
                              children: [
                                if (page > 0)
                                  TextButton(
                                    onPressed: back,
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('BACK'),
                                  )
                                else
                                  const SizedBox(width: 70),
                                const Spacer(),
                                FilledButton(
                                  onPressed: next,
                                  child: const Text('NEXT →'),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
