import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:aula_puntos_senati/data/local_store.dart';
import 'package:aula_puntos_senati/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('es');
  });

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('persists records when a store is reopened', () async {
    final first = await LocalStore.create();
    await first.save('groups', {
      'code': 'G-01',
      'name': 'Electrónica',
      'period': '2026-I',
    });

    final reopened = await LocalStore.create();
    expect(reopened.activeGroups, 1);
    expect(reopened.all('groups').single['name'], 'Electrónica');
  });

  test('upserts attendance for the same student and session', () async {
    final store = await LocalStore.create();
    await store.save('attendance', {
      'sessionId': 'ses-1',
      'studentId': 'est-1',
      'status': 'Falta',
    });
    await store.save('attendance', {
      'sessionId': 'ses-1',
      'studentId': 'est-1',
      'status': 'Presente',
    });

    expect(store.all('attendance'), hasLength(1));
    expect(store.all('attendance').single['status'], 'Presente');
  });

  test('calculates totals from stored participation', () async {
    final store = await LocalStore.create();
    await store.save('participation', {
      'sessionId': 'ses-1',
      'studentId': 'est-1',
      'points': 3,
    });
    await store.save('participation', {
      'sessionId': 'ses-1',
      'studentId': 'est-2',
      'points': 4,
    });
    expect(store.pointsTotal, 7);
    expect(store.studentPoints('est-1'), 3);
  });

  test('deduplicates retried participation writes by operation id', () async {
    final store = await LocalStore.create();
    const operationId = 'operation-1';
    final participation = {
      'operationId': operationId,
      'sessionId': 'ses-1',
      'studentId': 'est-1',
      'activity': 'Ejercicio',
      'points': 2,
    };
    await store.save('participation', participation);
    await store.save('participation', participation);

    expect(store.all('participation'), hasLength(1));
    expect(
      store.all('outbox').where((e) => e['operationId'] == operationId),
      hasLength(1),
    );
    expect(store.all('audit'), hasLength(1));
  });

  test('seeds SENATI academic dataset when seedIfEmpty is enabled', () async {
    final store = await LocalStore.create(seedIfEmpty: true);
    expect(store.activeGroups, greaterThanOrEqualTo(3));
    expect(store.activeStudents, greaterThanOrEqualTo(14));
    expect(store.sessionCount, greaterThanOrEqualTo(5));
    expect(store.pointsTotal, greaterThan(0));
    expect(store.all('groups').any((g) => g['code'] == '202601'), isTrue);
    expect(
      store.all('students').any((st) => st['code'] == '001507084'),
      isTrue,
    );
  });

  testWidgets(
    'requires login and navigates across all modules on mobile 360px',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = await LocalStore.create(
        seedIfEmpty: true,
        requireLogin: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [localStoreProvider.overrideWith((ref) => store)],
          child: const AulaPuntosApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Verifica que aparece el Login antes de ingresar
      expect(find.text('Ingresar al Panel'), findsOneWidget);

      await tester.tap(find.text('Ingresar al Panel'));
      await tester.pumpAndSettle();

      // Ya dentro del Panel en pantalla de celular (360x780)
      expect(find.textContaining('Jorge Luque Chambi'), findsWidgets);

      // Navegar a Grupos, Estudiantes, Sesiones y Asistencia en móvil sin overflows
      await tester.tap(find.text('Grupos').last);
      await tester.pumpAndSettle();
      expect(find.text('Grupos SENATI'), findsOneWidget);

      await tester.tap(find.text('Estudiantes').last);
      await tester.pumpAndSettle();
      expect(find.text('Estudiantes'), findsWidgets);

      await tester.tap(find.text('Sesiones').last);
      await tester.pumpAndSettle();
      expect(find.text('Sesiones académicas'), findsOneWidget);

      // Abrir el selector de grupo en Sesiones en pantalla de 360px
      await tester.tap(find.text('Todos los grupos'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('202601').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Asistencia').last);
      await tester.pumpAndSettle();
      expect(find.text('Control de asistencia'), findsOneWidget);
      expect(find.text('1. Curso / Grupo académico'), findsOneWidget);
      expect(find.text('2. Fecha de asistencia (Sesión)'), findsOneWidget);
      expect(find.text('Elegir otra fecha'), findsOneWidget);
    },
  );
}
