import 'package:dio/dio.dart';

String workflowError(Object error) {
  if (error is DioException) {
    if (CancelToken.isCancel(error)) {
      return 'Upload paused. Retry with the same file to continue this submission.';
    }
    switch (error.response?.statusCode) {
      case 401:
        return 'Please sign in again to continue.';
      case 403:
        return 'Your account does not have access to this action.';
      case 404:
        return 'This item is no longer available.';
      case 409:
        return 'This item has changed. Refresh and try again.';
      case 413:
        return 'This file is too large. Please choose a smaller video.';
      case 422:
        return 'Check the details and required fields, then try again.';
      case 429:
        return 'Please wait a moment before trying again.';
    }
    return 'The service could not be reached. Check your connection and retry.';
  }
  return 'The operation could not finish. Please retry.';
}
