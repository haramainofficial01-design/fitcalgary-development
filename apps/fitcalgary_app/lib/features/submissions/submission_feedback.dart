import 'package:dio/dio.dart';

String workflowError(Object error) {
  if (error is DioException) {
    if (CancelToken.isCancel(error)) {
      return 'Upload paused. Retry with the same file to continue this submission.';
    }
    final body = error.response?.data;
    if (body is Map && body['error'] is Map) {
      final message = (body['error'] as Map)['message'];
      if (message is String) return message;
    }
    return 'The service could not be reached. Check your connection and retry.';
  }
  return 'The operation could not finish. Please retry.';
}
