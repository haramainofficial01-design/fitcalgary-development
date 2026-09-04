import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/widgets.dart';
import '../../core/theme.dart';
import 'gym_providers.dart';
import 'gym_widgets.dart';

class GymsScreen extends ConsumerStatefulWidget {
  const GymsScreen({super.key});
  @override
  ConsumerState<GymsScreen> createState() => _GymsScreenState();
}

class _GymsScreenState extends ConsumerState<GymsScreen> {
  String query = '',
      area = '',
      category = '',
      amenity = '',
      pricing = '',
      sort = 'cost';
  int page = 1;
  bool showMore = false;
  Timer? debounce;
  final selected = <String>{};
  @override
  void dispose() {
    debounce?.cancel();
    super.dispose();
  }

  void change(VoidCallback action) => setState(() {
    action();
    page = 1;
  });
  @override
  Widget build(BuildContext context) {
    final encoded = Uri(
      queryParameters: {
        'q': query,
        'area': area,
        'category': category,
        'amenity': amenity,
        'pricing': pricing,
        'sort': sort,
        'page': '$page',
        'pageSize': '20',
      },
    ).query;
    final provider = directoryProvider(encoded);
    final gyms = ref.watch(provider);
    return Scaffold(
      body: Column(
        children: [
          const BrandHeader(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(provider);
                await ref.read(provider.future);
                ref.invalidate(savedGymsProvider);
              },
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
                  const SizedBox(height: 22),
                  TextField(
                    key: const ValueKey('gym-search'),
                    onChanged: (value) {
                      debounce?.cancel();
                      debounce = Timer(const Duration(milliseconds: 300), () {
                        if (mounted) change(() => query = value.trim());
                      });
                    },
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search gyms, operators, areas',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final item in {
                        '': 'Everything',
                        'BUDGET': '24/7 & budget',
                        'FULL_SERVICE': 'Full-service',
                        'BOUTIQUE': 'Boutique',
                        'CLIMBING': 'Climbing',
                        'REC_CENTRE': 'Rec centre',
                      }.entries)
                        ChoiceChip(
                          label: Text(item.value),
                          selected: category == item.key,
                          onSelected: (_) => change(() => category = item.key),
                        ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => setState(() => showMore = !showMore),
                    child: Text(showMore ? 'FEWER FILTERS' : 'MORE FILTERS'),
                  ),
                  if (showMore) ...[
                    TextField(
                      key: const ValueKey('gym-area'),
                      onChanged: (value) => change(() => area = value.trim()),
                      decoration: const InputDecoration(
                        labelText: 'Area / neighbourhood',
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: amenity,
                      decoration: const InputDecoration(labelText: 'Amenity'),
                      items: [
                        for (final entry in {
                          '': 'Any amenity',
                          'POOL': 'Pool',
                          'SHOWERS': 'Showers',
                          'PARKING': 'Parking',
                          'SAUNA': 'Sauna',
                        }.entries)
                          DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                      ],
                      onChanged: (value) => change(() => amenity = value ?? ''),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: pricing,
                      decoration: const InputDecoration(
                        labelText: 'Pricing information',
                      ),
                      items: const [
                        DropdownMenuItem(value: '', child: Text('All pricing')),
                        DropdownMenuItem(
                          value: 'complete',
                          child: Text('All plans complete'),
                        ),
                        DropdownMenuItem(
                          value: 'incomplete',
                          child: Text('Pricing incomplete'),
                        ),
                      ],
                      onChanged: (value) => change(() => pricing = value ?? ''),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('COST'),
                        selected: sort == 'cost',
                        onSelected: (_) => change(() => sort = 'cost'),
                      ),
                      ChoiceChip(
                        label: const Text('A–Z'),
                        selected: sort == 'name',
                        onSelected: (_) => change(() => sort = 'name'),
                      ),
                      TextButton(
                        onPressed: () => context.push('/saved-gyms'),
                        child: const Text('SAVED GYMS'),
                      ),
                    ],
                  ),
                  if (selected.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: FilledButton(
                        onPressed: selected.length < 2
                            ? null
                            : () => context.push(
                                Uri(
                                  path: '/gyms/compare',
                                  queryParameters: {
                                    'slugs': selected.join(','),
                                  },
                                ).toString(),
                              ),
                        child: Text('COMPARE (${selected.length}/3)'),
                      ),
                    ),
                  gyms.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, _) => ErrorPanel(
                      message: 'The gym index could not be reached. Try again.',
                      onRetry: () => ref.invalidate(provider),
                    ),
                    data: (result) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${result.total} LOCATIONS · PAGE $page',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (result.items.isEmpty)
                          const EmptyPanel(
                            title: 'No gyms found',
                            body: 'Try another search or clear the filters. Listings come from the published directory.',
                          ),
                        for (final gym in result.items)
                          Container(
                            key: ValueKey('gym-${gym.slug}'),
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: FitColors.line),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  gym.operatorName,
                                  style: const TextStyle(
                                    color: FitColors.coralDark,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                TextButton(
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    alignment: Alignment.centerLeft,
                                  ),
                                  onPressed: () =>
                                      context.push('/gyms/${gym.slug}'),
                                  child: Text(
                                    gym.name,
                                    style: const TextStyle(
                                      fontSize: 21,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Text(gym.area ?? gym.city),
                                const SizedBox(height: 10),
                                Text(
                                  gym.lowestOngoingMonthlyCents == null
                                      ? 'Pricing incomplete'
                                      : 'From ${money(gym.lowestOngoingMonthlyCents)} / month all-in',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (!gym.pricingComplete &&
                                    gym.lowestOngoingMonthlyCents != null)
                                  const Text(
                                    'Some plans have incomplete pricing.',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                Row(
                                  children: [
                                    SaveGymButton(gym: gym),
                                    const Spacer(),
                                    FilterChip(
                                      label: const Text('Compare'),
                                      selected: selected.contains(gym.slug),
                                      onSelected: (value) {
                                        if (value && selected.length >= 3) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Compare up to three gyms.',
                                                  ),
                                                ),
                                              );
                                          return;
                                        }
                                        setState(() {
                                          if (value) {
                                            selected.add(gym.slug);
                                          } else {
                                            selected.remove(gym.slug);
                                          }
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        Row(
                          children: [
                            TextButton(
                              onPressed: page > 1
                                  ? () => setState(() => page--)
                                  : null,
                              child: const Text('PREVIOUS'),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: page * 20 < result.total
                                  ? () => setState(() => page++)
                                  : null,
                              child: const Text('NEXT PAGE'),
                            ),
                          ],
                        ),
                      ],
                    ),
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
