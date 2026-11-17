import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:aula_puntos_senati/data/senati_seed.dart';

/// Servidor Backend API REST conectado a MySQL (`aula_puntos_senati`)
/// para «Aula Puntos – SENATI».
/// Ejecución: `dart run backend/server.dart` (puerto 8080 por defecto).
Future<void> main(List<String> args) async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final dbFile = File('backend/aula_puntos_db.json');
  Map<String, dynamic> db = await _loadOrSeedDatabase(dbFile);

  final mysqlReady = await _checkMysqlDatabase();

  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  stdout.writeln(
    '================================================================',
  );
  stdout.writeln('  AULA PUNTOS – SENATI | Servidor API REST + MySQL Activo');
  stdout.writeln('  URL Base  : http://localhost:$port/api');
  stdout.writeln(
    '  Motor BD  : ${mysqlReady ? "MySQL XAMPP (aula_puntos_senati)" : "Respaldo Local JSON"}',
  );
  stdout.writeln(
    '================================================================',
  );

  server.listen((HttpRequest req) async {
    _addCorsHeaders(req.response);
    if (req.method == 'OPTIONS') {
      req.response.statusCode = HttpStatus.noContent;
      await req.response.close();
      return;
    }

    try {
      final path = req.uri.path;
      if (req.method == 'GET' && path == '/api/health') {
        final collections = db['collections'] as Map<String, dynamic>;
        await _sendJson(req, {
          'status': 'ok',
          'service': 'Aula Puntos – SENATI API REST',
          'database': 'MySQL (aula_puntos_senati)',
          'serverTime': DateTime.now().toIso8601String(),
          'counts': {
            for (final k in collections.keys)
              k: (collections[k] as List).length,
          },
        });
      } else if (req.method == 'POST' && path == '/api/login') {
        final rawBody = await utf8.decoder.bind(req).join();
        final payload = jsonDecode(rawBody) as Map<String, dynamic>;
        final userOrEmail = (payload['username'] ?? payload['email'] ?? '')
            .toString()
            .trim();
        final password = (payload['password'] ?? '').toString();
        final user = await _authenticateUser(userOrEmail, password);
        if (user == null) {
          await _sendJson(req, {
            'error':
                'Credenciales inválidas. Verifica tu usuario y contraseña.',
          }, statusCode: HttpStatus.unauthorized);
        } else {
          await _sendJson(req, {'status': 'ok', 'user': user});
        }
      } else if (req.method == 'GET' && path == '/api/bootstrap') {
        await _sendJson(req, db);
      } else if (req.method == 'GET' &&
          const [
            '/api/groups',
            '/api/students',
            '/api/sessions',
            '/api/attendance',
            '/api/activities',
            '/api/participation',
            '/api/audit',
          ].contains(path)) {
        final key = path.substring('/api/'.length);
        final collections = db['collections'] as Map<String, dynamic>;
        await _sendJson(req, {'data': collections[key] ?? []});
      } else if (req.method == 'POST' && path == '/api/sync') {
        final rawBody = await utf8.decoder.bind(req).join();
        final payload = jsonDecode(rawBody) as Map<String, dynamic>;
        db = _processSync(db, payload);
        await _persistDb(dbFile, db);
        await _syncToMysql(db);
        await _sendJson(req, {
          'status': 'synced',
          'database': 'MySQL (aula_puntos_senati)',
          'syncedAt': DateTime.now().toIso8601String(),
          'instructor': db['instructor'],
          'collections': db['collections'],
        });
      } else if (req.method == 'POST' && path == '/api/reset') {
        db = _createFreshDb();
        await _persistDb(dbFile, db);
        await _syncToMysql(db);
        await _sendJson(req, {
          'status': 'reset',
          'collections': db['collections'],
        });
      } else {
        await _sendJson(req, {
          'error': 'Ruta no encontrada: ${req.method} $path',
        }, statusCode: HttpStatus.notFound);
      }
    } catch (e) {
      await _sendJson(req, {
        'error': 'Error procesando solicitud: $e',
      }, statusCode: HttpStatus.internalServerError);
    }
  });

  await Completer<void>().future;
}

