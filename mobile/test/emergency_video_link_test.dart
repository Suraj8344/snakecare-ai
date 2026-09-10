import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snakecare_mobile/src/core/widgets/emergency_video_link.dart';

void main() {
  testWidgets('video is opt-in and written guidance fallback is clear',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: EmergencyVideoLink(videoId: 'fd42XW9RJeE')),),);
    expect(find.text('Watch on YouTube'), findsOneWidget);
    expect(find.text('Copy video link'), findsOneWidget);
    expect(find.textContaining('Internet is required'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
