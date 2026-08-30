import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/widgets.dart';
import '../../core/theme.dart';
import '../../domain/models.dart';

class LeaderboardsScreen extends ConsumerStatefulWidget {
  const LeaderboardsScreen({super.key});

  @override
  ConsumerState<LeaderboardsScreen> createState() => _LeaderboardsScreenState();
}

class _LeaderboardsScreenState extends ConsumerState<LeaderboardsScreen> {
  String? selectedDiscipline;
  String selectedDivision = 'OPEN';

  @override
  Widget build(BuildContext context) {
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
                  data: (items) {
                    if (items.isEmpty) {
                      return const EmptyPanel(
                        title: 'No active boards yet',
                        body: 'An administrator can configure disciplines and publish boards without a new app release.',
                      );
                    }
                    final active = items.firstWhere(
                      (item) => item.id == selectedDiscipline,
                      orElse: () => items.first,
                    );
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: items
                              .map(
                                (item) => _BoardFilter(
                                  label: item.displayName.toUpperCase(),
                                  selected: active.id == item.id,
                                  onPressed: () => setState(
                                    () => selectedDiscipline = item.id,
                                  ),
                                ),
                              )
                              .toList(growable: false),
                        ),
                        const SizedBox(height: 9),
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children:
                              ['OPEN', 'U23', '30–39', '40+', 'MASTERS 50+']
                                  .map(
                                    (division) => _BoardFilter(
                                      label: division,
                                      selected: selectedDivision == division,
                                      onPressed: () => setState(
                                        () => selectedDivision = division,
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                        ),
                        const SizedBox(height: 24),
                        _DevelopmentBoard(
                          discipline: active,
                          division: selectedDivision,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BoardFilter extends StatelessWidget {
  const _BoardFilter({
    required this.label,
    required this.selected,
    required this.onPressed,
  });
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      backgroundColor: selected ? FitColors.coral : Colors.transparent,
      foregroundColor: selected ? FitColors.white : FitColors.ink,
      side: BorderSide(color: selected ? FitColors.coral : FitColors.line),
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: 13),
    ),
    child: Text(label),
  );
}

class _DevelopmentBoard extends StatelessWidget {
  const _DevelopmentBoard({required this.discipline, required this.division});
  final Discipline discipline;
  final String division;

  String _mark(int index) {
    switch (discipline.metricType.toUpperCase()) {
      case 'TIME':
        return ['15:42', '16:08', '16:31', '17:04', '17:22'][index];
      case 'COUNT':
        return ['42', '38', '35', '32', '30'][index];
      default:
        return ['125', '118', '111', '104', '98'][index];
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(border: Border.all(color: FitColors.line)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: FitColors.black,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Overline('Development data · $division', light: true),
              const SizedBox(height: 10),
              Text(
                discipline.displayName,
                style: const TextStyle(
                  color: FitColors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Interaction preview — final verified rankings are completed in Phase 2.',
                style: TextStyle(color: Color(0xFFB5B5B1), fontSize: 10),
              ),
            ],
          ),
        ),
        ...List.generate(
          5,
          (index) => _RankRow(rank: index + 1, mark: _mark(index)),
        ),
      ],
    ),
  );
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.rank, required this.mark});
  final int rank;
  final String mark;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: FitColors.line)),
    ),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          color: rank <= 3 ? FitColors.coral : FitColors.black,
          child: Text(
            '$rank',
            style: const TextStyle(
              color: FitColors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Development Athlete ${String.fromCharCode(64 + rank)}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(
                'Calgary · demonstration record',
                style: TextStyle(fontSize: 9, color: FitColors.muted),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              mark,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const Text(
              'PREVIEW',
              style: TextStyle(
                fontSize: 7,
                color: FitColors.coralDark,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