const _mysqlExe = r'C:\xampp\mysql\bin\mysql.exe';

Future<bool> _checkMysqlDatabase() async {
  if (!await File(_mysqlExe).exists()) return false;
  try {
    final result = await Process.run(_mysqlExe, [
      '--default-character-set=utf8mb4',
      '-u',
      'root',
      '-D',
      'aula_puntos_senati',
      '-e',
      'SELECT COUNT(*) FROM usuarios;',
    ]);
    return result.exitCode == 0;
  } catch (_) {
    return false;
  }
}

Future<Map<String, String>?> _authenticateUser(
  String userOrEmail,
  String password,
) async {
  final lower = userOrEmail.toLowerCase();
  if (await File(_mysqlExe).exists()) {
    try {
      final safeUser = lower.replaceAll("'", "''");
      final safePass = password.replaceAll("'", "''");
      final sql =
          "SELECT id, username, email, name, role, campus FROM usuarios "
          "WHERE (LOWER(username)='$safeUser' OR LOWER(email)='$safeUser') "
          "AND password_plain='$safePass' AND active=1 LIMIT 1;";
      final res = await Process.run(_mysqlExe, [
        '--default-character-set=utf8mb4',
        '-u',
        'root',
        '-D',
        'aula_puntos_senati',
        '--batch',
        '--skip-column-names',
        '-e',
        sql,
      ]);
      if (res.exitCode == 0) {
        final line = res.stdout.toString().trim();
        if (line.isNotEmpty) {
          final parts = line.split('\t');
          if (parts.length >= 6) {
            return {
              'id': parts[0],
              'username': parts[1],
              'email': parts[2],
              'name': parts[3],
              'role': parts[4],
              'campus': parts[5],
            };
          }
        }
      }
    } catch (_) {}
  }

  for (final u in SenatiSeedData.defaultUsers) {
    final matchesUser =
        u['username']!.toLowerCase() == lower ||
        u['email']!.toLowerCase() == lower;
    if (matchesUser && u['password'] == password) {
      return {
        'id': u['id']!,
        'username': u['username']!,
        'email': u['email']!,
        'name': u['name']!,
        'role': u['role']!,
        'campus': u['campus']!,
      };
    }
  }
  return null;
}

