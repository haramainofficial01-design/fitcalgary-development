import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';

final competitionCatalogProvider = FutureProvider.autoDispose((ref) async {
  final api = ref.read(apiProvider);
  final rows = await Future.wait([
    api.list('/disciplines'),
    api.list('/divisions'),
    api.list('/cities'),
  ]);
  return {'disciplines': rows[0], 'divisions': rows[1], 'cities': rows[2]};
});
final boardsProvider = FutureProvider.autoDispose(
  (ref) => ref.read(apiProvider).list('/leaderboards'),
);
final boardProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, (String, int)>(
      (ref, key) async =>
          (await ref
                  .read(apiProvider)
                  .dio
                  .get<Map<String, dynamic>>(
                    '/leaderboards/${key.$1}',
                    queryParameters: {'page': key.$2, 'pageSize': 20},
                  ))
              .data!,
    );
final submissionDetailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>(
      (ref, id) async =>
          (await ref
                  .read(apiProvider)
                  .dio
                  .get<Map<String, dynamic>>('/submissions/$id'))
              .data!,
    );
final judgeQueueProvider = FutureProvider.autoDispose(
  (ref) => ref.read(apiProvider).list('/judge/queue'),
);
