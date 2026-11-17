import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:uuid/uuid.dart';

import '../data/local_store.dart';

enum _Page {
  dashboard,
  groups,
  students,
  sessions,
  attendance,
  points,
  reports,
  settings,
}

const _titles = [
  'Panel',
  'Grupos',
  'Estudiantes',
  'Sesiones',
  'Asistencia',
  'Puntuación',
  'Reportes',
  'Configuración',
];

const _icons = [
  Icons.dashboard_rounded,
  Icons.groups_rounded,
  Icons.school_rounded,
  Icons.event_note_rounded,
  Icons.fact_check_rounded,
  Icons.stars_rounded,
  Icons.bar_chart_rounded,
  Icons.settings_rounded,
];

const _paths = [
  '/',
  '/grupos',
  '/estudiantes',
  '/sesiones',
  '/asistencia',
  '/puntuacion',
  '/reportes',
  '/configuracion',
];

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.location});
  final String location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuthenticated = ref.watch(
      localStoreProvider.select((s) => s.isAuthenticated),
    );
    if (!isAuthenticated || location == '/login') {
      return const _LoginScreen();
    }

    final isOnline = ref.watch(localStoreProvider.select((s) => s.isOnline));
    final isSyncing = ref.watch(localStoreProvider.select((s) => s.isSyncing));
    final pending = ref.watch(
      localStoreProvider.select((s) => s.pendingOutboxCount),
    );
    final apiUrl = ref.watch(localStoreProvider.select((s) => s.apiUrl));
    final store = ref.read(localStoreProvider);

    final rawIndex = _paths.indexOf(location);
    final index = (rawIndex < 0 ? 0 : rawIndex).clamp(
      0,
      _Page.values.length - 1,
    );
    final page = _Page.values[index];
    final screenWidth = MediaQuery.sizeOf(context).width;
    final wide = screenWidth >= 900;
    final compactAppBar = screenWidth < 520;

    final body = _PageView(
      page: page,
      onNavigate: (p) => context.go(_paths[p.index]),
    );

    return Scaffold(
      appBar: AppBar(
        titleSpacing: compactAppBar ? 12 : 16,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.school, color: Colors.white, size: 19),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Aula Puntos',
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: compactAppBar ? 16 : 19,
                ),
              ),
            ),
            if (!compactAppBar) ...[
              const SizedBox(width: 8),
              const Text(
                'SENATI',
                style: TextStyle(fontSize: 12, letterSpacing: 1.3),
              ),
            ],
          ],
        ),
        actions: [
          if (compactAppBar)
            IconButton(
              tooltip: isOnline
                  ? 'MySQL conectado. Pulsa para sincronizar.'
                  : 'Modo local ($pending pend.). Pulsa para sincronizar con MySQL.',
              onPressed: isSyncing
                  ? null
                  : () async {
                      final res = await store.syncWithServer();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(res.message)));
                      }
                    },
              icon: isSyncing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      isOnline ? Icons.storage_rounded : Icons.sync_rounded,
                      color: isOnline ? const Color(0xFF159B8A) : null,
                    ),
            )
          else
            Tooltip(
              message: isOnline
                  ? 'MySQL conectado ($apiUrl). Pulsa para sincronizar.'
                  : 'Modo local ($pending pendientes). Pulsa para sincronizar con MySQL.',
              child: ActionChip(
                avatar: isSyncing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        isOnline ? Icons.storage_rounded : Icons.cloud_off,
                        size: 15,
                        color: isOnline ? const Color(0xFF159B8A) : null,
                      ),
                label: Text(
                  isOnline
                      ? (pending > 0 ? 'MySQL ($pending)' : 'MySQL Activo')
                      : (pending > 0 ? 'Local ($pending)' : 'Modo Local'),
                ),
                visualDensity: VisualDensity.compact,
                onPressed: isSyncing
                    ? null
                    : () async {
                        final res = await store.syncWithServer();
                        if (context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(res.message)));
                        }
                      },
              ),
            ),
          if (!wide)
            PopupMenuButton<String>(
              tooltip: 'Más opciones',
              onSelected: (value) async {
                if (value == 'logout') {
                  await store.logout();
                  if (context.mounted) context.go('/');
                } else {
                  final target = _Page.values.firstWhere(
                    (p) => p.name == value,
                  );
                  context.go(_paths[target.index]);
                }
              },
              itemBuilder: (context) => [
                for (final p in [_Page.points, _Page.reports, _Page.settings])
                  PopupMenuItem(
                    value: p.name,
                    child: Row(
                      children: [
                        Icon(_icons[p.index], size: 18),
                        const SizedBox(width: 8),
                        Text(_titles[p.index]),
                      ],
                    ),
                  ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Cerrar sesión'),
                    ],
                  ),
                ),
              ],
            )
          else
            IconButton(
              tooltip: 'Cerrar sesión',
              icon: const Icon(Icons.logout_rounded),
              onPressed: () async {
                await store.logout();
                if (context.mounted) context.go('/');
              },
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Row(
        children: [
          if (wide)
            NavigationRail(
              backgroundColor: Theme.of(context).colorScheme.surface,
              selectedIndex: page.index,
              onDestinationSelected: (i) => context.go(_paths[i]),
              labelType: NavigationRailLabelType.all,
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Icon(Icons.menu_book_rounded),
              ),
              destinations: List.generate(
                _titles.length,
                (i) => NavigationRailDestination(
                  icon: Icon(_icons[i]),
                  label: Text(_titles[i]),
                ),
              ),
            ),
          Expanded(child: body),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: page.index < 5 ? page.index : 0,
              onDestinationSelected: (i) => context.go(_paths[i]),
              destinations: List.generate(
                5,
                (i) => NavigationDestination(
                  icon: Icon(_icons[i]),
                  label: _titles[i],
                ),
              ),
            ),
    );
  }
}

// ============================================================================
// PANTALLA DE LOGIN INSTITUCIONAL SENATI (CONECTADA A MYSQL)
// ============================================================================
class _LoginScreen extends ConsumerStatefulWidget {
  const _LoginScreen();

