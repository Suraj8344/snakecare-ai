import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snakecare_mobile/src/features/system_status/data/system_status_repository.dart';
import 'package:snakecare_mobile/src/features/system_status/domain/service_status.dart';

final systemStatusProvider = FutureProvider<ServiceStatus>((Ref ref) {
  return ref.watch(systemStatusRepositoryProvider).getHealth();
});
