import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

typedef UploadProgress = void Function(int sentBytes, int totalBytes);

class EvidenceUploader {
  EvidenceUploader(this.api);

  final ApiClient api;

  Future<Map<String, dynamic>> upload({
    required String submissionId,
    required String filePath,
    required int sizeBytes,
    required String contentType,
    required UploadProgress onProgress,
  }) async {
    final initialized = await api.dio.post<Map<String, dynamic>>(
      '/submissions/$submissionId/uploads',
      data: {'contentType': contentType, 'sizeBytes': sizeBytes},
    );
    final data = initialized.data ?? const <String, dynamic>{};
    final uploadId = data['id']?.toString();
    final partSize =
        (data['partSizeBytes'] as num?)?.toInt() ?? 16 * 1024 * 1024;
    if (uploadId == null) throw StateError('Upload session was not created');

    final preferences = await SharedPreferences.getInstance();
    final stateKey = 'evidence-upload-v1:$uploadId';
    await preferences.setString(
      stateKey,
      jsonEncode({
        'submissionId': submissionId,
        'filePath': filePath,
        'sizeBytes': sizeBytes,
        'contentType': contentType,
        'partSizeBytes': partSize,
        'parts': <Map<String, dynamic>>[],
      }),
    );

    final file = File(filePath);
    final parts = <Map<String, dynamic>>[];
    var sent = 0;
    final partCount = (sizeBytes / partSize).ceil();
    for (var index = 0; index < partCount; index++) {
      final partNumber = index + 1;
      final start = index * partSize;
      final end = math.min(start + partSize, sizeBytes);
      final signed = await api.dio.post<Map<String, dynamic>>(
        '/uploads/$uploadId/parts/$partNumber',
      );
      final url = signed.data?['url']?.toString();
      if (url == null) throw StateError('Upload authorization was not issued');
      final response = await Dio().put<void>(
        url,
        data: file.openRead(start, end),
        options: Options(
          headers: {
            Headers.contentLengthHeader: end - start,
            Headers.contentTypeHeader: contentType,
          },
        ),
        onSendProgress: (partSent, _) => onProgress(sent + partSent, sizeBytes),
      );
      final eTag =
          response.headers.value('etag') ??
          response.headers.value('ETag') ??
          'part-$partNumber';
      parts.add({'ETag': eTag, 'PartNumber': partNumber});
      sent = end;
      onProgress(sent, sizeBytes);
      await preferences.setString(
        stateKey,
        jsonEncode({
          'submissionId': submissionId,
          'filePath': filePath,
          'sizeBytes': sizeBytes,
          'contentType': contentType,
          'partSizeBytes': partSize,
          'parts': parts,
        }),
      );
    }

    final finalized = await api.dio.post<Map<String, dynamic>>(
      '/uploads/$uploadId/finalize',
      data: {'parts': parts},
      options: Options(headers: {'Idempotency-Key': uploadId}),
    );
    await preferences.remove(stateKey);
    return finalized.data ?? const <String, dynamic>{};
  }
}
