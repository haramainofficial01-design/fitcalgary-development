import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/widgets.dart';
import '../../domain/models.dart';
import 'gym_providers.dart';
import 'gym_widgets.dart';

class GymDetailScreen extends ConsumerWidget {
  const GymDetailScreen({required this.slug, super.key});
  final String slug;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(
      title: const Text('Gym details'),
      leading: BackButton(
        onPressed: () => context.canPop() ? context.pop() : context.go('/gyms'),
      ),
    ),
    body: ref
        .watch(gymDetailProvider(slug))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => ErrorPanel(
            message:
                'This gym could not be loaded. It may no longer be published.',
            onRetry: () => ref.invalidate(gymDetailProvider(slug)),
          ),
          data: (data) {
            final gym = Gym.fromJson(data);
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(gymDetailProvider(slug));
                await ref.read(gymDetailProvider(slug).future);
              },
              child: ListView(
                padding: const EdgeInsets.all(22),
                children: [
                  Text(
                    gym.operatorName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          gym.name,
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      SaveGymButton(gym: gym),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    [
                      gym.address,
                      gym.area,
                      gym.city,
                    ].whereType<String>().join(' · '),
                  ),
                  if (data['description'] != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(data['description'].toString()),
                    ),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final label in [
                        ...?data['categories'] as List?,
                        ...?data['amenities'] as List?,
                      ])
                        Chip(
                          label: Text(label.toString().replaceAll('_', ' ')),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Membership pricing',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  const Text(
                    'Biweekly means 26 payments per year. All-in figures include mandatory fees; year one also includes the joining fee. Figures are CAD; confirm taxes and terms with the operator.',
                  ),
                  const SizedBox(height: 12),
                  PricingPlans(plans: data['pricing'] as List? ?? []),
                ],
              ),
            );
          },
        ),
  );
}

class GymComparisonScreen extends ConsumerWidget {
  const GymComparisonScreen({required this.slugs, super.key});
  final List<String> slugs;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(
      title: const Text('Compare memberships'),
      leading: BackButton(
        onPressed: () => context.canPop() ? context.pop() : context.go('/gyms'),
      ),
    ),
    body: slugs.length < 2 || slugs.length > 3
        ? const EmptyPanel(
            title: 'Select two or three gyms',
            body: 'Choose gyms from the index to compare current membership plans.',
          )
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: LayoutBuilder(
              builder: (context, constraints) => Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final slug in slugs)
                    SizedBox(
                      width: constraints.maxWidth >= 700
                          ? (constraints.maxWidth - 16) / 2
                          : constraints.maxWidth,
                      child: ref
                          .watch(gymDetailProvider(slug))
                          .when(
                            loading: () => const LinearProgressIndicator(),
                            error: (_, _) => ErrorPanel(
                              message: 'Comparison data unavailable.',
                              onRetry: () =>
                                  ref.invalidate(gymDetailProvider(slug)),
                            ),
                            data: (data) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['name'].toString(),
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const Text(
                                  'Current plans · CAD · unknown prices stay unknown',
                                ),
                                PricingPlans(
                                  plans: data['pricing'] as List? ?? [],
                                ),
                              ],
                            ),
                          ),
                    ),
                ],
              ),
            ),
          ),
  );
}

class SavedGymsScreen extends ConsumerWidget {
  const SavedGymsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Saved gyms')),
    body: ref
        .watch(savedGymsProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => ErrorPanel(
            message: 'Your saved gyms could not be loaded.',
            onRetry: () => ref.invalidate(savedGymsProvider),
          ),
          data: (gyms) => RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(savedGymsProvider);
              await ref.read(savedGymsProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (gyms.isEmpty)
                  const EmptyPanel(
                    title: 'No saved gyms',
                    body: 'Save a gym from the index to build your private shortlist.',
                  ),
                for (final gym in gyms)
                  ListTile(
                    title: Text(gym.name),
                    subtitle: Text(gym.area ?? gym.city),
                    trailing: SaveGymButton(gym: gym),
                    onTap: () => context.push('/gyms/${gym.slug}'),
                  ),
              ],
            ),
          ),
        ),
  );
}
