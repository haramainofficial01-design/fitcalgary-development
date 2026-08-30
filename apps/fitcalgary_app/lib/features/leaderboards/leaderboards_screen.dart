import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/widgets.dart';
import '../../core/theme.dart';

class LeaderboardsScreen extends ConsumerWidget {
  const LeaderboardsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final disciplines = ref.watch(disciplinesProvider);
    return Scaffold(
      body: Column(
        children: [
          const BrandHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 34, 22, 34),
              children: [
                const Overline('Community + official'),
                const SizedBox(height: 16),
                const Text(
                  'The city,\nranked.',
                  style: TextStyle(
                    fontSize: 48,
                    height: .95,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -2.8,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Official event results stay distinct from evidence-reviewed community marks.',
                  style: TextStyle(color: FitColors.muted, height: 1.5),
                ),
                const SizedBox(height: 26),
                disciplines.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => ErrorPanel(
                    message: 'Leaderboards are temporarily unavailable.',
                    onRetry: () => ref.invalidate(disciplinesProvider),
                  ),
                  data: (items) => items.isEmpty
                      ? const EmptyPanel(
                          title: 'No active boards yet',
                          body: 'An administrator can configure disciplines and publish boards without a new app release.',
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: items
                              .map(
                                (item) => OutlinedButton(
                                  onPressed: () {},
                                  child: Text(item.displayName.toUpperCase()),
                                ),
                              )
                              .toList(),
                        ),
                ),
                const SizedBox(height: 24),
                const _BoardEmpty(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BoardEmpty extends StatelessWidget {
  const _BoardEmpty();
  @override
  Widget build(BuildContext context) => Container(
    color: FitColors.black,
    padding: const EdgeInsets.all(24),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Overline('Calgary · Open', light: true),
        SizedBox(height: 22),
        Text(
          'Community verified',
          style: TextStyle(
            color: FitColors.white,
            fontSize: 31,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 28),
        Divider(color: Color(0xFF505154)),
        Padding(
          padding: EdgeInsets.symmetric(vertical: 28),
          child: Text(
            'Select an active discipline to view ranked, server-verified results.',
            style: TextStyle(color: Color(0xFFB5B5B1), height: 1.5),
          ),
        ),
      ],
    ),
  );
}
