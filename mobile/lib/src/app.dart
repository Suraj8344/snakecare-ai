import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:snakecare_mobile/src/core/localization/app_localizations.dart';
import 'package:snakecare_mobile/src/core/routing/app_router.dart';
import 'package:snakecare_mobile/src/core/theme/app_theme.dart';

class SnakeCareApp extends ConsumerWidget {
  const SnakeCareApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'SnakeCare AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
      locale: ref.watch(appLocaleProvider),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => Stack(
        children: [
          child ?? const SizedBox.shrink(),
          const Positioned(
            right: 14,
            bottom: 14,
            child: SafeArea(child: GlobalLanguageButton()),
          ),
        ],
      ),
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
