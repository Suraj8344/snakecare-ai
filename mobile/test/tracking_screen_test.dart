import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snakecare_mobile/src/core/network/api_client.dart';
import 'package:snakecare_mobile/src/features/ambulance_tracking/tracking_screen.dart';

void main() {
  for (final state in ['requested', 'en_route']) {
    testWidgets('tracking $state does not imply GPS or confirmed dispatch',
        (tester) async {
      final dio = Dio();
      dio.interceptors.add(InterceptorsWrapper(onRequest: (request, handler) {
        handler.resolve(Response<dynamic>(
            requestOptions: request,
            statusCode: 200,
            data: request.path.endsWith('hospitals')
                ? <dynamic>[]
                : <String, dynamic>{
                    'trips': <dynamic>[
                      <String, dynamic>{
                        'id': 'test-trip',
                        'status': state,
                        'is_patient': true,
                        'is_driver': false,
                        'hospital_id': 'test-hospital',
                      },
                    ],
                    'managed_hospitals': <dynamic>[],
                    'registrations': <dynamic>[],
                  },),);
      },),);
      await tester.pumpWidget(ProviderScope(
          overrides: [dioProvider.overrideWithValue(dio)],
          child: const MaterialApp(
              home: TrackingScreen(accessToken: 'test-token'),),),);
      await tester.pumpAndSettle();
      expect(find.textContaining('Awaiting driver GPS'), findsOneWidget);
      if (state == 'requested') {
        expect(
            find.textContaining('NOT a confirmed ambulance'), findsOneWidget,);
      }
      expect(find.text('Share GPS (keep screen open)'), findsNothing);
      expect(find.text('Driver registration'), findsNothing);
      expect(find.text('Hospital driver approvals'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      dio.close();
    });
  }
}
