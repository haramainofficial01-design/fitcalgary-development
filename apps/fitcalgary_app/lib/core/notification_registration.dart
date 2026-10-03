import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

class NotificationRegistration {
  NotificationRegistration(this.api, [this._messaging]);

  final ApiClient api;
  FirebaseMessaging? _messaging;
  StreamSubscription<String>? _refresh;
  int _revision = 0;
  static const _deviceIDKey = 'notification_device_id';

  static bool get configured =>
      const String.fromEnvironment('FIREBASE_PROJECT_ID').isNotEmpty &&
      const String.fromEnvironment('FIREBASE_APP_ID').isNotEmpty &&
      const String.fromEnvironment('FIREBASE_API_KEY').isNotEmpty &&
      const String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID').isNotEmpty;

  Future<bool> enable() async {
    final revision = _revision;
    if (!configured) return false;
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: String.fromEnvironment('FIREBASE_API_KEY'),
          appId: String.fromEnvironment('FIREBASE_APP_ID'),
          messagingSenderId: String.fromEnvironment(
            'FIREBASE_MESSAGING_SENDER_ID',
          ),
          projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
          authDomain: String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
          storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
        ),
      );
    }
    final messaging = _messaging ??= FirebaseMessaging.instance;
    final permission = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    if (revision != _revision) return false;
    if (permission.authorizationStatus != AuthorizationStatus.authorized &&
        permission.authorizationStatus != AuthorizationStatus.provisional) {
      return false;
    }
    if (!kIsWeb && Platform.isIOS) {
      for (var attempt = 0; attempt < 10; attempt++) {
        if (await messaging.getAPNSToken() != null) break;
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
    if (revision != _revision) return false;
    final token = await messaging.getToken(
      vapidKey: const String.fromEnvironment('FIREBASE_WEB_VAPID_KEY').isEmpty
          ? null
          : const String.fromEnvironment('FIREBASE_WEB_VAPID_KEY'),
    );
    if (revision != _revision || token == null || token.length < 20) {
      return false;
    }
    await registerToken(token);
    if (revision != _revision) return false;
    await _refresh?.cancel();
    if (revision != _revision) return false;
    _refresh = messaging.onTokenRefresh.listen((value) async {
      if (revision != _revision) return;
      try {
        await registerToken(value);
      } catch (_) {
        // A future app launch or provider refresh retries registration.
      }
    });
    return true;
  }

  @visibleForTesting
  Future<void> registerToken(String token) async {
    final revision = _revision;
    final prefs = await SharedPreferences.getInstance();
    if (revision != _revision) return;
    final existing = prefs.getString(_deviceIDKey);
    final platform = kIsWeb
        ? 'WEB'
        : Platform.isIOS
        ? 'IOS'
        : 'ANDROID';
    final response = existing == null
        ? await api.dio.post<Map<String, dynamic>>(
            '/notification-devices',
            data: {'platform': platform, 'token': token},
          )
        : await api.dio.put<Map<String, dynamic>>(
            '/notification-devices/$existing',
            data: {'platform': platform, 'token': token},
          );
    final id = response.data?['id'] as String?;
    if (revision != _revision) {
      if (id != null) {
        try {
          await api.dio.delete<void>('/notification-devices/$id');
        } on DioException {
          // The provider token is deleted on sign-out. Remote cleanup is
          // best-effort if the old session has already been revoked.
        }
      }
      return;
    }
    if (id != null) await prefs.setString(_deviceIDKey, id);
  }

  Future<void> unregister() async {
    _revision++;
    await _refresh?.cancel();
    _refresh = null;
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_deviceIDKey);
    if (id != null) {
      try {
        await api.dio.delete<void>('/notification-devices/$id');
      } on DioException {
        // An API outage must not prevent local sign-out or provider-token deletion.
      } finally {
        await prefs.remove(_deviceIDKey);
      }
    }
    try {
      if (_messaging == null && Firebase.apps.isNotEmpty) {
        _messaging = FirebaseMessaging.instance;
      }
      await _messaging?.deleteToken();
    } catch (_) {}
  }
}
