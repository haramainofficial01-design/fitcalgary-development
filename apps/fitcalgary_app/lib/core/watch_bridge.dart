import 'dart:io';

import 'package:flutter/services.dart';

abstract final class WatchBridge {
  static const _channel = MethodChannel('fitcalgary/watch');
  static const _apiURL = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:4000/api/v1',
  );
  static Future<void> sync(String accessToken) async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod<void>('syncAuth', {
        'accessToken': accessToken,
        'apiURL': _apiURL,
      });
    } on MissingPluginException {
      /* Watch is optional on unsupported hosts. */
    }
  }

  static Future<void> logout() async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod<void>('logout');
    } on MissingPluginException {
      /* Watch is optional. */
    }
  }
}
