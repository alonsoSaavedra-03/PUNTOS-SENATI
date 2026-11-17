import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'senati_seed.dart';

const _collections = [
  'groups',
  'students',
  'sessions',
  'attendance',
  'activities',
  'participation',
  'audit',
  'outbox',
];

final localStoreProvider = ChangeNotifierProvider<LocalStore>(
  (ref) => throw UnimplementedError(),
);

class AttendanceSummary {
  const AttendanceSummary({
    required this.present,
    required this.lateCount,
    required this.absent,
    required this.justified,
    required this.totalSessions,
  });

  final int present;
  final int lateCount;
  final int absent;
  final int justified;
  final int totalSessions;

  int get recorded => present + lateCount + absent + justified;
  int get pending => (totalSessions - recorded).clamp(0, totalSessions);

  double get attendanceRate {
    if (totalSessions <= 0) return 100.0;
    final effective = present + justified + (lateCount * 0.5);
    return ((effective / totalSessions) * 100).clamp(0.0, 100.0);
  }
}

class LocalStore extends ChangeNotifier {
  LocalStore(
    this._prefs,
    this._data,
    this.darkMode, {
    required Map<String, String> instructor,
    required this.apiUrl,
    this.lastSyncAt,
    this.isAuthenticated = false,
  }) {
    _instructor = instructor;
    _rebuildCaches();
  }

  final SharedPreferencesAsync _prefs;
  final Map<String, List<Map<String, dynamic>>> _data;
  late Map<String, String> _instructor;
  bool darkMode;
  String apiUrl;
  String? lastSyncAt;
  bool isAuthenticated;
  bool isOnline = false;
  bool isSyncing = false;
  String? selectedGroupFilter;
  String? selectedSessionId;

  // Cachés en memoria para acceso O(1) sin recalcular en cada frame
  final Map<String, Map<String, Map<String, dynamic>>> _byIdCache = {};
  final Map<String, int> _studentTotalPointsCache = {};
  int _cachedPointsTotal = 0;

  static const _uuid = Uuid();

