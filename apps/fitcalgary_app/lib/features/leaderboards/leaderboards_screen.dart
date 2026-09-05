import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/widgets.dart';
import '../../core/theme.dart';
import 'competition_providers.dart';

class LeaderboardsScreen extends ConsumerStatefulWidget {
  const LeaderboardsScreen({this.boardId, super.key});
  final String? boardId;
  @override
  ConsumerState<LeaderboardsScreen> createState() => _LeaderboardsScreenState();
}

class _LeaderboardsScreenState extends ConsumerState<LeaderboardsScreen> {
  String kind = 'OFFICIAL';
  String? selected;
  int page = 1;
  @override
  void initState() {
    super.initState();
    selected = widget.boardId;
  }

  @override
  Widget build(BuildContext context) {
    final linked = ref
        .watch(boardsProvider)
        .asData
        ?.value
        .where((b) => b['id'] == selected)
        .firstOrNull;
    final activeKind = linked?['board_type'] as String? ?? kind;
    return Scaffold(
      body: Column(
        children: [
          const BrandHeader(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(boardsProvider);
                ref.invalidate(boardProvider);
              },
              child: ListView(
                padding: const EdgeInsets.all(22),
                children: [
                  const Overline('Community + official'),
                  const SizedBox(height: 14),
                  const Text(
                    'The city,\nranked.',
                    style: TextStyle(
                      fontSize: 46,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Official boards contain verified performances. Community boards also welcome unverified personal claims. Each athlete’s best eligible result earns a place.',
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final type in ['OFFICIAL', 'COMMUNITY'])
                        ChoiceChip(
                          label: Text(
                            type == 'OFFICIAL'
                                ? 'Official · verified'
                                : 'Community',
                          ),
                          selected: activeKind == type,
                          onSelected: (_) => setState(() {
                            kind = type;
                            selected = null;
                            page = 1;
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ref
                      .watch(boardsProvider)
                      .when(
                        loading: () => const LinearProgressIndicator(),
                        error: (_, _) => ErrorPanel(
                          message: 'Boards could not be loaded.',
                          onRetry: () => ref.invalidate(boardsProvider),
                        ),
                        data: (all) {
                          final boards = all
                              .where((b) => b['board_type'] == activeKind)
                              .toList();
                          if (boards.isEmpty) {
                            return const EmptyPanel(
                              title: 'No published boards yet',
                              body: 'Boards appear when eligible results are recorded.',
                            );
                          }
                          final active = boards.firstWhere(
                            (b) => b['id'] == selected,
                            orElse: () => boards.first,
                          );
                          final id = active['id'] as String;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              DropdownButtonFormField<String>(
                                key: ValueKey('$kind-$id'),
                                initialValue: id,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Discipline · division · region',
                                ),
                                items: boards
                                    .map(
                                      (b) => DropdownMenuItem(
                                        value: b['id'] as String,
                                        child: Text(
                                          "${b['discipline_name']} · ${b['division_label']} · ${b['region_name']}",
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) => setState(() {
                                  selected = v;
                                  page = 1;
                                }),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                "${active['entry_count']} athletes ranked",
                                style: const TextStyle(color: FitColors.muted),
                              ),
                              const SizedBox(height: 10),
                              ref
                                  .watch(boardProvider((id, page)))
                                  .when(
                                    loading: () =>
                                        const LinearProgressIndicator(),
                                    error: (_, _) => ErrorPanel(
                                      message: 'Results could not be loaded.',
                                      onRetry: () => ref.invalidate(
                                        boardProvider((id, page)),
                                      ),
                                    ),
                                    data: (board) {
                                      final entries = (board['entries'] as List)
                                          .cast<Map<String, dynamic>>();
                                      return Column(
                                        children: [
                                          if (entries.isEmpty)
                                            const EmptyPanel(
                                              title: 'No results on this page',
                                              body: 'Return to the previous page or choose another board.',
                                            ),
                                          for (final row in entries)
                                            _ResultRow(row: row, boardId: id),
                                          const SizedBox(height: 14),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              TextButton(
                                                onPressed: page > 1
                                                    ? () =>
                                                          setState(() => page--)
                                                    : null,
                                                child: const Text('PREVIOUS'),
                                              ),
                                              Text('Page $page'),
                                              TextButton(
                                                onPressed:
                                                    page * 20 <
                                                        (active['entry_count']
                                                                as num? ??
                                                            0)
                                                    ? () =>
                                                          setState(() => page++)
                                                    : null,
                                                child: const Text('NEXT'),
                                              ),
                                            ],
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                            ],
                          );
                        },
                      ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => context.push('/submit'),
                    icon: const Icon(Icons.add),
                    label: const Text('POST A RESULT'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.row, required this.boardId});
  final Map<String, dynamic> row;
  final String boardId;
  @override
  Widget build(BuildContext context) {
    final verified = row['verification_type'] != 'UNVERIFIED';
    final rank = (row['rank'] as num).toInt();
    final previous = (row['previous_rank'] as num?)?.toInt();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FitColors.white,
        border: Border.all(color: FitColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: rank <= 3 ? FitColors.coral : FitColors.ink,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$rank',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row['display_name'] as String,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (row['gym_name'] != null)
                  Text(
                    row['gym_name'] as String,
                    style: const TextStyle(
                      fontSize: 11,
                      color: FitColors.muted,
                    ),
                  ),
                Text(
                  verified ? 'Verified performance' : 'Unverified claim',
                  style: const TextStyle(fontSize: 11, color: FitColors.muted),
                ),
                if (previous != null && previous != rank)
                  Text(
                    previous > rank
                        ? '↑ Up ${previous - rank}'
                        : '↓ Down ${rank - previous}',
                    style: const TextStyle(fontSize: 11),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                row['display_metric'] as String,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (row['profile_id'] != null)
                IconButton(
                  tooltip: 'Copy result',
                  icon: const Icon(Icons.ios_share, size: 18),
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(
                        text:
                            "${row['display_name']} · ${row['display_metric']} · #$rank · ${verified ? 'Verified' : 'Unverified'}\nFitCalgary Index · Board $boardId",
                      ),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Result copied for sharing.'),
                        ),
                      );
                    }
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
