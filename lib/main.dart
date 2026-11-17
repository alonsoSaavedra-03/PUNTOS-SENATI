import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'data/local_store.dart';
import 'features/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  final store = await LocalStore.create(seedIfEmpty: true, requireLogin: true);
  unawaited(store.checkServerHealth());
  runApp(
    ProviderScope(
      overrides: [localStoreProvider.overrideWith((ref) => store)],
      child: const AulaPuntosApp(),
    ),
  );
}

final routerProvider = Provider<GoRouter>(
  (ref) => GoRouter(
    initialLocation: '/',
    routes: [
      for (final path in [
        '/',
        '/login',
        '/grupos',
        '/estudiantes',
        '/sesiones',
        '/asistencia',
        '/puntuacion',
        '/reportes',
        '/configuracion',
      ])
        GoRoute(
          path: path,
          builder: (context, state) => HomeShell(location: path),
        ),
    ],
  ),
);

class AulaPuntosApp extends ConsumerWidget {
  const AulaPuntosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final store = ref.watch(
      localStoreProvider.select((s) => (darkMode: s.darkMode)),
    );
    return MaterialApp.router(
      title: 'Aula Puntos – SENATI',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es'), Locale('en')],
      locale: const Locale('es'),
      themeMode: store.darkMode ? ThemeMode.dark : ThemeMode.light,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      routerConfig: router,
    );
  }
}

ThemeData _theme(Brightness brightness) {
  const navy = Color(0xFF12355B);
  final scheme = ColorScheme.fromSeed(seedColor: navy, brightness: brightness);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: brightness == Brightness.light
        ? const Color(0xFFF5F7FA)
        : null,
    appBarTheme: const AppBarTheme(centerTitle: false),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0x140D2945)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
  );
}