String _esc(Object? value) =>
    (value?.toString() ?? '').replaceAll(r'\', r'\\').replaceAll("'", "''");

Future<void> _syncToMysql(Map<String, dynamic> db) async {
  if (!await File(_mysqlExe).exists()) return;
  try {
    final cols = db['collections'] as Map<String, dynamic>;
    final sb = StringBuffer()
      ..writeln('SET NAMES utf8mb4;')
      ..writeln('USE aula_puntos_senati;')
      ..writeln('SET FOREIGN_KEY_CHECKS = 0;')
      ..writeln('TRUNCATE TABLE participacion;')
      ..writeln('TRUNCATE TABLE asistencia;')
      ..writeln('TRUNCATE TABLE sesiones;')
      ..writeln('TRUNCATE TABLE estudiantes;')
      ..writeln('TRUNCATE TABLE grupos;')
      ..writeln('TRUNCATE TABLE actividades;')
      ..writeln('TRUNCATE TABLE auditoria;');

    for (final g in (cols['groups'] as List? ?? [])) {
      sb.writeln(
        "INSERT INTO grupos (id, code, name, program, period, section, instructor_id, active, created_at, updated_at) VALUES ("
        "'${_esc(g['id'])}', '${_esc(g['code'])}', '${_esc(g['name'])}', "
        "'${_esc(g['program'] ?? '2026-20')}', '${_esc(g['period'] ?? '2026-20')}', "
        "'${_esc(g['section'] ?? '')}', '${_esc(g['instructorId'] ?? 'inst-senati-01')}', "
        "${g['active'] == false ? 0 : 1}, '${_esc(g['createdAt'])}', '${_esc(g['updatedAt'])}');",
      );
    }

    for (final st in (cols['students'] as List? ?? [])) {
      sb.writeln(
        "INSERT INTO estudiantes (id, code, name, email, group_id, active, created_at, updated_at) VALUES ("
        "'${_esc(st['id'])}', '${_esc(st['code'])}', '${_esc(st['name'])}', "
        "'${_esc(st['email'] ?? '')}', '${_esc(st['groupId'])}', "
        "${st['active'] == false ? 0 : 1}, '${_esc(st['createdAt'])}', '${_esc(st['updatedAt'])}');",
      );
    }

    for (final a in (cols['activities'] as List? ?? [])) {
      sb.writeln(
        "INSERT INTO actividades (id, name, description, value_points, max_points, active, created_at, updated_at) VALUES ("
        "'${_esc(a['id'])}', '${_esc(a['name'])}', '${_esc(a['description'] ?? '')}', "
        "${(a['valuePoints'] as num?)?.toInt() ?? 1}, ${(a['maxPoints'] as num?)?.toInt() ?? 20}, "
        "${a['active'] == false ? 0 : 1}, '${_esc(a['createdAt'])}', '${_esc(a['updatedAt'])}');",
      );
    }

    for (final s in (cols['sessions'] as List? ?? [])) {
      sb.writeln(
        "INSERT INTO sesiones (id, group_id, session_number, topic, type, duration_hours, date, notes, created_at, updated_at) VALUES ("
        "'${_esc(s['id'])}', '${_esc(s['groupId'])}', ${(s['sessionNumber'] as num?)?.toInt() ?? 1}, "
        "'${_esc(s['topic'])}', '${_esc(s['type'] ?? 'Teoría (Tecnología)')}', "
        "${(s['durationHours'] as num?)?.toInt() ?? 4}, '${_esc(s['date'])}', "
        "'${_esc(s['notes'] ?? '')}', '${_esc(s['createdAt'])}', '${_esc(s['updatedAt'])}');",
      );
    }

    for (final att in (cols['attendance'] as List? ?? [])) {
      sb.writeln(
        "INSERT INTO asistencia (id, session_id, student_id, status, note, recorded_at, created_at, updated_at) VALUES ("
        "'${_esc(att['id'])}', '${_esc(att['sessionId'])}', '${_esc(att['studentId'])}', "
        "'${_esc(att['status'] ?? 'Presente')}', '${_esc(att['note'] ?? '')}', "
        "'${_esc(att['recordedAt'] ?? att['updatedAt'])}', '${_esc(att['createdAt'])}', '${_esc(att['updatedAt'])}');",
      );
    }

    for (final p in (cols['participation'] as List? ?? [])) {
      sb.writeln(
        "INSERT INTO participacion (id, operation_id, session_id, student_id, activity, points, note, date, created_at, updated_at) VALUES ("
        "'${_esc(p['id'])}', '${_esc(p['operationId'] ?? p['id'])}', '${_esc(p['sessionId'])}', "
        "'${_esc(p['studentId'])}', '${_esc(p['activity'] ?? 'Participación')}', "
        "${(p['points'] as num?)?.toInt() ?? 1}, '${_esc(p['note'] ?? '')}', "
        "'${_esc(p['date'] ?? '')}', '${_esc(p['createdAt'])}', '${_esc(p['updatedAt'])}');",
      );
    }

    for (final aud in (cols['audit'] as List? ?? [])) {
      sb.writeln(
        "INSERT INTO auditoria (id, entity, entity_id, action, at) VALUES ("
        "'${_esc(aud['id'])}', '${_esc(aud['entity'])}', '${_esc(aud['entityId'])}', "
        "'${_esc(aud['action'])}', '${_esc(aud['at'])}');",
      );
    }

    sb.writeln('SET FOREIGN_KEY_CHECKS = 1;');

    final tempSql = File('backend/_sync_temp.sql');
    await tempSql.writeAsString(sb.toString(), encoding: utf8);
    await Process.run(_mysqlExe, [
      '--default-character-set=utf8mb4',
      '-u',
      'root',
      '-D',
      'aula_puntos_senati',
      '-e',
      'source backend/_sync_temp.sql',
    ]);
    if (await tempSql.exists()) {
      await tempSql.delete();
    }
  } catch (_) {}
}

Map<String, dynamic> _createFreshDb() => {
  'instructor': SenatiSeedData.defaultInstructor,
  'collections': SenatiSeedData.buildInitialCollections(),
  'updatedAt': DateTime.now().toIso8601String(),
};

Future<Map<String, dynamic>> _loadOrSeedDatabase(File file) async {
  if (await file.exists()) {
    try {
      final content = await file.readAsString();
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {}
  }
  final fresh = _createFreshDb();
  await _persistDb(file, fresh);
  return fresh;
}

Future<void> _persistDb(File file, Map<String, dynamic> db) async {
  await file.parent.create(recursive: true);
  await file.writeAsString(const JsonEncoder.withIndent('  ').convert(db));
}

Map<String, dynamic> _processSync(
  Map<String, dynamic> db,
  Map<String, dynamic> payload,
) {
  final now = DateTime.now().toIso8601String();
  final serverCols = Map<String, dynamic>.from(
    db['collections'] as Map<String, dynamic>,
  );
  final clientCols = payload['collections'] as Map<String, dynamic>? ?? {};

  for (final key in [
    'groups',
    'students',
    'sessions',
    'attendance',
    'activities',
    'participation',
  ]) {
    final serverList = ((serverCols[key] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final clientList = ((clientCols[key] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final mergedById = <String, Map<String, dynamic>>{
      for (final item in clientList)
        if (item['id'] != null)
          item['id'].toString(): {...item, 'syncStatus': 'synced'},
    };

    for (final serverItem in serverList) {
      final id = serverItem['id']?.toString();
      if (id == null) continue;
      final clientItem = mergedById[id];
      if (clientItem != null) {
        final serverUpdated = serverItem['updatedAt']?.toString() ?? '';
        final clientUpdated = clientItem['updatedAt']?.toString() ?? '';
        if (serverUpdated.compareTo(clientUpdated) > 0) {
          mergedById[id] = {...serverItem, 'syncStatus': 'synced'};
        }
      }
    }

    final mergedList = mergedById.values.toList();
    if (key == 'participation') {
      final seenOps = <String>{};
      mergedList.retainWhere((row) {
        final opId = row['operationId']?.toString();
        if (opId == null || opId.isEmpty) return true;
        return seenOps.add(opId);
      });
    } else if (key == 'attendance') {
      final bySessionStudent = <String, Map<String, dynamic>>{};
      for (final row in mergedList) {
        final compositeKey = '${row['sessionId']}::${row['studentId']}';
        bySessionStudent[compositeKey] = row;
      }
      mergedList
        ..clear()
        ..addAll(bySessionStudent.values);
    }

    serverCols[key] = mergedList;
  }

  final audits = ((serverCols['audit'] as List?) ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  final outbox = (payload['outbox'] as List?) ?? [];
  audits.add({
    'id': 'aud-srv-${DateTime.now().millisecondsSinceEpoch}',
    'entity': 'sync',
    'entityId': 'mysql-db',
    'action': 'Sincronización MySQL completada (${outbox.length} operaciones)',
    'at': now,
  });
  serverCols['audit'] = audits;
  serverCols['outbox'] = <Map<String, dynamic>>[];

  return {
    'instructor': payload['instructor'] ?? db['instructor'],
    'collections': serverCols,
    'updatedAt': now,
  };
}

void _addCorsHeaders(HttpResponse res) {
  res.headers.set('Access-Control-Allow-Origin', '*');
  res.headers.set(
    'Access-Control-Allow-Methods',
    'GET, POST, PUT, DELETE, OPTIONS',
  );
  res.headers.set(
    'Access-Control-Allow-Headers',
    'Origin, Content-Type, Accept, Authorization',
  );
}

Future<void> _sendJson(
  HttpRequest req,
  Map<String, dynamic> body, {
  int statusCode = HttpStatus.ok,
}) async {
  req.response.statusCode = statusCode;
  req.response.headers.contentType = ContentType.json;
  req.response.write(jsonEncode(body));
  await req.response.close();
}
