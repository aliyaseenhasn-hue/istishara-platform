import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:astshara/shared/widgets/main_bottom_nav.dart';

void main() {
  testWidgets('lawyer navigation exposes notifications and every secondary destination', (tester) async {
    final router = GoRouter(
      initialLocation: '/lawyer-home',
      routes: [
        GoRoute(
          path: '/lawyer-home',
          builder: (_, __) => const _NavHost(),
        ),
        for (final path in [
          '/bookings',
          '/notifications',
          '/app-settings',
          '/lawyer-profile-edit',
          '/lawyer-availability',
          '/lawyer-wallet',
        ])
          GoRoute(
            path: path,
            builder: (_, state) => Scaffold(body: Text(state.uri.path, key: const Key('destination'))),
          ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('ar'),
        ),
      ),
    );

    expect(find.text('التنبيهات'), findsOneWidget);
    expect(find.text('استشاراتي'), findsOneWidget);
    expect(find.text('الإعدادات'), findsOneWidget);

    await tester.tap(find.text('التنبيهات'));
    await tester.pumpAndSettle();
    expect(find.text('/notifications'), findsOneWidget);
  });

  testWidgets('client navigation keeps all existing destinations', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            bottomNavigationBar: MainBottomNav(currentIndex: 0),
          ),
        ),
      ),
    );

    expect(find.text('الرئيسية'), findsOneWidget);
    expect(find.text('المحامون'), findsOneWidget);
    expect(find.text('استشاراتي'), findsOneWidget);
    expect(find.text('الإعدادات'), findsOneWidget);
  });

  testWidgets('lawyer navigation remains usable in dark mode with large text', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: const MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              bottomNavigationBar: MainBottomNav(currentIndex: 2, isLawyer: true),
            ),
          ),
        ),
      ),
    );

    expect(find.text('التنبيهات'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _NavHost extends StatelessWidget {
  const _NavHost();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      bottomNavigationBar: MainBottomNav(currentIndex: 0, isLawyer: true),
    );
  }
}
