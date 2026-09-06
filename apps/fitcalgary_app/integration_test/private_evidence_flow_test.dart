import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:fitcalgary_app/app/app.dart';
import 'package:fitcalgary_app/app/providers.dart';
import 'package:fitcalgary_app/core/auth_service.dart';
import 'package:fitcalgary_app/core/evidence_picker.dart';
import 'package:fitcalgary_app/core/onboarding_store.dart';

class _Identity extends AuthService {
  @override
  Future<AuthTokens?> current() async =>
      const AuthTokens(accessToken: String.fromEnvironment('TEST_USER_TOKEN'));
  @override
  Future<AuthTokens?> refresh() async => null;
}

// The picker boundary supplies an actual local clip; API/storage are not mocked.
final class _Clip extends PlatformFile {
  _Clip(this.file);
  final File file;
  @override
  String get name => 'transport-test.mp4';
  @override
  Uri get uri => file.uri;
  @override
  XFile get xFile => XFile(file.path);
  @override
  Future<int> length() => file.length();
  @override
  Future<Uint8List> readAsBytes() => file.readAsBytes();
  @override
  Stream<Uint8List> readAsByteStream() =>
      file.openRead().map(Uint8List.fromList);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Flutter private upload, correction, approval, ranking and inbox',
    (tester) async {
      final bytes = base64Decode(
        const String.fromEnvironment('TEST_EVIDENCE_BASE64'),
      );
      final directory = await Directory.systemTemp.createTemp(
        'fitcalgary-evidence-',
      );
      final file = await File('${directory.path}/clip.mp4').writeAsBytes(bytes);
      final api = Dio(
        BaseOptions(
          baseUrl: const String.fromEnvironment('API_BASE_URL'),
          headers: {
            'Authorization':
                'Bearer ${const String.fromEnvironment('TEST_USER_TOKEN')}',
          },
        ),
      );
      final judge = Dio(
        BaseOptions(
          baseUrl: const String.fromEnvironment('API_BASE_URL'),
          headers: {
            'Authorization':
                'Bearer ${const String.fromEnvironment('TEST_ADMIN_TOKEN')}',
          },
        ),
      );
      await api.patch(
        '/profile',
        data: {
          'displayName': 'Private evidence test athlete',
          'privacy': {'publicProfile': true, 'showGym': false},
        },
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(_Identity()),
            evidencePickerProvider.overrideWithValue((_) async => _Clip(file)),
          ],
          child: FitCalgaryApp(
            onboardingStore: MemoryOnboardingStore(complete: true),
          ),
        ),
      );
      Future<void> settle() async {
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
      }

      Future<void> reveal(Finder finder) async {
        await tester.scrollUntilVisible(
          finder,
          150,
          scrollable: find.byType(Scrollable).first,
          maxScrolls: 40,
        );
        await settle();
      }

      Future<void> send() async {
        await reveal(find.text('SELECT PRIVATE VIDEO'));
        await tester.tap(find.text('SELECT PRIVATE VIDEO'));
        await settle();
        await reveal(find.text('SUBMIT FOR REVIEW'));
        await tester.tap(find.text('SUBMIT FOR REVIEW'));
        for (
          var i = 0;
          i < 100 && find.text('PENDING REVIEW').evaluate().isEmpty;
          i++
        ) {
          await settle();
        }
        expect(find.text('PENDING REVIEW'), findsOneWidget);
      }

      await settle();
      await tester.tap(find.text('POST RESULT').first);
      await settle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await settle();
      await tester.tap(find.text('Bench Press').last);
      await settle();
      await reveal(find.text('City represented'));
      await tester.tap(find.text('City represented'));
      await settle();
      await tester.tap(find.text('Calgary').last);
      await settle();
      await reveal(find.byType(TextField));
      await tester.enterText(find.byType(TextField), '137');
      FocusManager.instance.primaryFocus?.unfocus();
      await settle();
      final disciplines = (await api.get('/disciplines')).data['data'] as List;
      final discipline = disciplines.firstWhere(
        (d) => d['display_name'] == 'Bench Press',
      );
      Future<void> confirmRules() async {
        for (final rule in discipline['verification_checklist'] as List) {
          await reveal(find.text(rule['label'] as String));
          await tester.tap(find.text(rule['label'] as String));
          await settle();
        }
      }

      await confirmRules();
      await send();
      final entries = (await api.get('/submissions')).data['data'] as List;
      final original = entries.first['id'] as String;
      final denied = await api.get(
        '/judge/submissions/$original/evidence',
        options: Options(validateStatus: (_) => true),
      );
      expect(denied.statusCode, 403);
      final access =
          (await judge.get('/judge/submissions/$original/evidence')).data['url']
              as String;
      final downloaded = await Dio().get<List<int>>(
        access,
        options: Options(responseType: ResponseType.bytes),
      );
      expect(downloaded.data, orderedEquals(bytes));
      await judge.post(
        '/judge/submissions/$original/decision',
        data: {
          'decision': 'RESUBMISSION_REQUESTED',
          'comments': 'Include the full setup.',
        },
      );
      await tester.tap(find.byTooltip('Refresh submission'));
      await settle();
      await reveal(find.text('CORRECT & RESUBMIT'));
      await tester.tap(find.text('CORRECT & RESUBMIT'));
      await settle();
      await confirmRules();
      await send();
      final corrected =
          ((await api.get('/submissions')).data['data'] as List).first['id']
              as String;
      expect(corrected, isNot(original));
      await judge.post(
        '/judge/submissions/$corrected/decision',
        data: {
          'decision': 'APPROVED',
          'comments': 'Transport test accepted.',
          'checklistResponses': {
            for (final rule in discipline['verification_checklist'] as List)
              rule['key']: true,
          },
        },
      );
      final detail = (await api.get('/submissions/$corrected')).data;
      expect(detail['status'], 'APPROVED');
      await tester.tap(find.byTooltip('Refresh submission'));
      await settle();
      await reveal(find.text('VIEW PUBLISHED BOARD'));
      await tester.tap(find.text('VIEW PUBLISHED BOARD'));
      await settle();
      expect(find.text('Private evidence test athlete'), findsWidgets);
      final board = (await api.get(
        '/leaderboards/${detail['result']['leaderboardId']}',
      )).data;
      expect(board.toString(), contains('Private evidence test athlete'));
      var notified = false;
      for (var i = 0; i < 30; i++) {
        final inbox = (await api.get('/notifications')).data['data'] as List;
        notified = inbox.any(
          (n) =>
              n['type'] == 'SUBMISSION_APPROVED' &&
              (n['deep_link'] as String).endsWith(corrected),
        );
        if (notified) break;
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      expect(notified, isTrue);
      expect(tester.takeException(), isNull);
      await file.delete();
      await directory.delete();
      api.close();
      judge.close();
      debugPrint(
        'PASS: Flutter form and real file upload → Go/PostgreSQL/private storage; correction, approval, official placement and inbox. Picker and identity are test boundaries; judge actions use API; clip is synthetic transport evidence.',
      );
    },
  );
}
