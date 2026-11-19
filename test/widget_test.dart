import 'package:dreamtide/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('age gate blocks the app until adult confirmation', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ProviderScope(child: DreamtideApp()));
    await tester.pumpAndSettle();

    expect(find.text('触梦 · Dreamtide'), findsOneWidget);
    expect(find.text('我已成年，进入梦境'), findsOneWidget);

    await tester.tap(find.text('我已成年，进入梦境'));
    await tester.pumpAndSettle();

    expect(find.text('消息'), findsOneWidget);
    expect(find.text('联系人'), findsOneWidget);
    expect(find.text('动态'), findsOneWidget);
    expect(find.byKey(const ValueKey('root-bottom-bar')), findsOneWidget);
  });

  testWidgets('chat is a full-screen route without root navigation', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ProviderScope(child: DreamtideApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('我已成年，进入梦境'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('顾言').first);
    await tester.pumpAndSettle();

    expect(find.text('顾言'), findsWidgets);
    expect(find.byKey(const ValueKey('root-bottom-bar')), findsNothing);
    expect(find.text('说点什么……'), findsOneWidget);
  });
}
