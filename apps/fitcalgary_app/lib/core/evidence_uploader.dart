import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';

import 'api_client.dart';

typedef UploadProgress = void Function(int sentBytes, int totalBytes);

class EvidenceUploader {
  EvidenceUploader(this.api);
  final ApiClient api;

  Future<Map<String, dynamic>> upload({
    required String submissionId,
    required PlatformFile file,
    required int sizeBytes,
    required String contentType,
    required UploadProgress onProgress,
    CancelToken? cancelToken,
  }) async {
    final initialized = await api.dio.post<Map<String, dynamic>>(
      '/submissions/$submissionId/uploads',
      data: {'contentType': contentType, 'sizeBytes': sizeBytes},
      cancelToken: cancelToken,
    );
    final uploadId = initialized.data!['id'] as String;
    final partSize = (initialized.data!['partSizeBytes'] as num).toInt();
    final parts = <Map<String, dynamic>>[];
    // One bounded part in memory works on browser blobs and native file handles.
    // Separate transport never attaches the API's bearer token to object storage.
    final transport = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(minutes: 4),
      ),
    );
    try {
      for (var start = 0; start < sizeBytes; start += partSize) {
        final end = math.min(start + partSize, sizeBytes);
        final partNumber = parts.length + 1;
        final builder = BytesBuilder(copy: false);
        await for (final chunk in file.xFile.openRead(start, end)) {
          builder.add(chunk);
        }
        final bytes = builder.takeBytes();
        if (bytes.length != end - start) {
          throw StateError('The file changed. Select it again.');
        }
        String? etag;
        for (var attempt = 0; attempt < 3; attempt++) {
          try {
            final signed = await api.dio.post<Map<String, dynamic>>(
              '/uploads/$uploadId/parts/$partNumber',
              cancelToken: cancelToken,
            );
            final response = await transport.put<void>(
              signed.data!['url'] as String,
              data: bytes,
              cancelToken: cancelToken,
              options: Options(contentType: contentType),
              onSendProgress: (sent, _) => onProgress(start + sent, sizeBytes),
            );
            etag = response.headers.value('etag');
            if (etag == null || etag.isEmpty) {
              throw StateError(
                'Storage did not confirm this part. Check its ETag/CORS configuration.',
              );
            }
            break;
          } on DioException catch (error) {
            if (CancelToken.isCancel(error) || attempt == 2) rethrow;
            await Future<void>.delayed(
              Duration(milliseconds: 400 * (attempt + 1)),
            );
          }
        }
        parts.add({'ETag': etag, 'PartNumber': partNumber});
        onProgress(end, sizeBytes);
      }
      final finalized = await api.dio.post<Map<String, dynamic>>(
        '/uploads/$uploadId/finalize',
        data: {'parts': parts},
        cancelToken: cancelToken,
      );
      return finalized.data!;
    } finally {
      transport.close();
    }
  }
}
