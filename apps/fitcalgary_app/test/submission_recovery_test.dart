import 'dart:async';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fitcalgary_app/app/providers.dart';
import 'package:fitcalgary_app/core/api_client.dart';
import 'package:fitcalgary_app/core/auth_service.dart';
import 'package:fitcalgary_app/core/evidence_picker.dart';
import 'package:fitcalgary_app/core/evidence_uploader.dart';
import 'package:fitcalgary_app/features/leaderboards/competition_providers.dart';
import 'package:fitcalgary_app/features/submissions/submit_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Guest extends AuthService {
  @override
  Future<AuthTokens?> current() async => null;
}

final class _UnreadableFile extends PlatformFile {
  @override
  String get name => 'evidence.mp4';
  @override
  Future<int> length() async => throw StateError('Private file system detail');
  @override
  Uri get uri => Uri.parse('memory:evidence.mp4');
  @override
  XFile get xFile => XFile.fromData(Uint8List.fromList([1, 2, 3]));
  @override
  Future<Uint8List> readAsBytes() async => throw StateError('Unreadable');
  @override
  Stream<Uint8List> readAsByteStream() => throw StateError('Unreadable');
}

final Map<String, List<Map<String, dynamic>>> _catalog = {
  'disciplines': [
    {
      'id': 'bench',
      'display_name': 'Bench Press',
      'metric_type': 'WEIGHT',
      'unit': 'kg',
      'evidence_type': 'VIDEO',
      'official_eligible': true,
      'community_eligible': true,
      'rules_version': 1,
      'verification_checklist': <Map<String, dynamic>>[],
    },
  ],
  'divisions': [
    {'id': 'open', 'display_label': 'Open'},
  ],
  'cities': [
    {'id': 'calgary', 'name': 'Calgary'},
  ],
};

void main() {
  for (final unavailable in [false, true]) {
    testWidgets(
      'resumed submission ${unavailable ? 'rejects unavailable rules' : 'loads saved city'}',
      (tester) async {
        final parent = Completer<Map<String, dynamic>>();
        final api = ApiClient(_Guest());
        api.dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              expect(options.path, '/profile');
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {'city_id': 'calgary'},
                ),
              );
            },
          ),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              apiProvider.overrideWithValue(api),
              competitionCatalogProvider.overrideWith((ref) async => _catalog),
              submissionDetailProvider.overrideWith((ref, id) => parent.future),
            ],
            child: const MaterialApp(home: SubmitScreen(draftId: 'draft')),
          ),
        );
        await tester.pump();
        expect(find.byType(FilledButton), findsNothing);
        parent.complete({
          'discipline_id': unavailable ? 'retired' : 'bench',
          'division_id': 'open',
          'board_type': 'OFFICIAL',
          'claimed_metric': 100,
          'checklist_acceptance': <String, bool>{},
        });
        await tester.pumpAndSettle();
        if (unavailable) {
          expect(find.text('Discipline unavailable'), findsOneWidget);
          expect(find.byType(FilledButton), findsNothing);
        } else {
          final city = find.byKey(const ValueKey('city-calgary'));
          expect(city, findsOneWidget);
          expect(tester.state<FormFieldState<String>>(city).value, 'calgary');
        }
        expect(tester.takeException(), isNull);
        api.dio.close();
      },
    );
  }
  test(
    'storage transport bounds response wait and never forwards API headers',
    () async {
      final api = ApiClient(_Guest());
      api.dio.options.headers['Authorization'] = 'Bearer isolated-test-value';
      api.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final data = options.path.endsWith('/finalize')
                ? {'status': 'SUBMITTED'}
                : options.path.contains('/parts/')
                ? {'url': 'https://storage.example/evidence'}
                : {'id': 'upload', 'partSizeBytes': 16 * 1024 * 1024};
            handler.resolve(
              Response(requestOptions: options, statusCode: 200, data: data),
            );
          },
        ),
      );
      var stored = false;
      final uploader = EvidenceUploader(
        api,
        transportFactory: (options) {
          expect(options.receiveTimeout, const Duration(seconds: 45));
          final storage = Dio(options);
          storage.interceptors.add(
            InterceptorsWrapper(
              onRequest: (request, handler) {
                expect(
                  request.headers.keys.map((key) => key.toLowerCase()),
                  isNot(contains('authorization')),
                );
                expect(request.data, [1, 2, 3]);
                stored = true;
                handler.resolve(
                  Response(
                    requestOptions: request,
                    statusCode: 200,
                    headers: Headers.fromMap({
                      'etag': ['confirmed-part'],
                    }),
                  ),
                );
              },
            ),
          );
          return storage;
        },
      );
      final result = await uploader.upload(
        submissionId: 'submission',
        file: _UnreadableFile(),
        sizeBytes: 3,
        contentType: 'video/mp4',
        onProgress: (_, _) {},
      );
      expect(stored, isTrue);
      expect(result['status'], 'SUBMITTED');
      api.dio.close();
    },
  );
  for (final failsInPicker in [true, false]) {
    testWidgets(
      'evidence ${failsInPicker ? 'picker' : 'read'} failure is recoverable',
      (tester) async {
        var attempts = 0;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              competitionCatalogProvider.overrideWith((ref) async => _catalog),
              evidencePickerProvider.overrideWithValue((video) async {
                attempts++;
                if (failsInPicker) throw StateError('Private picker detail');
                return _UnreadableFile();
              }),
            ],
            child: const MaterialApp(home: SubmitScreen()),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('SELECT PRIVATE VIDEO'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('SELECT PRIVATE VIDEO'));
        await tester.pumpAndSettle();
        expect(
          find.text(
            'The file could not be opened. Please select it again or choose another file.',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('Private picker detail'), findsNothing);
        expect(find.textContaining('Private file system detail'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('SELECT PRIVATE VIDEO'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('SELECT PRIVATE VIDEO'));
        await tester.pumpAndSettle();
        expect(attempts, 2);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final partSize in [0, -1, 1.5, 128 * 1024 * 1024, null]) {
    test(
      'invalid multipart size $partSize cannot loop or read a file',
      () async {
        final api = ApiClient(_Guest());
        var requests = 0;
        api.dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requests++;
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 201,
                  data: {'id': 'upload', 'partSizeBytes': partSize},
                ),
              );
            },
          ),
        );
        await expectLater(
          EvidenceUploader(api).upload(
            submissionId: 'submission',
            file: _UnreadableFile(),
            sizeBytes: 10,
            contentType: 'video/mp4',
            onProgress: (_, _) {},
          ),
          throwsStateError,
        );
        expect(requests, 1);
        api.dio.close();
      },
    );
  }
  test('empty evidence is rejected before creating an upload', () async {
    final api = ApiClient(_Guest());
    var requests = 0;
    api.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests++;
          handler.reject(DioException(requestOptions: options));
        },
      ),
    );
    await expectLater(
      EvidenceUploader(api).upload(
        submissionId: 'submission',
        file: _UnreadableFile(),
        sizeBytes: 0,
        contentType: 'video/mp4',
        onProgress: (_, _) {},
      ),
      throwsArgumentError,
    );
    expect(requests, 0);
    api.dio.close();
  });
}
