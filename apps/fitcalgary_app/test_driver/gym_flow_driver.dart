import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final directory = Directory(
    Platform.environment['FITCALGARY_CAPTURE_DIR'] ??
        '../../.artifacts/phase2-day3',
  );
  await directory.create(recursive: true);
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      final safeName = name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      await File('${directory.path}/$safeName.png').writeAsBytes(bytes);
      return true;
    },
  );
}
