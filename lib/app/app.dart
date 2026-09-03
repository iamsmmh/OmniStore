import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dynamic_color/dynamic_color.dart';

import 'package:omnistore/core/theme/app_theme.dart';
import 'package:omnistore/core/di/providers.dart';
import 'package:omnistore/core/di/router_provider.dart';
import 'package:omnistore/core/constants/app_constants.dart';

class OmniStoreApp extends ConsumerWidget {
  const OmniStoreApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(routerProvider);
    final useDynamicColor = ref.watch(dynamicColorProvider);

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final lightColorScheme = useDynamicColor && lightDynamic != null
            ? lightDynamic
            : AppTheme.lightColorScheme;
        final darkColorScheme = useDynamicColor && darkDynamic != null
            ? darkDynamic
            : AppTheme.darkColorScheme;

        return MaterialApp.router(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,
          theme: AppTheme.light(darkColorScheme),
          darkTheme: AppTheme.dark(darkColorScheme),
          routerConfig: router,
        );
      },
    );
  }
}