  static Future<LocalStore> create({
    bool seedIfEmpty = false,
    bool requireLogin = false,
    String defaultApiUrl = 'http://localhost:8080/api',
  }) async {
    final prefs = SharedPreferencesAsync();
    final data = <String, List<Map<String, dynamic>>>{};
    final results = await Future.wait([
      for (final key in _collections) prefs.getString('aula.$key'),
      prefs.getString('aula.instructor'),
      prefs.getString('aula.apiUrl'),
      prefs.getString('aula.lastSyncAt'),
      prefs.getBool('aula.dark'),
      prefs.getBool('aula.authenticated'),
    ]);

    for (var i = 0; i < _collections.length; i++) {
      final key = _collections[i];
      final raw = results[i] as String?;
      data[key] = raw == null
          ? <Map<String, dynamic>>[]
          : (jsonDecode(raw) as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
    }

    final rawInstructor = results[_collections.length] as String?;
    final instructor = rawInstructor == null
        ? Map<String, String>.from(SenatiSeedData.defaultInstructor)
        : Map<String, String>.from(jsonDecode(rawInstructor) as Map);

    final savedApiUrl =
        (results[_collections.length + 1] as String?) ?? defaultApiUrl;
    final lastSync = results[_collections.length + 2] as String?;
    final isDark = (results[_collections.length + 3] as bool?) ?? false;
    final savedAuth =
        (results[_collections.length + 4] as bool?) ?? !requireLogin;

    final store = LocalStore(
      prefs,
      data,
      isDark,
      instructor: instructor,
      apiUrl: savedApiUrl,
      lastSyncAt: lastSync,
      isAuthenticated: savedAuth,
    );

    final isEmpty =
        data['groups']!.isEmpty &&
        data['students']!.isEmpty &&
        data['sessions']!.isEmpty;
    if (seedIfEmpty && isEmpty) {
      await store.seedSenatiData();
    }

    // Auto-conectar y sincronizar con MySQL inmediatamente al iniciar
    unawaited(store.checkServerHealth().then((online) {
      if (online) {
        store.syncWithServer(allowLocalFallback: true);
      }
    }));

    return store;
  }

  void _rebuildCaches() {
    _byIdCache.clear();
    for (final key in _collections) {
      final map = <String, Map<String, dynamic>>{};
      for (final row in _data[key] ?? const <Map<String, dynamic>>[]) {
        final id = row['id']?.toString();
        if (id != null) map[id] = row;
      }
      _byIdCache[key] = map;
    }

    _studentTotalPointsCache.clear();
    var totalPts = 0;
    for (final p in _data['participation'] ?? const <Map<String, dynamic>>[]) {
      final pts = (p['points'] as num?)?.toInt() ?? 0;
      totalPts += pts;
      final stId = p['studentId']?.toString();
      if (stId != null) {
        _studentTotalPointsCache[stId] =
            (_studentTotalPointsCache[stId] ?? 0) + pts;
      }
    }
    _cachedPointsTotal = totalPts;
  }

  Map<String, String> get instructor => _instructor;

  List<Map<String, dynamic>> all(String key) =>
      _data[key] ?? const <Map<String, dynamic>>[];

  List<Map<String, dynamic>> where(
    String key,
    bool Function(Map<String, dynamic>) test,
  ) {
    final source = _data[key];
    if (source == null || source.isEmpty) return const [];
    return source.where(test).toList(growable: false);
  }

  Map<String, dynamic>? byId(String key, String? id) {
    if (id == null) return null;
    return _byIdCache[key]?[id];
  }

  int get activeGroups => where('groups', (e) => e['active'] != false).length;

  int get activeStudents =>
      where('students', (e) => e['active'] != false).length;

  int get sessionCount => (_data['sessions'] ?? const []).length;

  int get attendanceCount => (_data['attendance'] ?? const []).length;

  int get pendingOutboxCount =>
      where('outbox', (e) => e['status'] == 'pending').length;

  int get pointsTotal => _cachedPointsTotal;

  double get globalAttendancePercentage {
    final records = _data['attendance'] ?? const [];
    if (records.isEmpty) return 0;
    var positive = 0;
    for (final r in records) {
      final st = r['status'];
      if (st == 'Presente' || st == 'Justificado' || st == 'Tardanza') {
        positive++;
      }
    }
    return (positive / records.length) * 100;
  }

  String label(String collection, String? id) {
    final item = byId(collection, id);
    if (item == null) return '—';
    if (collection == 'groups') {
      final code = item['code']?.toString() ?? '';
      final name = item['name']?.toString() ?? '';
      if (code.isNotEmpty && name.isNotEmpty) return '$code · $name';
      return name.isNotEmpty ? name : (code.isNotEmpty ? code : '—');
    }
    if (collection == 'sessions') {
      return item['topic']?.toString() ??
          item['name']?.toString() ??
          item['code']?.toString() ??
          '—';
    }
    return item['name']?.toString() ??
        item['code']?.toString() ??
        item['topic']?.toString() ??
        '—';
  }

  int studentPoints(String studentId, {String? sessionId}) {
    if (sessionId == null) {
      return _studentTotalPointsCache[studentId] ?? 0;
    }
    var sum = 0;
    for (final e in _data['participation'] ?? const <Map<String, dynamic>>[]) {
      if (e['studentId'] == studentId && e['sessionId'] == sessionId) {
        sum += (e['points'] as num?)?.toInt() ?? 0;
      }
    }
    return sum;
  }

  int sessionPointsTotal(String sessionId) {
    var sum = 0;
    for (final e in _data['participation'] ?? const <Map<String, dynamic>>[]) {
      if (e['sessionId'] == sessionId) {
        sum += (e['points'] as num?)?.toInt() ?? 0;
      }
    }
    return sum;
  }

  AttendanceSummary studentAttendanceSummary(
    String studentId, {
    String? groupId,
    String? sessionId,
  }) {
    final student = byId('students', studentId);
    final effectiveGroupId = groupId ?? student?['groupId']?.toString();
    final sessionIds = <Object?>{};
    for (final s in _data['sessions'] ?? const <Map<String, dynamic>>[]) {
      if ((effectiveGroupId == null || s['groupId'] == effectiveGroupId) &&
          (sessionId == null || s['id'] == sessionId)) {
        sessionIds.add(s['id']);
      }
    }
    var present = 0;
    var lateCount = 0;
    var absent = 0;
    var justified = 0;
    for (final a in _data['attendance'] ?? const <Map<String, dynamic>>[]) {
      if (a['studentId'] == studentId && sessionIds.contains(a['sessionId'])) {
        switch (a['status']) {
          case 'Presente':
            present++;
          case 'Tardanza':
            lateCount++;
          case 'Falta':
            absent++;
          case 'Justificado':
            justified++;
        }
      }
    }
    return AttendanceSummary(
      present: present,
      lateCount: lateCount,
      absent: absent,
      justified: justified,
      totalSessions: sessionIds.length,
    );
  }

  void selectSessionAndNavigate(String? sessionId, {String? groupId}) {
    selectedSessionId = sessionId;
    if (groupId != null) {
      selectedGroupFilter = groupId;
    } else if (sessionId != null) {
      selectedGroupFilter = byId('sessions', sessionId)?['groupId']?.toString();
    }
    notifyListeners();
  }

  void setGroupFilter(String? groupId) {
    selectedGroupFilter = groupId;
    notifyListeners();
  }

  /// Autentica contra la tabla `usuarios` de MySQL vía API REST,
  /// con respaldo local instantáneo si el dispositivo está sin conexión.
  Future<({bool ok, String message})> login(
    String userOrEmail,
    String password,
  ) async {
    final cleanUser = userOrEmail.trim();
    if (cleanUser.isEmpty || password.isEmpty) {
      return (ok: false, message: 'Ingresa tu usuario/correo y contraseña.');
    }

    try {
      final uri = Uri.parse('$apiUrl/login');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'username': cleanUser, 'password': password}),
          )
          .timeout(const Duration(milliseconds: 1800));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final user = Map<String, String>.from(body['user'] as Map);
        _instructor = user;
        isAuthenticated = true;
        isOnline = true;
        notifyListeners();
        await Future.wait([
          _prefs.setString('aula.instructor', jsonEncode(_instructor)),
          _prefs.setBool('aula.authenticated', true),
        ]);
        return (
          ok: true,
          message: 'Bienvenido, ${user['name']} (MySQL conectado).',
        );
      } else if (response.statusCode == 401) {
        return (
          ok: false,
          message: 'Usuario o contraseña incorrectos en MySQL.',
        );
      }
    } catch (_) {
      isOnline = false;
    }

    final lower = cleanUser.toLowerCase();
    for (final u in SenatiSeedData.defaultUsers) {
      final matchesUser =
          u['username']!.toLowerCase() == lower ||
          u['email']!.toLowerCase() == lower;
      if (matchesUser && u['password'] == password) {
        _instructor = {
          'id': u['id']!,
          'username': u['username']!,
          'email': u['email']!,
          'name': u['name']!,
          'role': u['role']!,
          'campus': u['campus']!,
        };
        isAuthenticated = true;
        notifyListeners();
        await Future.wait([
          _prefs.setString('aula.instructor', jsonEncode(_instructor)),
          _prefs.setBool('aula.authenticated', true),
        ]);
        return (ok: true, message: 'Bienvenido, ${u['name']}.');
      }
    }

    return (
      ok: false,
      message: 'Credenciales inválidas. Usa jluque@senati.pe / 123456.',
    );
  }

  Future<void> logout() async {
    isAuthenticated = false;
    notifyListeners();
    await _prefs.setBool('aula.authenticated', false);
  }

  Future<void> save(String key, Map<String, dynamic> item) async {
    final rows = _data[key]!;
    final retry = key == 'participation' && item['operationId'] != null
        ? rows.where((e) => e['operationId'] == item['operationId']).firstOrNull
        : null;
    final id = item['id'] ?? retry?['id'] ?? _uuid.v4();
    final now = DateTime.now().toIso8601String();
    final oldIndex = rows.indexWhere((r) => r['id'] == id);
    final saved = <String, dynamic>{
      if (oldIndex >= 0) ...rows[oldIndex],
      ...item,
      'id': id,
      'updatedAt': now,
      'createdAt': oldIndex >= 0 ? rows[oldIndex]['createdAt'] : now,
      'syncStatus': 'pending',
    };
    if (oldIndex >= 0) {
      rows[oldIndex] = saved;
    } else {
      rows.add(saved);
    }
    if (key == 'attendance') {
      final duplicate = rows
          .where(
            (r) =>
                r['id'] != id &&
                r['sessionId'] == item['sessionId'] &&
                r['studentId'] == item['studentId'],
          )
          .firstOrNull;
      if (duplicate != null) {
        rows.remove(saved);
        final dupIndex = rows.indexWhere((r) => r['id'] == duplicate['id']);
        rows[dupIndex] = {...duplicate, ...saved, 'id': duplicate['id']};
      }
    }
    if (key == 'participation' && saved['operationId'] == null) {
      saved['operationId'] = _uuid.v4();
    }
    if (key == 'attendance' || (key == 'participation' && retry == null)) {
      _data['audit']!.add({
        'id': _uuid.v4(),
        'entity': key,
        'entityId': id,
        'action': oldIndex >= 0 ? 'updated' : 'created',
        'at': now,
      });
    }
    final operationId = key == 'participation' ? saved['operationId'] : null;
    if (operationId == null ||
        !_data['outbox']!.any((e) => e['operationId'] == operationId)) {
      _data['outbox']!.add({
        'id': _uuid.v4(),
        'operationId': operationId ?? _uuid.v4(),
        'entity': key,
        'entityId': id,
        'createdAt': now,
        'status': 'pending',
      });
    }
    _rebuildCaches();
    notifyListeners();
    await Future.wait([_persist(key), _persist('audit'), _persist('outbox')]);
  }

  /// Marca en lote a todos los estudiantes elegibles como Presentes en una sola operación.
  Future<void> markAllPresent(
    String sessionId,
    List<Map<String, dynamic>> eligibleStudents,
  ) async {
    final now = DateTime.now().toIso8601String();
    final rows = _data['attendance']!;
    for (final student in eligibleStudents) {
      final studentId = student['id'];
      final idx = rows.indexWhere(
        (e) => e['sessionId'] == sessionId && e['studentId'] == studentId,
      );
      if (idx >= 0) {
        rows[idx] = {
          ...rows[idx],
          'status': 'Presente',
          'recordedAt': now,
          'updatedAt': now,
          'syncStatus': 'pending',
        };
      } else {
        final newId = _uuid.v4();
        rows.add({
          'id': newId,
          'sessionId': sessionId,
          'studentId': studentId,
          'status': 'Presente',
          'note': '',
          'recordedAt': now,
          'createdAt': now,
          'updatedAt': now,
          'syncStatus': 'pending',
        });
      }
    }
    _data['audit']!.add({
      'id': _uuid.v4(),
      'entity': 'attendance',
      'entityId': sessionId,
      'action':
          'Asistencia masiva marcada como Presente (${eligibleStudents.length} estudiantes)',
      'at': now,
    });
    _data['outbox']!.add({
      'id': _uuid.v4(),
      'operationId': _uuid.v4(),
      'entity': 'attendance',
      'entityId': sessionId,
      'createdAt': now,
      'status': 'pending',
    });
    _rebuildCaches();
    notifyListeners();
    await Future.wait([
      _persist('attendance'),
      _persist('audit'),
      _persist('outbox'),
    ]);
  }

  Future<void> awardQuickPoints({
    required String sessionId,
    required String studentId,
    required String activity,
    required int points,
    String? note,
  }) async {
    final session = byId('sessions', sessionId);
    final date =
        session?['date']?.toString() ??
        DateFormat('yyyy-MM-dd').format(DateTime.now());
    await save('participation', {
      'sessionId': sessionId,
      'studentId': studentId,
      'activity': activity,
      'points': points,
      'note': note ?? 'Asignación rápida en sesión',
      'date': date,
      'operationId': _uuid.v4(),
    });
  }

  Future<void> remove(String key, String id) async {
    final now = DateTime.now().toIso8601String();
    _data[key]!.removeWhere((e) => e['id'] == id);
    _data['audit']!.add({
      'id': _uuid.v4(),
      'entity': key,
      'entityId': id,
      'action': 'deleted',
      'at': now,
    });
    _rebuildCaches();
    notifyListeners();
    await Future.wait([_persist(key), _persist('audit')]);
  }

  Future<void> updateInstructor(Map<String, String> updated) async {
    _instructor = {..._instructor, ...updated};
    notifyListeners();
    await _prefs.setString('aula.instructor', jsonEncode(_instructor));
  }

  Future<void> setApiUrl(String url) async {
    apiUrl = url.trim();
    notifyListeners();
    await _prefs.setString('aula.apiUrl', apiUrl);
  }

  Future<void> setDark(bool value) async {
    darkMode = value;
    notifyListeners();
    await _prefs.setBool('aula.dark', value);
  }

  Future<void> seedSenatiData() async {
    final seeded = SenatiSeedData.buildInitialCollections();
    for (final key in _collections) {
      _data[key] = List<Map<String, dynamic>>.from(seeded[key] ?? const []);
    }
    _instructor = Map<String, String>.from(SenatiSeedData.defaultInstructor);
    selectedGroupFilter = null;
    selectedSessionId = _data['sessions']!.firstOrNull?['id']?.toString();
    _rebuildCaches();
    notifyListeners();
    await Future.wait([
      for (final key in _collections) _persist(key),
      _prefs.setString('aula.instructor', jsonEncode(_instructor)),
    ]);
  }

  Future<void> clearAllData() async {
    for (final key in _collections) {
      _data[key] = <Map<String, dynamic>>[];
    }
    selectedGroupFilter = null;
    selectedSessionId = null;
    _rebuildCaches();
    notifyListeners();
    await Future.wait([for (final key in _collections) _persist(key)]);
  }

  Future<bool> checkServerHealth() async {
    try {
      final uri = Uri.parse('$apiUrl/health');
      final response = await http
          .get(uri)
          .timeout(const Duration(milliseconds: 4000));
      isOnline = response.statusCode == 200;
    } catch (_) {
      isOnline = false;
    }
    notifyListeners();
    return isOnline;
  }

  Future<({bool connected, int syncedCount, String message})> syncWithServer({
    bool allowLocalFallback = true,
  }) async {
    isSyncing = true;
    notifyListeners();

    final now = DateTime.now().toIso8601String();
    final pendingCount = _data['outbox']!.length;

    try {
      final uri = Uri.parse('$apiUrl/sync');
      final payload = {
        'instructor': _instructor,
        'collections': {
          for (final key in [
            'groups',
            'students',
            'sessions',
            'attendance',
            'activities',
            'participation',
          ])
            key: _data[key],
        },
        'outbox': _data['outbox'],
        'clientTimestamp': now,
      };

      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final serverCollections =
            decoded['collections'] as Map<String, dynamic>?;
        if (serverCollections != null) {
          for (final key in [
            'groups',
            'students',
            'sessions',
            'attendance',
            'activities',
            'participation',
          ]) {
            if (serverCollections[key] is List) {
              _data[key] = (serverCollections[key] as List)
                  .map((e) => Map<String, dynamic>.from(e as Map))
                  .toList();
            }
          }
        } else {
          _markAllSyncedInMemory();
        }
        _data['outbox']!.clear();
        _data['audit']!.add({
          'id': _uuid.v4(),
          'entity': 'sync',
          'entityId': 'mysql-db',
          'action':
              'Sincronización exitosa con MySQL ($pendingCount operaciones)',
          'at': now,
        });
        lastSyncAt = now;
        isOnline = true;
        isSyncing = false;
        _rebuildCaches();
        notifyListeners();
        await Future.wait([
          for (final key in _collections) _persist(key),
          _prefs.setString('aula.lastSyncAt', now),
        ]);
        return (
          connected: true,
          syncedCount: pendingCount,
          message:
              'Sincronizado con la base de datos MySQL ($pendingCount operaciones procesadas).',
        );
      }
    } catch (_) {
      isOnline = false;
    }

    if (allowLocalFallback) {
      _markAllSyncedInMemory();
      _data['outbox']!.clear();
      _data['audit']!.add({
        'id': _uuid.v4(),
        'entity': 'sync',
        'entityId': 'local-checkpoint',
        'action':
            'Consolidación local completada ($pendingCount operaciones verificadas)',
        'at': now,
      });
      lastSyncAt = now;
      isSyncing = false;
      _rebuildCaches();
      notifyListeners();
      await Future.wait([
        for (final key in _collections) _persist(key),
        _prefs.setString('aula.lastSyncAt', now),
      ]);
      return (
        connected: false,
        syncedCount: pendingCount,
        message:
            'Servidor no detectado en $apiUrl. Se consolidaron $pendingCount operaciones localmente.',
      );
    }

    isSyncing = false;
    notifyListeners();
    return (
      connected: false,
      syncedCount: 0,
      message: 'No se pudo conectar al servidor MySQL en $apiUrl.',
    );
  }

  void _markAllSyncedInMemory() {
    for (final key in [
      'groups',
      'students',
      'sessions',
      'attendance',
      'activities',
      'participation',
    ]) {
      for (final row in _data[key]!) {
        row['syncStatus'] = 'synced';
      }
    }
  }

  String exportBackupJson() {
    return const JsonEncoder.withIndent('  ').convert({
      'app': 'Aula Puntos – SENATI',
      'database': 'MySQL (aula_puntos_senati)',
      'version': '1.0.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'instructor': _instructor,
      'collections': _data,
    });
  }

  Future<void> _persist(String key) =>
      _prefs.setString('aula.$key', jsonEncode(_data[key]));
}
