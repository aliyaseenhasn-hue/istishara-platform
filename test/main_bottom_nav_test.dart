import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:astshara/shared/widgets/main_bottom_nav.dart';
import 'package:astshara/shared/widgets/lawyer_more_menu_button.dart';

void main() {
  testWidgets('lawyer navigation keeps notifications off the bottom bar', (tester) async {
    final router = GoRouter(
      initialLocation: '/lawyer-home',
      routes: [
        GoRoute(
          path: '/lawyer-home',
          builder: (_, __) => const _NavHost(),
        ),
        for (final path in [
          '/bookings',
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

    expect(find.text('التنبيهات'), findsNothing);
    expect(find.text('الرئيسية'), findsOneWidget);
    expect(find.text('استشاراتي'), findsOneWidget);
    expect(find.text('الملف المهني'), findsOneWidget);
    expect(find.text('الإعدادات'), findsOneWidget);
    expect(find.byTooltip('المزيد من أدوات المحامي'), findsNothing);

    await tester.tap(find.text('الإعدادات'));
    await tester.pumpAndSettle();
    expect(find.text('/app-settings'), findsOneWidget);
  });

  testWidgets('lawyer home menu keeps professional profile out of secondary tools', (tester) async {
    final router = GoRouter(
      initialLocation: '/lawyer-home',
      routes: [
        GoRoute(
          path: '/lawyer-home',
          builder: (_, __) => const Scaffold(
            appBar: _TestLawyerAppBar(),
          ),
        ),
        for (final path in ['/lawyer-availability', '/lawyer-wallet'])
          GoRoute(
            path: path,
            builder: (_, state) => Scaffold(body: Text(state.uri.path)),
          ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.byTooltip('المزيد من أدوات المحامي'));
    await tester.pumpAndSettle();

    expect(find.text('ملفي المهني'), findsNothing);
    expect(find.text('أوقات التوفر'), findsOneWidget);
    expect(find.text('المحفظة'), findsOneWidget);

    await tester.tap(find.text('المحفظة'));
    await tester.pumpAndSettle();
    expect(find.text('/lawyer-wallet'), findsOneWidget);
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
              bottomNavigationBar: MainBottomNav(currentIndex: 3, isLawyer: true),
            ),
          ),
        ),
      ),
    );

    expect(find.text('التنبيهات'), findsNothing);
    expect(find.text('الإعدادات'), findsOneWidget);
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

class _TestLawyerAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _TestLawyerAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      leading: const LawyerMoreMenuButton(),
      title: const Text('الرئيسية'),
    );
  }
}
