import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/auth_service.dart';
import '../core/notification_registration.dart';
import '../domain/models.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final apiProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.read(authServiceProvider)),
);
final notificationRegistrationProvider = Provider<NotificationRegistration>(
  (ref) => NotificationRegistration(ref.read(apiProvider)),
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

class CatalogSnapshot {
  const CatalogSnapshot({
    required this.gyms,
    required this.events,
    required this.boards,
  });

  final int gyms;
  final int events;
  final int boards;
}

final catalogSnapshotProvider = FutureProvider.autoDispose<CatalogSnapshot>((
  ref,
) async {
  final dio = ref.read(apiProvider).dio;
  final responses = await Future.wait([
    dio.get<Map<String, dynamic>>('/gyms', queryParameters: {'pageSize': 1}),
    dio.get<Map<String, dynamic>>('/events', queryParameters: {'pageSize': 1}),
    dio.get<Map<String, dynamic>>(
      '/disciplines',
      queryParameters: {'pageSize': 1},
    ),
  ]);
  int total(int index) {
    final payload = responses[index].data ?? const <String, dynamic>{};
    return (payload['total'] as num?)?.toInt() ??
        (payload['data'] as List? ?? const []).length;
  }

  return CatalogSnapshot(gyms: total(0), events: total(1), boards: total(2));
});

final profileProvider = FutureProvider.autoDispose<AthleteProfile>((ref) async {
  final response = await ref
      .read(apiProvider)
      .dio
      .get<Map<String, dynamic>>('/profile');
  return AthleteProfile.fromJson(response.data ?? const {});
});

final performanceProvider = FutureProvider.autoDispose<AthletePerformance>((
  ref,
) async {
  final response = await ref
      .read(apiProvider)
      .dio
      .get<Map<String, dynamic>>('/profile/performance');
  return AthletePerformance.fromJson(response.data ?? const {});
});

final submissionsProvider = FutureProvider.autoDispose<List<SubmissionRecord>>((
  ref,
) async {
  final rows = await ref.read(apiProvider).list('/submissions');
  return rows.map(SubmissionRecord.fromJson).toList(growable: false);
});
