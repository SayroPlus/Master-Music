import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:music_organizer/app.dart';

void main() {
  testWidgets('App renders onboarding screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MusicOrganizerApp(showOnboarding: true),
      ),
    );

    await tester.pumpAndSettle();

    // Verify the onboarding screen is shown
    expect(find.text('Welcome to Music Organizer'), findsOneWidget);
  });

  testWidgets('App renders main shell when onboarding complete',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MusicOrganizerApp(showOnboarding: false),
      ),
    );

    await tester.pumpAndSettle();

    // Verify the bottom navigation is shown
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Organize'), findsOneWidget);
    expect(find.text('Stats'), findsOneWidget);
    expect(find.text('Player'), findsOneWidget);
  });
}
