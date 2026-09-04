import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models.dart';

class ContentPage<T> {
  const ContentPage(this.items, this.total);
  final List<T> items;
  final int total;
}

final eventDirectoryProvider = FutureProvider.autoDispose
    .family<ContentPage<EventListing>, String>((ref, query) async {
      final response = await ref
          .read(apiProvider)
          .dio
          .get<Map<String, dynamic>>(
            '/events',
            queryParameters: Uri.splitQueryString(query),
          );
      final data = response.data ?? const {};
      return ContentPage(
        (data['data'] as List? ?? const [])
            .map(
              (item) => EventListing.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList(growable: false),
        (data['total'] as num?)?.toInt() ?? 0,
      );
    });

final clubDirectoryProvider = FutureProvider.autoDispose
    .family<ContentPage<ClubListing>, String>((ref, query) async {
      final response = await ref
          .read(apiProvider)
          .dio
          .get<Map<String, dynamic>>(
            '/clubs',
            queryParameters: Uri.splitQueryString(query),
          );
      final data = response.data ?? const {};
      return ContentPage(
        (data['data'] as List? ?? const [])
            .map(
              (item) => ClubListing.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList(growable: false),
        (data['total'] as num?)?.toInt() ?? 0,
      );
    });

final eventDetailProvider = FutureProvider.autoDispose
    .family<EventListing, String>((ref, slug) async {
      final response = await ref
          .read(apiProvider)
          .dio
          .get<Map<String, dynamic>>('/events/${Uri.encodeComponent(slug)}');
      return EventListing.fromJson(response.data ?? const {});
    });

final clubDetailProvider = FutureProvider.autoDispose
    .family<ClubListing, String>((ref, slug) async {
      final response = await ref
          .read(apiProvider)
          .dio
          .get<Map<String, dynamic>>('/clubs/${Uri.encodeComponent(slug)}');
      return ClubListing.fromJson(response.data ?? const {});
    });
