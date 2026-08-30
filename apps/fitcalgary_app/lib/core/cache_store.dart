import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class CacheStore {
  static const _prefix = 'public-cache-v1:';
  static const maxAge = Duration(hours: 6);

  Future<void> write(String key, List<Map<String, dynamic>> value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      '$_prefix$key',
      jsonEncode({
        'storedAt': DateTime.now().toUtc().toIso8601String(),
        'data': value,
      }),
    );
  }

  Future<List<Map<String, dynamic>>?> read(
    String key, {
    bool allowStale = false,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString('$_prefix$key');
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final storedAt = DateTime.parse(decoded['storedAt'] as String);
      if (!allowStale && DateTime.now().toUtc().difference(storedAt) > maxAge) {
        return null;
      }
      return (decoded['data'] as List).cast<Map<String, dynamic>>().toList(
        growable: false,
      );
    } catch (_) {
      await preferences.remove('$_prefix$key');
      return null;
    }
  }
}
