import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/auth_service.dart';
import '../domain/models.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final apiProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.read(authServiceProvider)),
);
final gymsProvider = FutureProvider.autoDispose<List<Gym>>(
  (ref) async =>
      (await ref.read(apiProvider).cachedList('/gyms'))
          .map(Gym.fromJson)
          .toList(growable: false),
);
final eventsProvider = FutureProvider.autoDispose<List<EventListing>>(
  (ref) async =>
      (await ref.read(apiProvider).cachedList('/events'))
          .map(EventListing.fromJson)
          .toList(growable: false),
);
final disciplinesProvider = FutureProvider.autoDispose<List<Discipline>>(
  (ref) async =>
      (await ref.read(apiProvider).cachedList('/disciplines'))
          .map(Discipline.fromJson)
          .toList(growable: false),
);

final profileProvider = FutureProvider.autoDispose<AthleteProfile>((ref) async {
  final response = await ref
      .read(apiProvider)
      .dio
      .get<Map<String, dynamic>>('/profile');
  return AthleteProfile.fromJson(response.data ?? const {});
});

final submissionsProvider = FutureProvider.autoDispose<List<SubmissionRecord>>((
  ref,
) async {
  final rows = await ref.read(apiProvider).list('/submissions');
  return rows.map(SubmissionRecord.fromJson).toList(growable: false);
});
