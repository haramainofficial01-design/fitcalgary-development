import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models.dart';

class GymPage {
  const GymPage(this.items, this.total);
  final List<Gym> items;
  final int total;
}

final directoryProvider = FutureProvider.autoDispose.family<GymPage, String>((
  ref,
  query,
) async {
  final response = await ref
      .read(apiProvider)
      .dio
      .get<Map<String, dynamic>>(
        '/gyms',
        queryParameters: Uri.splitQueryString(query),
      );
  final data = response.data!;
  return GymPage(
    (data['data'] as List)
        .map((item) => Gym.fromJson(Map<String, dynamic>.from(item)))
        .toList(),
    (data['total'] as num).toInt(),
  );
});

final gymDetailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, slug) async {
      final response = await ref
          .read(apiProvider)
          .dio
          .get<Map<String, dynamic>>('/gyms/${Uri.encodeComponent(slug)}');
      return response.data!;
    });

// Private data is never stored in the public offline cache. Re-fetch on account
// changes and after writes so a route remount cannot invent a saved state.
final savedGymsProvider = FutureProvider.autoDispose<List<Gym>>((ref) async {
  if (await ref.read(authServiceProvider).current() == null) return [];
  return (await ref.read(apiProvider).list('/saved-gyms'))
      .map(Gym.fromJson)
      .toList();
});

String money(dynamic cents) {
  final value = cents is num ? cents : num.tryParse(cents?.toString() ?? '');
  return value == null
      ? 'Not supplied'
      : '\$${(value / 100).toStringAsFixed(2)}';
}
