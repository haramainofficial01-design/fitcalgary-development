import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/widgets.dart';
import '../../core/theme.dart';
import '../../domain/models.dart';

class GymsScreen extends ConsumerStatefulWidget {
  const GymsScreen({super.key});
  @override
  ConsumerState<GymsScreen> createState() => _GymsScreenState();
}

class _GymsScreenState extends ConsumerState<GymsScreen> {
  String query = '';
  String area = 'ALL AREAS';
  String pricing = 'EVERYTHING';
  bool sortByCost = true;
  bool showMore = false;
  @override
  Widget build(BuildContext context) {
    final gyms = ref.watch(gymsProvider);
    return Scaffold(
      body: Column(
        children: [
          const BrandHeader(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(gymsProvider.future),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 34, 22, 34),
                children: [
                  const Overline('The gym index'),
                  const SizedBox(height: 16),
                  const Text(
                    'Every major gym\nin Calgary.',
                    style: TextStyle(
                      fontSize: 43,
                      height: .98,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -2.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Advertised rates and normalized all-in monthly cost, side by side.',
                    style: TextStyle(color: FitColors.muted, height: 1.5),
                  ),
                  const SizedBox(height: 26),
                  TextField(
                    onChanged: (value) =>
                        setState(() => query = value.toLowerCase()),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search gyms, operators, areas',
                    ),
                  ),
                  const SizedBox(height: 14),
                  gyms.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (items) {
                      final areas = <String>{
                        'ALL AREAS',
                        ...items
                            .map((item) => item.area?.toUpperCase())
                            .whereType<String>(),
                      }.take(6).toList(growable: false);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Wrap(
                            spacing: 7,
                            runSpacing: 7,
                            children: areas
                                .map(
                                  (label) => _IndexFilter(
                                    label: label,
                                    selected: area == label,
                                    onPressed: () =>
                                        setState(() => area = label),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 7,
                            runSpacing: 7,
                            children:
                                [
                                      'EVERYTHING',
                                      'ALL-IN VERIFIED',
                                      'PRICING PENDING',
                                    ]
                                    .map(
                                      (label) => _IndexFilter(
                                        label: label,
                                        selected: pricing == label,
                                        onPressed: () =>
                                            setState(() => pricing = label),
                                      ),
                                    )
                                    .toList(growable: false),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton(
                            onPressed: () =>
                                setState(() => showMore = !showMore),
                            child: Text(
                              showMore ? 'FEWER FILTERS' : 'MORE FILTERS',
                            ),
                          ),
                          if (showMore)
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: const BoxDecoration(
                                border: Border(
                                  left: BorderSide(color: FitColors.line),
                                  right: BorderSide(color: FitColors.line),
                                  bottom: BorderSide(color: FitColors.line),
                                ),
                              ),
                              child: const Text(
                                'Additional amenities and contract filters will use Client-confirmed data in Phase 2.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: FitColors.muted,
                                  height: 1.4,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 22),
                  gyms.when(
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(48),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (error, _) => ErrorPanel(
                      message: 'The gym index could not be reached. Check your connection and try again.',
                      onRetry: () => ref.invalidate(gymsProvider),
                    ),
                    data: (items) {
                      final visible = items
                          .where(
                            (item) =>
                                query.isEmpty ||
                                '${item.name} ${item.operatorName} ${item.area ?? ''}'
                                    .toLowerCase()
                                    .contains(query),
                          )
                          .where(
                            (item) =>
                                area == 'ALL AREAS' ||
                                item.area?.toUpperCase() == area,
                          )
                          .where((item) {
                            if (pricing == 'ALL-IN VERIFIED') {
                              return item.pricingComplete;
                            }
                            if (pricing == 'PRICING PENDING') {
                              return !item.pricingComplete;
                            }
                            return true;
                          })
                          .toList();
                      visible.sort((a, b) {
                        if (!sortByCost) return a.name.compareTo(b.name);
                        return (a.lowestOngoingMonthlyCents ?? 1 << 30)
                            .compareTo(b.lowestOngoingMonthlyCents ?? 1 << 30);
                      });
                      if (visible.isEmpty) {
                        return const EmptyPanel(
                          title: 'No gyms found',
                          body: 'Try another search. Production listings are published through the FitCalgary admin system.',
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${visible.length} ${visible.length == 1 ? 'LOCATION' : 'LOCATIONS'}',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                              _IndexFilter(
                                label: 'COST',
                                selected: sortByCost,
                                onPressed: () =>
                                    setState(() => sortByCost = true),
                              ),
                              const SizedBox(width: 6),
                              _IndexFilter(
                                label: 'A–Z',
                                selected: !sortByCost,
                                onPressed: () =>
                                    setState(() => sortByCost = false),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ...visible.map((item) => _GymRow(item)),
                        ],
                      );
                    },
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

class _IndexFilter extends StatelessWidget {
  const _IndexFilter({
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      minimumSize: const Size(0, 42),
    ),
    child: Text(label),
  );
}

class _GymRow extends ConsumerStatefulWidget {
  const _GymRow(this.gym);
  final Gym gym;

  @override
  ConsumerState<_GymRow> createState() => _GymRowState();
}

class _GymRowState extends ConsumerState<_GymRow> {
  late bool saved = widget.gym.saved;
  bool busy = false;

  Future<void> toggleSaved() async {
    setState(() => busy = true);
    try {
      if (saved) {
        await ref
            .read(apiProvider)
            .dio
            .delete<void>('/saved-gyms/${widget.gym.id}');
      } else {
        await ref
            .read(apiProvider)
            .dio
            .put<void>('/saved-gyms/${widget.gym.id}');
      }
      if (mounted) setState(() => saved = !saved);
    } on DioException catch (error) {
      if (error.response?.statusCode == 401 && mounted) {
        context.push('/signin');
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved gyms could not be updated.')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gym = widget.gym;
    final cents = gym.lowestOngoingMonthlyCents;
    final name = gym.name;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: FitColors.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            color: const Color(0xFFDDDAD2),
            alignment: Alignment.center,
            child: Text(
              name
                  .split(' ')
                  .take(2)
                  .map((word) => word.isEmpty ? '' : word[0])
                  .join(),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  gym.operatorName,
                  style: const TextStyle(
                    fontSize: 9,
                    letterSpacing: 1.4,
                    color: FitColors.coralDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  gym.area ?? gym.city,
                  style: const TextStyle(fontSize: 11, color: FitColors.muted),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                cents == null
                    ? 'Pricing\nincomplete'
                    : '\$${(cents / 100).toStringAsFixed(2)}',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: cents == null ? 11 : 21,
                  fontWeight: FontWeight.w900,
                  color: cents == null ? FitColors.muted : FitColors.ink,
                ),
              ),
              if (cents != null)
                const Text(
                  'ALL-IN / MO',
                  style: TextStyle(
                    fontSize: 8,
                    letterSpacing: 1.2,
                    color: FitColors.muted,
                  ),
                ),
              const SizedBox(height: 8),
              IconButton(
                tooltip: saved ? 'Remove saved gym' : 'Save gym privately',
                onPressed: busy ? null : toggleSaved,
                icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