  @override
  ConsumerState<_LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<_LoginScreen> {
  final _userCtrl = TextEditingController(text: 'jluque@senati.pe');
  final _passCtrl = TextEditingController(text: '123456');
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final store = ref.read(localStoreProvider);
    final result = await store.login(_userCtrl.text, _passCtrl.text);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (!result.ok) _error = result.message;
    });
    if (result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 1600),
          content: Text(result.message),
        ),
      );
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(localStoreProvider.select((s) => s.isOnline));
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 600;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D2744), Color(0xFF163D70), Color(0xFF1E4E8C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 16 : 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(isMobile ? 22 : 30),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFF12355B),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.school_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'AULA PUNTOS – SENATI',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.4,
                                        ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Escuela de Tecnologías de la Información',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isOnline
                                    ? Icons.check_circle_rounded
                                    : Icons.storage_rounded,
                                size: 16,
                                color: isOnline
                                    ? const Color(0xFF159B8A)
                                    : const Color(0xFF3167BD),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  isOnline
                                      ? 'Base de datos MySQL activa (aula_puntos_senati)'
                                      : 'Almacenamiento híbrido MySQL / Local listo',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _userCtrl,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Usuario o correo institucional',
                            prefixIcon: Icon(Icons.person_outline),
                            hintText: 'jluque@senati.pe',
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _passCtrl,
                          obscureText: _obscure,
                          onSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              tooltip: _obscure
                                  ? 'Mostrar contraseña'
                                  : 'Ocultar contraseña',
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _loading ? null : _submit,
                          icon: _loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.login_rounded),
                          label: Text(
                            _loading
                                ? 'Verificando credenciales...'
                                : 'Ingresar al Panel',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Divider(),
                        const SizedBox(height: 8),
                        Text(
                          'Cuentas configuradas en MySQL (pulsa para autocompletar):',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ActionChip(
                              avatar: const Icon(Icons.school, size: 15),
                              label: const Text('Instructor (jluque / 123456)'),
                              visualDensity: VisualDensity.compact,
                              onPressed: () => setState(() {
                                _userCtrl.text = 'jluque@senati.pe';
                                _passCtrl.text = '123456';
                                _error = null;
                              }),
                            ),
                            ActionChip(
                              avatar: const Icon(
                                Icons.admin_panel_settings_outlined,
                                size: 15,
                              ),
                              label: const Text('Admin (admin / admin123)'),
                              visualDensity: VisualDensity.compact,
                              onPressed: () => setState(() {
                                _userCtrl.text = 'admin@senati.pe';
                                _passCtrl.text = 'admin123';
                                _error = null;
                              }),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PageView extends StatelessWidget {
  const _PageView({required this.page, required this.onNavigate});
  final _Page page;
  final ValueChanged<_Page> onNavigate;

  @override
  Widget build(BuildContext context) => switch (page) {
    _Page.dashboard => _Dashboard(onNavigate: onNavigate),
    _Page.groups => _GroupsPage(onNavigate: onNavigate),
    _Page.students => const _StudentsPage(),
    _Page.sessions => _SessionPage(onNavigate: onNavigate),
    _Page.attendance => const _AttendancePage(),
    _Page.points => const _PointsPage(),
    _Page.reports => const _ReportsPage(),
    _Page.settings => const _SettingsPage(),
  };
}

class _Content extends StatelessWidget {
  const _Content({
    required this.title,
    required this.subtitle,
    required this.child,
    this.action,
  });
  final String title, subtitle;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final isMobile = box.maxWidth < 600;
      return SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 14 : 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isMobile) ...[
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (action != null) ...[
                    const SizedBox(height: 12),
                    SizedBox(width: double.infinity, child: action!),
                  ],
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              subtitle,
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (action != null) ...[
                        const SizedBox(width: 16),
                        action!,
                      ],
                    ],
                  ),
                SizedBox(height: isMobile ? 16 : 24),
                child,
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _Dashboard extends ConsumerWidget {
  const _Dashboard({required this.onNavigate});
  final ValueChanged<_Page> onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(localStoreProvider);
    final recent = s.all('sessions').reversed.take(5).toList();
    final instructorName = s.instructor['name'] ?? 'Instructor';
    final instructorRole =
        s.instructor['role'] ?? 'Escuela de Tecnologías de la Información';

    final rankedStudents = [
      for (final st in s.where('students', (e) => e['active'] != false))
        (
          student: st,
          points: s.studentPoints(st['id'] as String),
          attendance: s
              .studentAttendanceSummary(st['id'] as String)
              .attendanceRate,
        ),
    ]..sort((a, b) => b.points.compareTo(a.points));

    String formattedDate;
    try {
      formattedDate = DateFormat(
        'EEEE, d MMMM yyyy',
        'es',
      ).format(DateTime.now());
    } catch (_) {
      formattedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    }

    return _Content(
      title: '¡Bienvenido, $instructorName!',
      subtitle: '$instructorRole · $formattedDate',
      action: FilledButton.tonalIcon(
        onPressed: () => onNavigate(_Page.attendance),
        icon: const Icon(Icons.fact_check_outlined),
        label: const Text('Tomar asistencia'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF12355B), Color(0xFF1E4E8C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Wrap(
              spacing: 16,
              runSpacing: 14,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'PANEL DEL INSTRUCTOR · SENATI',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Control Académico & Puntuación',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Optimizado para sesiones de teoría, taller y laboratorio · ${s.instructor['campus'] ?? 'SENATI'}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF12355B),
                      ),
                      onPressed: () => onNavigate(_Page.points),
                      icon: const Icon(Icons.stars_rounded),
                      label: const Text('Puntuación Rápida'),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                      ),
                      onPressed: () => onNavigate(_Page.reports),
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('Reportes y PDF'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _ResponsiveMetricsWrap(
            metrics: [
              _MetricData(
                title: 'Grupos activos',
                value: '${s.activeGroups}',
                icon: Icons.groups,
                color: const Color(0xff3167bd),
                onTap: () => onNavigate(_Page.groups),
              ),
              _MetricData(
                title: 'Estudiantes',
                value: '${s.activeStudents}',
                icon: Icons.school,
                color: const Color(0xff159b8a),
                onTap: () => onNavigate(_Page.students),
              ),
              _MetricData(
                title: 'Sesiones',
                value: '${s.sessionCount}',
                icon: Icons.event_available,
                color: const Color(0xff7857c5),
                onTap: () => onNavigate(_Page.sessions),
              ),
              _MetricData(
                title:
                    'Asistencias (${s.globalAttendancePercentage.toStringAsFixed(0)}%)',
                value: '${s.attendanceCount}',
                icon: Icons.fact_check,
                color: const Color(0xffd58835),
                onTap: () => onNavigate(_Page.attendance),
              ),
              _MetricData(
                title: 'Puntos acumulados',
                value: '${s.pointsTotal}',
                icon: Icons.stars,
                color: const Color(0xffd15b6b),
                onTap: () => onNavigate(_Page.points),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            'Accesos rápidos',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in [
                _Page.groups,
                _Page.students,
                _Page.sessions,
                _Page.attendance,
                _Page.points,
                _Page.reports,
                _Page.settings,
              ])
                OutlinedButton.icon(
                  onPressed: () => onNavigate(p),
                  icon: Icon(_icons[p.index], size: 18),
                  label: Text(_titles[p.index]),
                ),
            ],
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoCols = constraints.maxWidth >= 820;
              final sessionsSection = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Sesiones recientes',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      TextButton(
                        onPressed: () => onNavigate(_Page.sessions),
                        child: const Text('Ver todas'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: recent.isEmpty
                        ? const _Empty(
                            text: 'Aún no hay sesiones. Crea una para empezar.',
                          )
                        : Column(
                            children: [
                              for (final row in recent)
                                ListTile(
                                  leading: CircleAvatar(
                                    child: Text(
                                      'S${row['sessionNumber'] ?? 1}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    row['topic'] ?? 'Sesión',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${s.byId('groups', row['groupId'] as String?)?['code'] ?? ''} · ${row['date'] ?? ''} · ${row['type'] ?? 'Teoría'}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'Tomar asistencia',
                                        icon: const Icon(
                                          Icons.fact_check_outlined,
                                          size: 20,
                                        ),
                                        onPressed: () {
                                          s.selectSessionAndNavigate(
                                            row['id'] as String?,
                                          );
                                          onNavigate(_Page.attendance);
                                        },
                                      ),
                                      IconButton(
                                        tooltip: 'Puntuar participación',
                                        icon: const Icon(
                                          Icons.stars_outlined,
                                          size: 20,
                                        ),
                                        onPressed: () {
                                          s.selectSessionAndNavigate(
                                            row['id'] as String?,
                                          );
                                          onNavigate(_Page.points);
                                        },
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    s.selectSessionAndNavigate(
                                      row['id'] as String?,
                                    );
                                    onNavigate(_Page.attendance);
                                  },
                                ),
                            ],
                          ),
                  ),
                ],
              );

              final rankingSection = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Estudiantes destacados',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      TextButton(
                        onPressed: () => onNavigate(_Page.reports),
                        child: const Text('Consolidado'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: rankedStudents.isEmpty
                        ? const _Empty(
                            text: 'No hay estudiantes registrados todavía.',
                          )
                        : Column(
                            children: [
                              for (final entry in rankedStudents.take(5))
                                ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .primaryContainer,
                                    child: Text(
                                      _initials(
                                        entry.student['name']?.toString() ?? '',
                                      ),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    entry.student['name']?.toString() ?? '—',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    'ID: ${entry.student['code']} · ${s.byId('groups', entry.student['groupId'] as String?)?['code'] ?? ''}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: Chip(
                                    label: Text(
                                      '${entry.points} pts',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                            ],
                          ),
                  ),
                ],
              );

              if (!twoCols) {
                return Column(
                  children: [
                    sessionsSection,
                    const SizedBox(height: 20),
                    rankingSection,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 6, child: sessionsSection),
                  const SizedBox(width: 20),
                  Expanded(flex: 5, child: rankingSection),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

String _initials(String fullName) {
  final parts = fullName
      .replaceAll(',', ' ')
      .split(RegExp(r'\s+'))
      .where((e) => e.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'ES';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}

class _MetricData {
  const _MetricData({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });
  final String title, value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
}

class _ResponsiveMetricsWrap extends StatelessWidget {
  const _ResponsiveMetricsWrap({required this.metrics});
  final List<_MetricData> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final double cardWidth;
        if (box.maxWidth < 520) {
          cardWidth = (box.maxWidth - 12) / 2;
        } else if (box.maxWidth < 800) {
          cardWidth = (box.maxWidth - 24) / 3;
        } else {
          cardWidth = 215;
        }
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final m in metrics)
              _Metric(
                width: cardWidth.clamp(135.0, 260.0),
                title: m.title,
                value: m.value,
                icon: m.icon,
                color: m.color,
                onTap: m.onTap,
              ),
          ],
        );
      },
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.width = 215,
    this.onTap,
  });
  final String title, value;
  final IconData icon;
  final Color color;
  final double width;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: color.withValues(alpha: .13),
                foregroundColor: color,
                child: Icon(icon, size: 20),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(28),
    child: Center(
      child: Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 38,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );
}

// ============================================================================
// MÓDULO DE GRUPOS SENATI
// ============================================================================
class _GroupsPage extends ConsumerStatefulWidget {
  const _GroupsPage({required this.onNavigate});
  final ValueChanged<_Page> onNavigate;

  @override
  ConsumerState<_GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends ConsumerState<_GroupsPage> {
  String search = '';

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(localStoreProvider);
    final rows = s
        .all('groups')
        .where(
          (e) =>
              '${e['code']} ${e['name']} ${e['program'] ?? ''} ${e['section'] ?? ''}'
                  .toLowerCase()
                  .contains(search.toLowerCase()),
        )
        .toList();

    return _Content(
      title: 'Grupos SENATI',
      subtitle: 'Administra tus grupos, asignaturas, programas académicos y secciones.',
      action: FilledButton.icon(
        onPressed: () => _editGroup(context, s, null),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Grupo'),
      ),
      child: Column(
        children: [
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Buscar por código (ej. 202601), asignatura o sección',
            ),
            onChanged: (v) => setState(() => search = v),
          ),
          const SizedBox(height: 14),
          if (rows.isEmpty)
            const Card(
              child: _Empty(
                text: 'No hay grupos registrados. Crea un grupo para comenzar.',
              ),
            )
          else
            Column(
              children: [
                for (final row in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildGroupCard(context, s, row),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildGroupCard(
    BuildContext context,
    LocalStore s,
    Map<String, dynamic> row,
  ) {
    final groupId = row['id'] as String;
    final studentCount = s
        .where(
          'students',
          (e) => e['active'] != false && e['groupId'] == groupId,
        )
        .length;
    final sessionCount = s
        .where('sessions', (e) => e['groupId'] == groupId)
        .length;
    final program = row['program']?.toString().isNotEmpty == true
        ? row['program']
        : (row['period'] ?? '2026-20');
    final section = row['section']?.toString().isNotEmpty == true
        ? row['section']
        : '${row['period'] ?? '2026-20'}-${row['code'] ?? ''}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .primaryContainer,
                  child: const Icon(Icons.groups_rounded),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${row['code'] ?? ''} · ${row['name'] ?? 'Grupo'}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Programa: $program | Periodo: ${row['period'] ?? '2026-20'} | Sección: $section',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Editar',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _editGroup(context, s, row),
                ),
                IconButton(
                  tooltip: 'Eliminar',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _deleteGroup(context, s, row),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(
                  avatar: const Icon(Icons.school_outlined, size: 16),
                  label: Text('$studentCount estudiantes'),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  avatar: const Icon(Icons.event_note_outlined, size: 16),
                  label: Text('$sessionCount sesiones'),
                  visualDensity: VisualDensity.compact,
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    s.setGroupFilter(groupId);
                    widget.onNavigate(_Page.students);
                  },
                  icon: const Icon(Icons.people_outline, size: 18),
                  label: const Text('Integrantes'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () {
                    s.setGroupFilter(groupId);
                    widget.onNavigate(_Page.sessions);
                  },
                  icon: const Icon(Icons.event_available_outlined, size: 18),
                  label: const Text('Sesiones'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editGroup(
    BuildContext context,
    LocalStore s,
    Map<String, dynamic>? old,
  ) async {
    final codeCtrl = TextEditingController(
      text: old?['code']?.toString() ?? '',
    );
    final nameCtrl = TextEditingController(
      text: old?['name']?.toString() ?? '',
    );
    final programCtrl = TextEditingController(
      text: old?['program']?.toString() ?? '2026-20',
    );
    final periodCtrl = TextEditingController(
      text: old?['period']?.toString() ?? '2026-20',
    );
    final sectionCtrl = TextEditingController(
      text: old?['section']?.toString() ?? '',
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(old == null ? 'Nuevo Grupo SENATI' : 'Editar Grupo SENATI'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Código / Nombre del Grupo (ej. 202601)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Asignatura / Curso',
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: programCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Programa Académico (ej. 2026-20)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: periodCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Periodo Académico (ej. 2026-II / 2026-20)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: sectionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Código de Sección (opcional)',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (ok == true) {
      final code = codeCtrl.text.trim();
      final name = nameCtrl.text.trim();
      final program = programCtrl.text.trim();
      final period = periodCtrl.text.trim();
      final section = sectionCtrl.text.trim().isEmpty
          ? '$period-$code'
          : sectionCtrl.text.trim();
      final duplicate = s
          .all('groups')
          .any(
            (e) =>
                e['id'] != old?['id'] &&
                (e['code'] as String? ?? '').toLowerCase() ==
                    code.toLowerCase(),
          );
      if (code.isEmpty || name.isEmpty || duplicate) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Completa el código único y el nombre de la asignatura.',
              ),
            ),
          );
        }
      } else {
        await s.save('groups', {
          ...?old,
          'code': code,
          'name': name,
          'program': program,
          'period': period,
          'section': section,
          'active': true,
        });
      }
    }

    codeCtrl.dispose();
    nameCtrl.dispose();
    programCtrl.dispose();
    periodCtrl.dispose();
    sectionCtrl.dispose();
  }

  Future<void> _deleteGroup(
    BuildContext context,
    LocalStore s,
    Map<String, dynamic> row,
  ) async {
    final id = row['id'] as String;
    final hasLinked =
        s.all('students').any((e) => e['groupId'] == id) ||
        s.all('sessions').any((e) => e['groupId'] == id);
    if (hasLinked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se puede eliminar: el grupo tiene estudiantes o sesiones asociadas.',
          ),
        ),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar grupo'),
        content: Text('¿Eliminar “${row['name']} (${row['code']})”?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) await s.remove('groups', id);
  }
}

// ============================================================================
// MÓDULO DE ESTUDIANTES (RESPONSIVO PC Y MÓVIL)
// ============================================================================
class _StudentsPage extends ConsumerStatefulWidget {
  const _StudentsPage();

  @override
  ConsumerState<_StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends ConsumerState<_StudentsPage> {
  String search = '';

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(localStoreProvider);
    final groups = s.all('groups');
    final activeFilter = groups.any((g) => g['id'] == s.selectedGroupFilter)
        ? s.selectedGroupFilter
        : null;

    final rows = s.all('students').where((e) {
      final matchesGroup = activeFilter == null || e['groupId'] == activeFilter;
      final matchesSearch = '${e['name']} ${e['code']} ${e['email'] ?? ''}'
          .toLowerCase()
          .contains(search.toLowerCase());
      return matchesGroup && matchesSearch;
    }).toList();

    return _Content(
      title: 'Estudiantes',
      subtitle: 'Consulta integrantes por grupo, revisa su historial de puntos y administra su matrícula.',
      action: FilledButton.icon(
        onPressed: groups.isEmpty ? null : () => _editStudent(context, s, null),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Nuevo Estudiante'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, box) {
              final searchField = TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Buscar por apellidos, nombres o ID (001507084)',
                ),
                onChanged: (v) => setState(() => search = v),
              );
              final groupDropdown = DropdownButtonFormField<String?>(
                key: ValueKey(activeFilter),
                isExpanded: true,
                initialValue: activeFilter,
                decoration: const InputDecoration(
                  labelText: 'Filtrar por grupo',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text(
                      'Todos los grupos',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  for (final g in groups)
                    DropdownMenuItem<String?>(
                      value: g['id'] as String,
                      child: Text(
                        '${g['code']} · ${g['name']}',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                ],
                onChanged: (v) => s.setGroupFilter(v),
              );

              if (box.maxWidth < 680) {
                return Column(
                  children: [
                    searchField,
                    const SizedBox(height: 12),
                    groupDropdown,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(flex: 3, child: searchField),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: groupDropdown),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Card(
            child: rows.isEmpty
                ? const _Empty(
                    text: 'No se encontraron estudiantes con los criterios seleccionados.',
                  )
                : Column(
                    children: [
                      for (var i = 0; i < rows.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        _buildStudentTile(context, s, rows[i]),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentTile(
    BuildContext context,
    LocalStore s,
    Map<String, dynamic> row,
  ) {
    final studentId = row['id'] as String;
    final pts = s.studentPoints(studentId);
    final att = s.studentAttendanceSummary(studentId);
    final group = s.byId('groups', row['groupId'] as String?);

    return InkWell(
      onTap: () => _showStudentHistory(context, s, row),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: LayoutBuilder(
          builder: (context, box) {
            final isNarrow = box.maxWidth < 560;
            final infoRow = Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .primaryContainer,
                  child: Text(
                    _initials(row['name']?.toString() ?? ''),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row['name'] ?? '—',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Código: ${row['code'] ?? ''} · Grupo: ${group?['code'] ?? '—'}${row['email']?.toString().isNotEmpty == true ? ' · ${row['email']}' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );

            final actionsRow = Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(
                  label: Text(
                    '$pts pts',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  label: Text(
                    '${att.attendanceRate.toStringAsFixed(0)}% asist.',
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  tooltip: 'Editar',
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: () => _editStudent(context, s, row),
                ),
                IconButton(
                  tooltip: 'Eliminar',
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => _deleteStudent(context, s, row),
                ),
              ],
            );

            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  infoRow,
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 52),
                    child: actionsRow,
                  ),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: infoRow),
                const SizedBox(width: 12),
                actionsRow,
              ],
            );
          },
        ),
      ),
    );
  }

  void _showStudentHistory(
    BuildContext context,
    LocalStore s,
    Map<String, dynamic> student,
  ) {
    final studentId = student['id'] as String;
    final att = s.studentAttendanceSummary(studentId);
    final pts = s.studentPoints(studentId);
    final participations = s
        .where('participation', (e) => e['studentId'] == studentId)
        .reversed
        .toList();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(student['name']?.toString() ?? 'Estudiante'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Código institucional: ${student['code']} · Grupo: ${s.label('groups', student['groupId'] as String?)}',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text('Total Puntos: $pts pts')),
                    Chip(label: Text('Presentes: ${att.present}')),
                    Chip(label: Text('Tardanzas: ${att.lateCount}')),
                    Chip(label: Text('Faltas: ${att.absent}')),
                    Chip(label: Text('Justificados: ${att.justified}')),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Historial de participaciones',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (participations.isEmpty)
                  const Text('Sin participaciones registradas aún.')
                else
                  for (final p in participations)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.stars_rounded, size: 20),
                      title: Text('${p['activity']} (+${p['points']} pts)'),
                      subtitle: Text(
                        '${s.label('sessions', p['sessionId'] as String?)} · ${p['date'] ?? ''}${p['note']?.toString().isNotEmpty == true ? ' · ${p['note']}' : ''}',
                      ),
                    ),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _editStudent(
    BuildContext context,
    LocalStore s,
    Map<String, dynamic>? old,
  ) async {
    final codeCtrl = TextEditingController(
      text: old?['code']?.toString() ?? '',
    );
    final nameCtrl = TextEditingController(
      text: old?['name']?.toString() ?? '',
    );
    final emailCtrl = TextEditingController(
      text: old?['email']?.toString() ?? '',
    );
    String? groupId =
        old?['groupId']?.toString() ??
        s.selectedGroupFilter ??
        s.all('groups').firstOrNull?['id']?.toString();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text(
            old == null ? 'Nuevo Estudiante SENATI' : 'Editar Estudiante',
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: codeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Código institucional (ej. 001507084)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Apellidos y nombres',
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Correo institucional (opcional)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: groupId,
                    decoration: const InputDecoration(
                      labelText: 'Grupo académico',
                    ),
                    items: [
                      for (final g in s.all('groups'))
                        DropdownMenuItem(
                          value: g['id'] as String,
                          child: Text(
                            '${g['code']} · ${g['name']}',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                    ],
                    onChanged: (v) => set(() => groupId = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      final code = codeCtrl.text.trim();
      final name = nameCtrl.text.trim();
      final email = emailCtrl.text.trim();
      final duplicate = s
          .all('students')
          .any(
            (e) =>
                e['id'] != old?['id'] &&
                (e['code'] as String? ?? '').toLowerCase() ==
                    code.toLowerCase(),
          );
      if (code.isEmpty || name.isEmpty || groupId == null || duplicate) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Completa los datos obligatorios, usa un código único y selecciona un grupo.',
              ),
            ),
          );
        }
      } else {
        await s.save('students', {
          ...?old,
          'code': code,
          'name': name,
          'email': email.isEmpty ? '$code@senati.pe' : email,
          'groupId': groupId,
          'active': true,
        });
      }
    }

    codeCtrl.dispose();
    nameCtrl.dispose();
    emailCtrl.dispose();
  }

  Future<void> _deleteStudent(
    BuildContext context,
    LocalStore s,
    Map<String, dynamic> row,
  ) async {
    final id = row['id'] as String;
    final hasLinked =
        s.all('attendance').any((e) => e['studentId'] == id) ||
        s.all('participation').any((e) => e['studentId'] == id);
    if (hasLinked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se puede eliminar: el estudiante tiene asistencias o puntos registrados.',
          ),
        ),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar estudiante'),
        content: Text('¿Eliminar a “${row['name']}”?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) await s.remove('students', id);
  }
}

// ============================================================================
// MÓDULO DE SESIONES ACADÉMICAS (SIN OVERFLOW EN SELECTOR DE GRUPO)
// ============================================================================
class _SessionPage extends ConsumerStatefulWidget {
  const _SessionPage({required this.onNavigate});
  final ValueChanged<_Page> onNavigate;

  @override
  ConsumerState<_SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends ConsumerState<_SessionPage> {
  @override
  Widget build(BuildContext context) {
    final s = ref.watch(localStoreProvider);
    final groups = s.all('groups');
    final activeFilter = groups.any((g) => g['id'] == s.selectedGroupFilter)
        ? s.selectedGroupFilter
        : null;

    final rows = s
        .all('sessions')
        .where((r) => activeFilter == null || r['groupId'] == activeFilter)
        .toList()
        .reversed
        .toList();

    return _Content(
      title: 'Sesiones académicas',
      subtitle: 'Organiza las sesiones de teoría, taller y laboratorio asociadas a cada grupo.',
      action: FilledButton.icon(
        onPressed: groups.isEmpty ? null : () => _editSession(context, s, null),
        icon: const Icon(Icons.add),
        label: const Text('Nueva sesión'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (groups.isNotEmpty) ...[
            DropdownButtonFormField<String?>(
              key: ValueKey(activeFilter),
              isExpanded: true,
              initialValue: activeFilter,
              decoration: const InputDecoration(
                labelText: 'Seleccionar Grupo – Sesiones',
                prefixIcon: Icon(Icons.groups_outlined),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text(
                    'Todos los grupos',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                for (final g in groups)
                  DropdownMenuItem<String?>(
                    value: g['id'] as String,
                    child: Text(
                      '${g['code']} · ${g['name']}',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
              ],
              onChanged: (v) => s.setGroupFilter(v),
            ),
            const SizedBox(height: 16),
          ],
          if (rows.isEmpty)
            const Card(
              child: _Empty(
                text: 'No hay sesiones registradas para este filtro. Crea una sesión para comenzar la clase.',
              ),
            )
          else
            Column(
              children: [
                for (final r in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildSessionCard(context, s, r),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(
    BuildContext context,
    LocalStore s,
    Map<String, dynamic> r,
  ) {
    final sessionId = r['id'] as String;
    final attRecords = s.where(
      'attendance',
      (e) => e['sessionId'] == sessionId,
    );
    final presentCount = attRecords
        .where((e) => e['status'] == 'Presente' || e['status'] == 'Justificado')
        .length;
    final ptsTotal = s.sessionPointsTotal(sessionId);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      r['type']?.toString() ?? 'Teoría (Tecnología)',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Sesión N° ${r['sessionNumber'] ?? 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Editar sesión',
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: () => _editSession(context, s, r),
                ),
                IconButton(
                  tooltip: 'Eliminar sesión',
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => _deleteSession(context, s, r),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              r['topic'] ?? 'Sesión',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Grupo: ${s.label('groups', r['groupId'] as String?)} · Fecha: ${r['date'] ?? ''} · Duración: ${r['durationHours'] ?? 4} horas',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (r['notes']?.toString().isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Text(
                'Obs: ${r['notes']}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(
                  label: Text(
                    'Asistencia: $presentCount/${attRecords.length} reg.',
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  label: Text('Puntos: +$ptsTotal pts'),
                  visualDensity: VisualDensity.compact,
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    s.selectSessionAndNavigate(sessionId);
                    widget.onNavigate(_Page.attendance);
                  },
                  icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                  label: const Text('Asistencia'),
                ),
                FilledButton.icon(
                  onPressed: () {
                    s.selectSessionAndNavigate(sessionId);
                    widget.onNavigate(_Page.points);
                  },
                  icon: const Icon(Icons.stars_rounded, size: 18),
                  label: const Text('Puntuación'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editSession(
    BuildContext context,
    LocalStore s,
    Map<String, dynamic>? old,
  ) async {
    String? group =
        old?['groupId']?.toString() ??
        s.selectedGroupFilter ??
        s.all('groups').first['id'] as String;
    final groupSessionsCount = s
        .where('sessions', (e) => e['groupId'] == group)
        .length;
    final numberCtrl = TextEditingController(
      text: '${old?['sessionNumber'] ?? (groupSessionsCount + 1)}',
    );
    final topicCtrl = TextEditingController(
      text: old?['topic']?.toString() ?? '',
    );
    final durationCtrl = TextEditingController(
      text: '${old?['durationHours'] ?? 4}',
    );
    final dateCtrl = TextEditingController(
      text:
          old?['date']?.toString() ??
          DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );
    final notesCtrl = TextEditingController(
      text: old?['notes']?.toString() ?? '',
    );
    const sessionTypes = [
      'Teoría (Tecnología)',
      'Taller / Práctica',
      'Laboratorio TI',
      'Evaluación',
    ];
    String selectedType = sessionTypes.contains(old?['type'])
        ? old!['type'] as String
        : sessionTypes.first;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text(
            old == null ? 'Crear Sesión Académica' : 'Editar Sesión Académica',
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: group,
                    items: [
                      for (final g in s.all('groups'))
                        DropdownMenuItem(
                          value: g['id'] as String,
                          child: Text(
                            '${g['code']} · ${g['name']}',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                    ],
                    onChanged: (v) => set(() => group = v),
                    decoration: const InputDecoration(labelText: 'Grupo'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: numberCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'N° de Sesión',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: durationCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Duración (Horas)',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: topicCtrl,
                    decoration: const InputDecoration(
                      labelText:
                          'Tema Desarrollado (ej. FORMACION DUAL SENATI)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de Sesión',
                    ),
                    items: [
                      for (final t in sessionTypes)
                        DropdownMenuItem(
                          value: t,
                          child: Text(
                            t,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                    ],
                    onChanged: (v) =>
                        set(() => selectedType = v ?? selectedType),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: dateCtrl,
                    decoration: InputDecoration(
                      labelText: 'Fecha (AAAA-MM-DD)',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.calendar_today_outlined),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate:
                                DateTime.tryParse(dateCtrl.text) ??
                                DateTime.now(),
                            firstDate: DateTime(2024),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            dateCtrl.text = DateFormat('yyyy-MM-dd')
                                .format(picked);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Observaciones (Opcional, ej. CLASE 01)',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (ok == true && topicCtrl.text.trim().isNotEmpty) {
      await s.save('sessions', {
        ...?old,
        'groupId': group,
        'sessionNumber': int.tryParse(numberCtrl.text.trim()) ?? 1,
        'topic': topicCtrl.text.trim(),
        'type': selectedType,
        'durationHours': int.tryParse(durationCtrl.text.trim()) ?? 4,
        'date': dateCtrl.text.trim(),
        'notes': notesCtrl.text.trim(),
      });
    }

    numberCtrl.dispose();
    topicCtrl.dispose();
    durationCtrl.dispose();
    dateCtrl.dispose();
    notesCtrl.dispose();
  }

  Future<void> _deleteSession(
    BuildContext context,
    LocalStore s,
    Map<String, dynamic> row,
  ) async {
    final id = row['id'] as String;
    final hasRecords =
        s.all('attendance').any((e) => e['sessionId'] == id) ||
        s.all('participation').any((e) => e['sessionId'] == id);
    if (hasRecords) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se puede eliminar: la sesión ya registra asistencias o participaciones.',
          ),
        ),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar sesión'),
        content: Text('¿Eliminar la sesión “${row['topic']}”?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) await s.remove('sessions', id);
  }
}

// ============================================================================
// MÓDULO DE CONTROL DE ASISTENCIA (BOTONES P / T / F / J OPTIMIZADOS)
// ============================================================================
class _AttendancePage extends ConsumerStatefulWidget {
  const _AttendancePage();

  @override
  ConsumerState<_AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends ConsumerState<_AttendancePage> {
  String search = '';
  String? selectedCourseId;

  Future<void> _pickOrCreateDateSession(
    BuildContext context,
    LocalStore s,
    String courseId,
    List<Map<String, dynamic>> courseSessions,
    Map<String, dynamic>? currentSession,
  ) async {
    final initialDate =
        DateTime.tryParse(currentSession?['date']?.toString() ?? '') ??
        DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      helpText: 'SELECCIONAR FECHA DE ASISTENCIA',
    );
    if (picked == null || !context.mounted) return;

    final dateStr = DateFormat('yyyy-MM-dd').format(picked);
    final existing = courseSessions
        .where((x) => x['date']?.toString() == dateStr)
        .firstOrNull;
    if (existing != null) {
      s.selectSessionAndNavigate(existing['id']?.toString());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(milliseconds: 1400),
            content: Text('Fecha seleccionada: $dateStr'),
          ),
        );
      }
      return;
    }

    final nextNum = courseSessions.length + 1;
    final topicCtrl = TextEditingController(text: 'Sesión de clase ($dateStr)');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Registrar asistencia para $dateStr'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Curso: ${s.label('groups', courseId)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: topicCtrl,
              decoration: InputDecoration(
                labelText: 'Tema de la Sesión N° $nextNum',
                prefixIcon: const Icon(Icons.topic_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('Abrir asistencia de esta fecha'),
          ),
        ],
      ),
    );

    if (ok == true) {
      final newId = 'ses-${DateTime.now().millisecondsSinceEpoch}';
      final topic = topicCtrl.text.trim().isEmpty
          ? 'Sesión de clase ($dateStr)'
          : topicCtrl.text.trim();
      await s.save('sessions', {
        'id': newId,
        'groupId': courseId,
        'sessionNumber': nextNum,
        'topic': topic,
        'date': dateStr,
        'status': 'En curso',
        'notes': 'Sesión habilitada desde Control de Asistencia',
      });
      s.selectSessionAndNavigate(newId);
    }
    topicCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(localStoreProvider);
    final groups = s.where('groups', (e) => e['active'] != false);
    final allSessions = s.all('sessions');

    // Determinar el Curso / Grupo activo (Paso 1)
    final sessionFromStore = s.byId('sessions', s.selectedSessionId);
    final groupFromSession = sessionFromStore?['groupId']?.toString();
    final activeGroupId = groups.any((g) => g['id'] == selectedCourseId)
        ? selectedCourseId
        : (groups.any((g) => g['id'] == groupFromSession)
              ? groupFromSession
              : (groups.any((g) => g['id'] == s.selectedGroupFilter)
                    ? s.selectedGroupFilter
                    : groups.firstOrNull?['id']?.toString()));

    // Filtrar las fechas/sesiones que pertenecen exclusivamente al Curso seleccionado (Paso 2)
    final courseSessions =
        s.where('sessions', (e) => e['groupId'] == activeGroupId).toList()
          ..sort(
            (a, b) => (b['date']?.toString() ?? '').compareTo(
              a['date']?.toString() ?? '',
            ),
          );

    final activeSessionId =
        courseSessions.any((e) => e['id'] == s.selectedSessionId)
        ? s.selectedSessionId
        : courseSessions.firstOrNull?['id']?.toString();

    final selected = s.byId('sessions', activeSessionId);
    final groupId = activeGroupId;
    final eligible = s.where(
      'students',
      (e) =>
          e['active'] != false &&
          e['groupId'] == groupId &&
          '${e['name']} ${e['code']}'.toLowerCase().contains(
            search.toLowerCase(),
          ),
    );
    final allEligibleCount = s
        .where(
          'students',
          (e) => e['active'] != false && e['groupId'] == groupId,
        )
        .length;
    final records = activeSessionId == null
        ? const <Map<String, dynamic>>[]
        : s.where('attendance', (e) => e['sessionId'] == activeSessionId);
    final counts = {
      for (final state in ['Presente', 'Tardanza', 'Falta', 'Justificado'])
        state: records.where((e) => e['status'] == state).length,
    };
    final pendingCount = (allEligibleCount - records.length).clamp(
      0,
      allEligibleCount,
    );

    return _Content(
      title: 'Control de asistencia',
      subtitle: 'Paso 1: Selecciona el curso/grupo · Paso 2: Selecciona la fecha para registrar Presente (P), Tardanza (T), Falta (F) o Justificado (J).',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (groups.isEmpty && allSessions.isEmpty)
            const Card(
              child: _Empty(
                text: 'Crea un curso/grupo y una sesión para comenzar a registrar asistencia.',
              ),
            )
          else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: LayoutBuilder(
                  builder: (context, box) {
                    final courseDropdown = DropdownButtonFormField<String>(
                      key: ValueKey('att-course-$activeGroupId'),
                      isExpanded: true,
                      initialValue: activeGroupId,
                      decoration: const InputDecoration(
                        labelText: '1. Curso / Grupo académico',
                        prefixIcon: Icon(Icons.school_outlined),
                      ),
                      items: [
                        for (final g in groups)
                          DropdownMenuItem(
                            value: g['id'] as String,
                            child: Text(
                              '${g['code']} · ${g['name']}',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                      ],
                      onChanged: (newGroupId) {
                        if (newGroupId == null) return;
                        setState(() => selectedCourseId = newGroupId);
                        final sessionsForCourse =
                            s
                                .where(
                                  'sessions',
                                  (e) => e['groupId'] == newGroupId,
                                )
                                .toList()
                              ..sort(
                                (a, b) => (b['date']?.toString() ?? '')
                                    .compareTo(a['date']?.toString() ?? ''),
                              );
                        if (sessionsForCourse.isNotEmpty) {
                          s.selectSessionAndNavigate(
                            sessionsForCourse.first['id']?.toString(),
                          );
                        }
                      },
                    );

                    final dateDropdown = courseSessions.isEmpty
                        ? InputDecorator(
                            decoration: const InputDecoration(
                              labelText: '2. Fecha de asistencia',
                              prefixIcon: Icon(Icons.calendar_today_outlined),
                            ),
                            child: Text(
                              'Sin fechas registradas en este curso',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          )
                        : DropdownButtonFormField<String>(
                            key: ValueKey(
                              'att-date-$activeGroupId-$activeSessionId',
                            ),
                            isExpanded: true,
                            initialValue: activeSessionId,
                            decoration: const InputDecoration(
                              labelText: '2. Fecha de asistencia (Sesión)',
                              prefixIcon: Icon(Icons.calendar_today_outlined),
                            ),
                            items: [
                              for (final x in courseSessions)
                                DropdownMenuItem(
                                  value: x['id'] as String,
                                  child: Text(
                                    '${x['date'] ?? ''} · Sesión ${x['sessionNumber'] ?? 1}: ${x['topic'] ?? ''}',
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                            ],
                            onChanged: (v) => s.selectSessionAndNavigate(v),
                          );

                    final pickDateBtn = OutlinedButton.icon(
                      onPressed: activeGroupId == null
                          ? null
                          : () => _pickOrCreateDateSession(
                              context,
                              s,
                              activeGroupId,
                              courseSessions,
                              selected,
                            ),
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: const Text('Elegir otra fecha'),
                    );

                    if (box.maxWidth < 760) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          courseDropdown,
                          const SizedBox(height: 12),
                          dateDropdown,
                          const SizedBox(height: 10),
                          pickDateBtn,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(flex: 5, child: courseDropdown),
                        const SizedBox(width: 12),
                        Expanded(flex: 5, child: dateDropdown),
                        const SizedBox(width: 10),
                        pickDateBtn,
                      ],
                    );
                  },
                ),
              ),
            ),
            if (selected == null && activeGroupId != null) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text(
                        'Este curso aún no tiene una fecha de asistencia seleccionada.',
                      ),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: () => _pickOrCreateDateSession(
                          context,
                          s,
                          activeGroupId,
                          courseSessions,
                          null,
                        ),
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: const Text('Seleccionar fecha en el calendario'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (selected != null) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _StatusCounterChip(
                    label: 'Presentes',
                    count: counts['Presente'] ?? 0,
                    color: const Color(0xFF2E7D32),
                  ),
                  _StatusCounterChip(
                    label: 'Tardanzas',
                    count: counts['Tardanza'] ?? 0,
                    color: const Color(0xFFEF6C00),
                  ),
                  _StatusCounterChip(
                    label: 'Faltas',
                    count: counts['Falta'] ?? 0,
                    color: const Color(0xFFC62828),
                  ),
                  _StatusCounterChip(
                    label: 'Justificados',
                    count: counts['Justificado'] ?? 0,
                    color: const Color(0xFF1565C0),
                  ),
                  if (pendingCount > 0)
                    Chip(
                      label: Text('Pendientes: $pendingCount'),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, box) {
                  final filterField = TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Filtrar estudiante en este curso',
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => search = v),
                  );
                  final markAllBtn = FilledButton.tonalIcon(
                    onPressed: eligible.isEmpty
                        ? null
                        : () async {
                            await s.markAllPresent(activeSessionId!, eligible);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  duration: Duration(milliseconds: 1200),
                                  content: Text(
                                    'Todos los estudiantes fueron marcados como Presentes.',
                                  ),
                                ),
                              );
                            }
                          },
                    icon: const Icon(Icons.done_all),
                    label: const Text('Marcar todos presentes'),
                  );

                  if (box.maxWidth < 600) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        filterField,
                        const SizedBox(height: 10),
                        markAllBtn,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: filterField),
                      const SizedBox(width: 12),
                      markAllBtn,
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              Card(
                child: eligible.isEmpty
                    ? const _Empty(
                        text: 'No hay estudiantes asociados a este curso o búsqueda.',
                      )
                    : Column(
                        children: [
                          for (var i = 0; i < eligible.length; i++) ...[
                            if (i > 0) const Divider(height: 1),
                            _AttendanceRow(
                              student: eligible[i],
                              sessionId: activeSessionId!,
                              store: s,
                            ),
                          ],
                        ],
                      ),
              ),
              const SizedBox(height: 10),
              Text(
                'Curso: ${s.label('groups', groupId)} · Fecha de asistencia: ${selected['date'] ?? ''} (Sesión ${selected['sessionNumber'] ?? 1}: ${selected['topic'] ?? ''})',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _StatusCounterChip extends StatelessWidget {
  const _StatusCounterChip({
    required this.label,
    required this.count,
    required this.color,
  });
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) => Chip(
    avatar: CircleAvatar(
      backgroundColor: color,
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
    label: Text(label),
    visualDensity: VisualDensity.compact,
  );
}

class _AttendanceRow extends StatelessWidget {
  const _AttendanceRow({
    required this.student,
    required this.sessionId,
    required this.store,
  });
  final Map<String, dynamic> student;
  final String sessionId;
  final LocalStore store;

  static const _options = [
    ('P', 'Presente', Color(0xFF2E7D32)),
    ('T', 'Tardanza', Color(0xFFEF6C00)),
    ('F', 'Falta', Color(0xFFC62828)),
    ('J', 'Justificado', Color(0xFF1565C0)),
  ];

  @override
  Widget build(BuildContext context) {
    final item = store
        .where(
          'attendance',
          (e) => e['sessionId'] == sessionId && e['studentId'] == student['id'],
        )
        .firstOrNull;
    final status = item?['status']?.toString();
    final note = item?['note']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: LayoutBuilder(
        builder: (context, box) {
          final isNarrow = box.maxWidth < 540;
          final studentInfo = Row(
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  _initials(student['name']?.toString() ?? ''),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student['name'] ?? 'Estudiante',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Código: ${student['code'] ?? ''}${note.isNotEmpty ? ' · Obs: $note' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          final buttonsRow = Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final opt in _options)
                _AttendanceToggleButton(
                  shortLabel: opt.$1,
                  fullLabel: opt.$2,
                  selected: status == opt.$2,
                  activeColor: opt.$3,
                  onTap: () => store.save('attendance', {
                    'id': item?['id'],
                    'sessionId': sessionId,
                    'studentId': student['id'],
                    'status': opt.$2,
                    'note': note,
                    'recordedAt': DateTime.now().toIso8601String(),
                  }),
                ),
              IconButton(
                tooltip: 'Agregar observación / justificación',
                icon: Icon(
                  note.isEmpty ? Icons.comment_outlined : Icons.comment,
                  size: 20,
                ),
                onPressed: () => _editNote(context, item, status ?? 'Presente'),
              ),
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                studentInfo,
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 52),
                  child: buttonsRow,
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: studentInfo),
              const SizedBox(width: 12),
              buttonsRow,
            ],
          );
        },
      ),
    );
  }

  Future<void> _editNote(
    BuildContext context,
    Map<String, dynamic>? item,
    String currentStatus,
  ) async {
    final ctrl = TextEditingController(text: item?['note']?.toString() ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Observación · ${student['name']}'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Detalle de justificación o tardanza',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await store.save('attendance', {
        'id': item?['id'],
        'sessionId': sessionId,
        'studentId': student['id'],
        'status': currentStatus,
        'note': ctrl.text.trim(),
        'recordedAt': DateTime.now().toIso8601String(),
      });
    }
    ctrl.dispose();
  }
}

class _AttendanceToggleButton extends StatelessWidget {
  const _AttendanceToggleButton({
    required this.shortLabel,
    required this.fullLabel,
    required this.selected,
    required this.activeColor,
    required this.onTap,
  });
  final String shortLabel;
  final String fullLabel;
  final bool selected;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: fullLabel,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 40,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? activeColor
                  : Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Text(
            shortLabel,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: selected
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// MÓDULO DE PUNTUACIÓN Y PARTICIPACIÓN (+1 / +2 / +3 RÁPIDO + HISTORIAL)
// ============================================================================
class _PointsPage extends ConsumerStatefulWidget {
  const _PointsPage();

  @override
  ConsumerState<_PointsPage> createState() => _PointsPageState();
}

class _PointsPageState extends ConsumerState<_PointsPage> {
  String? selectedActivity;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(localStoreProvider);
    final sessions = s.all('sessions');
    final activeSessionId = sessions.any((e) => e['id'] == s.selectedSessionId)
        ? s.selectedSessionId
        : sessions.firstOrNull?['id']?.toString();
    final selectedSession = s.byId('sessions', activeSessionId);
    final groupId = selectedSession?['groupId']?.toString();
    final groupStudents = s.where(
      'students',
      (e) => e['active'] != false && e['groupId'] == groupId,
    );

    final configured = s.where('activities', (e) => e['active'] != false);
    const defaults = [
      'Participación en clase',
      'Resolución de ejercicios',
      'Trabajo en equipo',
      'Exposición',
      'Actividad práctica',
    ];
    final activities = configured.isEmpty
        ? defaults
        : configured.map((e) => e['name'] as String).toList();
    final currentActivity = activities.contains(selectedActivity)
        ? selectedActivity!
        : activities.first;

    final rows = s.all('participation').reversed.toList();
    final canAssign = sessions.any(
      (session) => s
          .all('students')
          .any(
            (student) =>
                student['active'] != false &&
                student['groupId'] == session['groupId'],
          ),
    );

    return _Content(
      title: 'Puntuación y participación',
      subtitle: 'Asigna puntos rápidos (+1, +2, +3) por estudiante o registra calificaciones con observación y trazabilidad.',
      action: FilledButton.icon(
        onPressed: !canAssign ? null : () => _add(context, s),
        icon: const Icon(Icons.add),
        label: const Text('Asignar puntos'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sessions.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Puntuación rápida en sesión',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, box) {
                        final sessionDropdown = DropdownButtonFormField<String>(
                          key: ValueKey(activeSessionId),
                          isExpanded: true,
                          initialValue: activeSessionId,
                          decoration: const InputDecoration(
                            labelText: 'Sesión activa',
                          ),
                          items: [
                            for (final x in sessions)
                              DropdownMenuItem(
                                value: x['id'] as String,
                                child: Text(
                                  'S${x['sessionNumber'] ?? 1}: ${x['topic']} (${s.byId('groups', x['groupId'] as String?)?['code'] ?? ''})',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                          ],
                          onChanged: (v) => s.selectSessionAndNavigate(v),
                        );
                        final activityDropdown =
                            DropdownButtonFormField<String>(
                              key: ValueKey(currentActivity),
                              isExpanded: true,
                              initialValue: currentActivity,
                              decoration: const InputDecoration(
                                labelText: 'Actividad actual',
                              ),
                              items: [
                                for (final a in activities)
                                  DropdownMenuItem(
                                    value: a,
                                    child: Text(
                                      a,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                              ],
                              onChanged: (v) =>
                                  setState(() => selectedActivity = v),
                            );
                        if (box.maxWidth < 680) {
                          return Column(
                            children: [
                              sessionDropdown,
                              const SizedBox(height: 12),
                              activityDropdown,
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(flex: 3, child: sessionDropdown),
                            const SizedBox(width: 12),
                            Expanded(flex: 2, child: activityDropdown),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    if (groupStudents.isEmpty)
                      const _Empty(
                        text: 'No hay estudiantes en el grupo de esta sesión.',
                      )
                    else
                      Column(
                        children: [
                          for (var i = 0; i < groupStudents.length; i++) ...[
                            if (i > 0) const Divider(height: 1),
                            _QuickPointStudentRow(
                              student: groupStudents[i],
                              sessionId: activeSessionId!,
                              activity: currentActivity,
                              store: s,
                            ),
                          ],
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
          Text(
            'Historial de participaciones registradas (${rows.length})',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Card(
            child: rows.isEmpty
                ? const _Empty(
                    text: 'Aún no se han registrado participaciones.',
                  )
                : Column(
                    children: [
                      for (final e in rows)
                        ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.stars)),
                          title: Text(
                            '${s.label('students', e['studentId'] as String?)} · +${e['points']} pts',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${e['activity'] ?? 'Participación'} · ${s.label('sessions', e['sessionId'] as String?)} · ${e['date'] ?? ''}${e['note']?.toString().isNotEmpty == true ? ' · ${e['note']}' : ''}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Corregir puntuación',
                                icon: const Icon(Icons.edit_outlined, size: 20),
                                onPressed: () => _add(context, s, old: e),
                              ),
                              IconButton(
                                tooltip: 'Eliminar registro',
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                ),
                                onPressed: () => s.remove(
                                  'participation',
                                  e['id'] as String,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _add(
    BuildContext context,
    LocalStore s, {
    Map<String, dynamic>? old,
  }) async {
    final points = TextEditingController(
      text: old?['points']?.toString() ?? '1',
    );
    final note = TextEditingController(text: old?['note']?.toString() ?? '');
    final validSessions = s.where(
      'sessions',
      (session) => s
          .all('students')
          .any(
            (st) =>
                st['active'] != false && st['groupId'] == session['groupId'],
          ),
    );
    if (validSessions.isEmpty) return;

    String? selectedSession =
        old?['sessionId']?.toString() ??
        (validSessions.any((e) => e['id'] == s.selectedSessionId)
            ? s.selectedSessionId
            : validSessions.first['id'] as String);

    List<Map<String, dynamic>> eligibleFor(String? sesId) {
      final grpId = s.byId('sessions', sesId)?['groupId'];
      return s.where(
        'students',
        (e) => e['active'] != false && e['groupId'] == grpId,
      );
    }

    final initialEligible = eligibleFor(selectedSession);
    String? selectedStudent =
        initialEligible.any((e) => e['id'] == old?['studentId'])
        ? old!['studentId'] as String
        : initialEligible.firstOrNull?['id'] as String?;

    final configured = s.where('activities', (e) => e['active'] != false);
    const defaults = [
      'Participación en clase',
      'Resolución de ejercicios',
      'Trabajo en equipo',
      'Exposición',
      'Actividad práctica',
    ];
    final activities = configured.isEmpty
        ? defaults
        : configured.map((e) => e['name'] as String).toList();
    String activity = activities.contains(old?['activity'])
        ? old!['activity'] as String
        : activities.first;
    final initialActivity = configured
        .where((e) => e['name'] == activity)
        .firstOrNull;
    if (old == null && initialActivity != null) {
      points.text = '${initialActivity['valuePoints'] ?? 1}';
    }
    final operationId = const Uuid().v4();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          final currentEligible = eligibleFor(selectedSession);
          if (!currentEligible.any((e) => e['id'] == selectedStudent)) {
            selectedStudent = currentEligible.firstOrNull?['id'] as String?;
          }
          return AlertDialog(
            title: Text(old == null ? 'Asignar puntos' : 'Corregir puntuación'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: selectedSession,
                      decoration: const InputDecoration(labelText: 'Sesión'),
                      items: [
                        for (final e in validSessions)
                          DropdownMenuItem(
                            value: e['id'] as String,
                            child: Text(
                              e['topic'] ?? 'Sesión',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                      ],
                      onChanged: (value) => set(() {
                        selectedSession = value;
                        final nextEligible = eligibleFor(value);
                        selectedStudent =
                            nextEligible.firstOrNull?['id'] as String?;
                      }),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      key: ValueKey('$selectedSession-$selectedStudent'),
                      isExpanded: true,
                      initialValue: selectedStudent,
                      decoration: const InputDecoration(
                        labelText: 'Estudiante',
                      ),
                      items: [
                        for (final e in currentEligible)
                          DropdownMenuItem(
                            value: e['id'] as String,
                            child: Text(
                              e['name'] ?? 'Estudiante',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                      ],
                      onChanged: (value) => set(() => selectedStudent = value),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: activity,
                      decoration: const InputDecoration(labelText: 'Actividad'),
                      items: [
                        for (final a in activities)
                          DropdownMenuItem(
                            value: a,
                            child: Text(
                              a,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                      ],
                      onChanged: (v) => set(() {
                        activity = v ?? activity;
                        final configuredActivity = configured
                            .where((e) => e['name'] == activity)
                            .firstOrNull;
                        if (configuredActivity != null) {
                          points.text =
                              '${configuredActivity['valuePoints'] ?? 1}';
                        }
                      }),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: points,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Puntos (0–100)',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: note,
                      decoration: const InputDecoration(
                        labelText: 'Observación (opcional)',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
    if (ok == true) {
      final value = int.tryParse(points.text);
      if (value == null ||
          value < 0 ||
          value > 100 ||
          selectedStudent == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Los puntos deben ser un número entre 0 y 100.'),
            ),
          );
        }
      } else {
        await s.save('participation', {
          'id': old?['id'],
          'sessionId': selectedSession,
          'studentId': selectedStudent,
          'activity': activity,
          'operationId': operationId,
          'points': value,
          'note': note.text.trim(),
          'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        });
      }
    }
    points.dispose();
    note.dispose();
  }
}

class _QuickPointStudentRow extends StatelessWidget {
  const _QuickPointStudentRow({
    required this.student,
    required this.sessionId,
    required this.activity,
    required this.store,
  });
  final Map<String, dynamic> student;
  final String sessionId;
  final String activity;
  final LocalStore store;

  @override
  Widget build(BuildContext context) {
    final studentId = student['id'] as String;
    final totalPts = store.studentPoints(studentId);
    final sessionPts = store.studentPoints(studentId, sessionId: sessionId);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: LayoutBuilder(
        builder: (context, box) {
          final isNarrow = box.maxWidth < 520;
          final studentInfo = Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF12355B),
                foregroundColor: Colors.white,
                child: Text(
                  _initials(student['name']?.toString() ?? ''),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student['name'] ?? 'Estudiante',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Código: ${student['code']} · Total: $totalPts pts (Sesión: +$sessionPts pts)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          final buttons = Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (pts, color) in const [
                (1, Color(0xFF12355B)),
                (2, Color(0xFF1E4E8C)),
                (3, Color(0xFFE87524)),
              ])
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(44, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  onPressed: () async {
                    await store.awardQuickPoints(
                      sessionId: sessionId,
                      studentId: studentId,
                      activity: activity,
                      points: pts,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          duration: const Duration(milliseconds: 1000),
                          content: Text(
                            '+$pts pts asignados a ${student['name']} ($activity)',
                          ),
                        ),
                      );
                    }
                  },
                  child: Text(
                    '+$pts',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                studentInfo,
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 52),
                  child: buttons,
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: studentInfo),
              const SizedBox(width: 12),
              buttons,
            ],
          );
        },
      ),
    );
  }
}

// ============================================================================
// MÓDULO DE REPORTES Y EXPORTACIÓN (CONSOLIDADO SENATI + PDF / EXCEL)
// ============================================================================
class _ReportsPage extends ConsumerStatefulWidget {
  const _ReportsPage();

  @override
  ConsumerState<_ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<_ReportsPage> {
  String? filterGroupId;
  String? filterSessionId;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(localStoreProvider);
    final groups = s.all('groups');
    if (filterGroupId != null && !groups.any((g) => g['id'] == filterGroupId)) {
      filterGroupId = null;
    }
    final sessions = s.where(
      'sessions',
      (ses) => filterGroupId == null || ses['groupId'] == filterGroupId,
    );
    if (filterSessionId != null &&
        !sessions.any((ses) => ses['id'] == filterSessionId)) {
      filterSessionId = null;
    }

    final students = s.where(
      'students',
      (st) =>
          st['active'] != false &&
          (filterGroupId == null || st['groupId'] == filterGroupId),
    );

    final consolidated = [
      for (final st in students)
        (
          student: st,
          group: s.byId('groups', st['groupId'] as String?),
          att: s.studentAttendanceSummary(
            st['id'] as String,
            groupId: filterGroupId,
            sessionId: filterSessionId,
          ),
          points: s.studentPoints(
            st['id'] as String,
            sessionId: filterSessionId,
          ),
        ),
    ]..sort((a, b) => b.points.compareTo(a.points));

    return _Content(
      title: 'Reportes y Exportación',
      subtitle: 'Filtra por grupo o sesión, consulta el consolidado de calificaciones y exporta en PDF o Excel.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, box) {
                  final groupDrop = DropdownButtonFormField<String?>(
                    key: ValueKey(filterGroupId),
                    isExpanded: true,
                    initialValue: filterGroupId,
                    decoration: const InputDecoration(
                      labelText: 'Grupo académico',
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text(
                          'Todos los grupos',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      for (final g in groups)
                        DropdownMenuItem<String?>(
                          value: g['id'] as String,
                          child: Text(
                            '${g['code']} · ${g['name']}',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() {
                      filterGroupId = v;
                      filterSessionId = null;
                    }),
                  );

                  final sessionDrop = DropdownButtonFormField<String?>(
                    key: ValueKey('$filterGroupId-$filterSessionId'),
                    isExpanded: true,
                    initialValue: filterSessionId,
                    decoration: const InputDecoration(
                      labelText: 'Sesión (opcional)',
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text(
                          'Todas las sesiones del periodo',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      for (final ses in sessions)
                        DropdownMenuItem<String?>(
                          value: ses['id'] as String,
                          child: Text(
                            'S${ses['sessionNumber'] ?? 1}: ${ses['topic']} (${ses['date']})',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => filterSessionId = v),
                  );

                  if (box.maxWidth < 680) {
                    return Column(
                      children: [
                        groupDrop,
                        const SizedBox(height: 12),
                        sessionDrop,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: groupDrop),
                      const SizedBox(width: 14),
                      Expanded(child: sessionDrop),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, box) {
              final fullWidthCard = box.maxWidth < 680;
              final exportCardWidth = fullWidthCard ? box.maxWidth : 320.0;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: exportCardWidth,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.picture_as_pdf_outlined,
                              size: 32,
                              color: Color(0xFFC62828),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Resumen académico PDF',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Reporte Consolidado de Calificaciones y Asistencia SENATI listo para imprimir o archivar.',
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: () => _pdf(context, s, consolidated),
                              icon: const Icon(Icons.download),
                              label: const Text('Exportar PDF'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: exportCardWidth,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.table_view_outlined,
                              size: 32,
                              color: Color(0xFF2E7D32),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Libro Excel (.xlsx)',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Hojas de Consolidado, Grupos, Estudiantes, Sesiones, Asistencia y Participación.',
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: () => _excel(context, s, consolidated),
                              icon: const Icon(Icons.download),
                              label: const Text('Exportar Excel'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Vista previa · Reporte Consolidado de Calificaciones',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Card(
            child: consolidated.isEmpty
                ? const _Empty(
                    text: 'No hay registros para los filtros seleccionados.',
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Estudiante')),
                        DataColumn(label: Text('Código')),
                        DataColumn(label: Text('Grupo')),
                        DataColumn(label: Text('P / T / F / J')),
                        DataColumn(label: Text('% Asist.')),
                        DataColumn(label: Text('Total Pts'), numeric: true),
                      ],
                      rows: [
                        for (final item in consolidated)
                          DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  item.student['name']?.toString() ?? '—',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(item.student['code']?.toString() ?? ''),
                              ),
                              DataCell(
                                Text(item.group?['code']?.toString() ?? '—'),
                              ),
                              DataCell(
                                Text(
                                  '${item.att.present} / ${item.att.lateCount} / ${item.att.absent} / ${item.att.justified}',
                                ),
                              ),
                              DataCell(
                                Text(
                                  '${item.att.attendanceRate.toStringAsFixed(0)}%',
                                ),
                              ),
                              DataCell(
                                Text(
                                  '${item.points}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _pdf(
    BuildContext context,
    LocalStore s,
    List<
      ({
        Map<String, dynamic> student,
        Map<String, dynamic>? group,
        AttendanceSummary att,
        int points,
      })
    >
    consolidated,
  ) async {
    final doc = pw.Document();
    final selectedGroup = s.byId('groups', filterGroupId);
    final selectedSession = s.byId('sessions', filterSessionId);
    final groupLabel = selectedGroup != null
        ? '${selectedGroup['code']} | Asignatura: ${selectedGroup['name']} | Periodo: ${selectedGroup['period'] ?? '2026-20'}'
        : 'Todos los grupos activos (Periodo 2026-20)';
    final sessionLabel = selectedSession != null
        ? 'Sesión ${selectedSession['sessionNumber'] ?? 1}: ${selectedSession['topic']} (${selectedSession['date']})'
        : 'Consolidado general de sesiones';

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => [
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'SENATI - AULA PUNTOS',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text('Grupo: ${_asciiSafe(groupLabel)}'),
                pw.Text('Criterio: ${_asciiSafe(sessionLabel)}'),
                pw.Text(
                  'Instructor: ${_asciiSafe(s.instructor['name'] ?? 'Instructor SENATI')} - Generado: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Reporte Consolidado de Calificaciones y Asistencia',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: [
              'Estudiante',
              'Codigo',
              'Grupo',
              'Asist. (P/T/F/J)',
              '% Asist.',
              'Total Pts',
            ],
            data: [
              for (final item in consolidated)
                [
                  _asciiSafe(item.student['name']?.toString() ?? ''),
                  item.student['code']?.toString() ?? '',
                  item.group?['code']?.toString() ?? '',
                  '${item.att.present}/${item.att.lateCount}/${item.att.absent}/${item.att.justified}',
                  '${item.att.attendanceRate.toStringAsFixed(0)}%',
                  '${item.points}',
                ],
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Indicadores Generales del Sistema',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            data: [
              ['Indicador', 'Total'],
              ['Grupos activos', '${s.activeGroups}'],
              ['Estudiantes activos', '${s.activeStudents}'],
              ['Sesiones registradas', '${s.sessionCount}'],
              ['Asistencias registradas', '${s.attendanceCount}'],
              ['Puntos acumulados', '${s.pointsTotal}'],
            ],
          ),
        ],
      ),
    );
    final bytes = await doc.save();
    await FileSaver.instance.saveFile(
      name: 'reporte_aula_puntos_senati',
      bytes: bytes,
      fileExtension: 'pdf',
      mimeType: MimeType.pdf,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Reporte PDF generado.')));
    }
  }

  String _asciiSafe(String input) {
    return input
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('Ñ', 'N')
        .replaceAll('ñ', 'n');
  }

  Future<void> _excel(
    BuildContext context,
    LocalStore s,
    List<
      ({
        Map<String, dynamic> student,
        Map<String, dynamic>? group,
        AttendanceSummary att,
        int points,
      })
    >
    consolidated,
  ) async {
    final book = xls.Excel.createExcel();
    final consolidatedSheet = book['Consolidado'];
    consolidatedSheet.appendRow([
      xls.TextCellValue('Codigo'),
      xls.TextCellValue('Estudiante'),
      xls.TextCellValue('Grupo'),
      xls.TextCellValue('Presentes'),
      xls.TextCellValue('Tardanzas'),
      xls.TextCellValue('Faltas'),
      xls.TextCellValue('Justificados'),
      xls.TextCellValue('% Asistencia'),
      xls.TextCellValue('Total Puntos'),
    ]);
    for (final item in consolidated) {
      consolidatedSheet.appendRow([
        xls.TextCellValue('${item.student['code'] ?? ''}'),
        xls.TextCellValue('${item.student['name'] ?? ''}'),
        xls.TextCellValue('${item.group?['code'] ?? ''}'),
        xls.IntCellValue(item.att.present),
        xls.IntCellValue(item.att.lateCount),
        xls.IntCellValue(item.att.absent),
        xls.IntCellValue(item.att.justified),
        xls.TextCellValue('${item.att.attendanceRate.toStringAsFixed(0)}%'),
        xls.IntCellValue(item.points),
      ]);
    }

    for (final entry in {
      'Grupos': s.all('groups'),
      'Estudiantes': s.all('students'),
      'Sesiones': s.all('sessions'),
      'Asistencia': s.all('attendance'),
      'Participacion': s.all('participation'),
    }.entries) {
      final sheet = book[entry.key];
      final keys = entry.value.isEmpty
          ? <String>['id']
          : entry.value.first.keys.toList();
      sheet.appendRow([for (final k in keys) xls.TextCellValue(k)]);
      for (final e in entry.value) {
        sheet.appendRow([
          for (final k in keys) xls.TextCellValue('${e[k] ?? ''}'),
        ]);
      }
    }
    if (book.sheets.containsKey('Sheet1')) {
      book.delete('Sheet1');
    }
    final bytes = book.save();
    if (bytes != null) {
      await FileSaver.instance.saveFile(
        name: 'reporte_aula_puntos_senati',
        bytes: Uint8List.fromList(bytes),
        fileExtension: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );
    }
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Reporte Excel generado.')));
    }
  }
}

// ============================================================================
// MÓDULO DE CONFIGURACIÓN, PERFIL, AUDITORÍA Y SINCRONIZACIÓN MYSQL
// ============================================================================
class _SettingsPage extends ConsumerWidget {
  const _SettingsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(localStoreProvider);
    final pendingCount = s.pendingOutboxCount;

    return _Content(
      title: 'Configuración',
      subtitle: 'Preferencias de la aplicación, perfil del instructor, sincronización MySQL y respaldo de datos.',
      child: Column(
        children: [
          const _ActivityManager(),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text(
                      'Sesión activa: ${s.instructor['name'] ?? 'Instructor'}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${s.instructor['role'] ?? ''} · ${s.instructor['email'] ?? ''} · ${s.instructor['campus'] ?? ''}',
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _editInstructor(context, s),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Editar perfil'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () async {
                            await s.logout();
                            if (context.mounted) context.go('/');
                          },
                          icon: const Icon(Icons.logout_rounded, size: 18),
                          label: const Text('Cerrar sesión'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    leading: Icon(
                      s.isOnline ? Icons.storage_rounded : Icons.sync_outlined,
                      color: s.isOnline ? const Color(0xFF159B8A) : null,
                    ),
                    title: const Text(
                      'Base de Datos MySQL (aula_puntos_senati)',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '$pendingCount operaciones en cola · Endpoint: ${s.apiUrl}${s.lastSyncAt != null ? '\nÚltima sincronización: ${s.lastSyncAt}' : ''}',
                    ),
                    trailing: Chip(
                      avatar: Icon(
                        s.isOnline ? Icons.check_circle : Icons.cloud_off,
                        size: 16,
                      ),
                      label: Text(s.isOnline ? 'MySQL Activo' : 'Modo Local'),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: s.isSyncing
                              ? null
                              : () async {
                                  final res = await s.syncWithServer();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(res.message)),
                                    );
                                  }
                                },
                          icon: const Icon(Icons.sync),
                          label: const Text('Sincronizar con MySQL'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _editApiUrl(context, s),
                          icon: const Icon(Icons.link),
                          label: const Text('Configurar URL API'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _showAuditDialog(context, s),
                          icon: const Icon(Icons.history),
                          label: Text('Auditoría (${s.all('audit').length})'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ListTile(
                    leading: Icon(Icons.storage_outlined),
                    title: Text(
                      'Almacenamiento y Datos Académicos SENATI',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      'Persistencia híbrida MySQL + Caché Local con respaldo JSON.',
                    ),
                    trailing: Chip(label: Text('Activo')),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: () async {
                            await s.seedSenatiData();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Datos reales del Caso Práctico SENATI restaurados correctamente.',
                                  ),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.restore),
                          label: const Text('Restaurar datos SENATI'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final bytes = utf8.encode(s.exportBackupJson());
                            await FileSaver.instance.saveFile(
                              name: 'respaldo_aula_puntos_senati',
                              bytes: Uint8List.fromList(bytes),
                              fileExtension: 'json',
                              mimeType: MimeType.json,
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Respaldo JSON exportado.'),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.download_outlined),
                          label: const Text('Exportar respaldo JSON'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: SwitchListTile(
              title: const Text('Modo oscuro'),
              subtitle: const Text('Ajusta la apariencia de la aplicación.'),
              secondary: const Icon(Icons.dark_mode_outlined),
              value: s.darkMode,
              onChanged: s.setDark,
            ),
          ),
          const SizedBox(height: 12),
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Aula Puntos – SENATI'),
              subtitle: Text(
                'Versión 1.0.0 · Sistema conectado a MySQL (aula_puntos_senati) para Android y Web.',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editInstructor(BuildContext context, LocalStore s) async {
    final nameCtrl = TextEditingController(text: s.instructor['name'] ?? '');
    final roleCtrl = TextEditingController(text: s.instructor['role'] ?? '');
    final emailCtrl = TextEditingController(text: s.instructor['email'] ?? '');
    final campusCtrl = TextEditingController(
      text: s.instructor['campus'] ?? '',
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Perfil del Instructor'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombres y apellidos',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: roleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Especialidad / Escuela',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Correo institucional',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: campusCtrl,
                  decoration: const InputDecoration(labelText: 'Sede / CFP'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (ok == true && nameCtrl.text.trim().isNotEmpty) {
      await s.updateInstructor({
        'name': nameCtrl.text.trim(),
        'role': roleCtrl.text.trim(),
        'email': emailCtrl.text.trim(),
        'campus': campusCtrl.text.trim(),
      });
    }
    nameCtrl.dispose();
    roleCtrl.dispose();
    emailCtrl.dispose();
    campusCtrl.dispose();
  }

  Future<void> _editApiUrl(BuildContext context, LocalStore s) async {
    final ctrl = TextEditingController(text: s.apiUrl);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Configurar servidor API REST / MySQL'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'URL base del API (ej. http://localhost:8080/api)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar y verificar'),
          ),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      await s.setApiUrl(ctrl.text.trim());
      final online = await s.checkServerHealth();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              online
                  ? 'Conexión establecida con MySQL en ${s.apiUrl}'
                  : 'URL guardada (${s.apiUrl}). Servidor actualmente sin conexión.',
            ),
          ),
        );
      }
    }
    ctrl.dispose();
  }

  void _showAuditDialog(BuildContext context, LocalStore s) {
    final audits = s.all('audit').reversed.take(40).toList();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Trazabilidad y Auditoría del Sistema'),
        content: SizedBox(
          width: 520,
          height: 380,
          child: audits.isEmpty
              ? const Center(child: Text('No hay eventos de auditoría.'))
              : ListView.builder(
                  itemCount: audits.length,
                  itemBuilder: (ctx, i) {
                    final a = audits[i];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.verified_user_outlined),
                      title: Text('${a['entity']} · ${a['action']}'),
                      subtitle: Text('ID: ${a['entityId']} · ${a['at']}'),
                    );
                  },
                ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}

class _ActivityManager extends ConsumerWidget {
  const _ActivityManager();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(localStoreProvider);
    final activities = store.all('activities');
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.stars_outlined),
        title: const Text('Actividades puntuables'),
        subtitle: Text('${activities.length} actividades configuradas'),
        children: [
          for (final item in activities)
            ListTile(
              title: Text(item['name'] ?? 'Actividad'),
              subtitle: Text(
                'Valor sugerido: ${item['valuePoints'] ?? 1} puntos${item['description'] != null ? ' · ${item['description']}' : ''}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Editar actividad',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _edit(context, store, old: item),
                  ),
                  IconButton(
                    tooltip: 'Eliminar actividad',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () =>
                        store.remove('activities', item['id'] as String),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: OutlinedButton.icon(
              onPressed: () => _edit(context, store),
              icon: const Icon(Icons.add),
              label: const Text('Agregar actividad'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    LocalStore store, {
    Map<String, dynamic>? old,
  }) async {
    final name = TextEditingController(text: old?['name']?.toString() ?? '');
    final value = TextEditingController(text: '${old?['valuePoints'] ?? 1}');
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(old == null ? 'Nueva actividad' : 'Editar actividad'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: value,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Puntos sugeridos (0–100)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (saved == true) {
      final points = int.tryParse(value.text);
      final duplicate = store
          .all('activities')
          .any(
            (e) =>
                e['id'] != old?['id'] &&
                (e['name'] as String).toLowerCase() ==
                    name.text.trim().toLowerCase(),
          );
      if (name.text.trim().isEmpty ||
          points == null ||
          points < 0 ||
          points > 100 ||
          duplicate) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Revisa el nombre único y los puntos (0–100).'),
            ),
          );
        }
      } else {
        await store.save('activities', {
          ...?old,
          'name': name.text.trim(),
          'valuePoints': points,
          'active': true,
        });
      }
    }
    name.dispose();
    value.dispose();
  }
}
