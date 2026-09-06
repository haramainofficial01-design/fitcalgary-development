import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitcalgary_app/features/submissions/submission_feedback.dart';

void main() {
  test('protected-action failures use safe account wording', () {
    for (final status in [401, 403, 404, 409, 413, 422, 429, 500]) {
      final request = RequestOptions(path: '/protected');
      final error = DioException(
        requestOptions: request,
        response: Response(
          requestOptions: request,
          statusCode: status,
          data: {
            'error': {'message': 'private service diagnostic'},
          },
        ),
      );
      final message = workflowError(error);
      expect(message, isNot(contains('private service diagnostic')));
      if (status == 403) expect(message, contains('does not have access'));
      if (status == 401) expect(message, contains('sign in again'));
    }
  });
}
