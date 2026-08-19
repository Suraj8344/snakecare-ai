import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:snakecare_mobile/src/features/auth/presentation/auth_gate.dart';

final appRouterProvider = Provider<GoRouter>((Ref ref) {
  return GoRouter(
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (context, state) => AuthGate(
          modulePreview: state.uri.queryParameters['module'],
          antivenomToken: state.uri.queryParameters['antivenom_token'],
        ),
      ),
    ],
  );
});
