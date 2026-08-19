import 'package:flutter_test/flutter_test.dart';
import 'package:snakecare_mobile/src/features/system_status/domain/service_status.dart';

void main() {
  test('parses a valid service status', () {
    final ServiceStatus status = ServiceStatus.fromJson(<String, Object?>{
      'service': 'snakecare-api',
      'status': 'ok',
      'version': '0.1.0',
    });
    expect(status.service, 'snakecare-api');
    expect(status.status, 'ok');
  });

  test('rejects an invalid service status', () {
    expect(
      () => ServiceStatus.fromJson(<String, Object?>{'status': 'ok'}),
      throwsFormatException,
    );
  });
}
