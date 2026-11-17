-- ============================================================================
-- BASE DE DATOS MYSQL: aula_puntos_senati (XAMPP / MySQL / MariaDB)
-- Caso Práctico: Aula Puntos – SENATI (Escuela de Tecnologías de la Información)
-- ============================================================================

DROP DATABASE IF EXISTS aula_puntos_senati;
CREATE DATABASE aula_puntos_senati CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE aula_puntos_senati;

-- 1. Tabla de Usuarios y Roles (Login de Instructor y Administrador)
CREATE TABLE usuarios (
    id VARCHAR(50) PRIMARY KEY,
    username VARCHAR(60) NOT NULL UNIQUE,
    email VARCHAR(120) NOT NULL UNIQUE,
    password_plain VARCHAR(100) NOT NULL,
    name VARCHAR(150) NOT NULL,
    role VARCHAR(80) NOT NULL,
    campus VARCHAR(120) NOT NULL,
    active TINYINT(1) NOT NULL DEFAULT 1,
    created_at VARCHAR(40) NOT NULL
) ENGINE=InnoDB;

-- 2. Tabla de Grupos Académicos SENATI
CREATE TABLE grupos (
    id VARCHAR(50) PRIMARY KEY,
    code VARCHAR(40) NOT NULL UNIQUE,
    name VARCHAR(180) NOT NULL,
    program VARCHAR(50) NOT NULL,
    period VARCHAR(50) NOT NULL,
    section VARCHAR(80) NOT NULL,
    instructor_id VARCHAR(50) NOT NULL,
    active TINYINT(1) NOT NULL DEFAULT 1,
    created_at VARCHAR(40) NOT NULL,
    updated_at VARCHAR(40) NOT NULL
) ENGINE=InnoDB;

-- 3. Tabla de Estudiantes SENATI
CREATE TABLE estudiantes (
    id VARCHAR(50) PRIMARY KEY,
    code VARCHAR(40) NOT NULL UNIQUE,
    name VARCHAR(180) NOT NULL,
    email VARCHAR(140) NOT NULL,
    group_id VARCHAR(50) NOT NULL,
    active TINYINT(1) NOT NULL DEFAULT 1,
    created_at VARCHAR(40) NOT NULL,
    updated_at VARCHAR(40) NOT NULL,
    CONSTRAINT fk_estudiante_grupo FOREIGN KEY (group_id) REFERENCES grupos(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 4. Tabla de Actividades Puntuables
CREATE TABLE actividades (
    id VARCHAR(50) PRIMARY KEY,
    name VARCHAR(120) NOT NULL UNIQUE,
    description VARCHAR(255) DEFAULT '',
    value_points INT NOT NULL DEFAULT 1,
    max_points INT NOT NULL DEFAULT 20,
    active TINYINT(1) NOT NULL DEFAULT 1,
    created_at VARCHAR(40) NOT NULL,
    updated_at VARCHAR(40) NOT NULL
) ENGINE=InnoDB;

-- 5. Tabla de Sesiones Académicas
CREATE TABLE sesiones (
    id VARCHAR(50) PRIMARY KEY,
    group_id VARCHAR(50) NOT NULL,
    session_number INT NOT NULL DEFAULT 1,
    topic VARCHAR(220) NOT NULL,
    type VARCHAR(80) NOT NULL,
    duration_hours INT NOT NULL DEFAULT 4,
    date VARCHAR(20) NOT NULL,
    notes VARCHAR(300) DEFAULT '',
    created_at VARCHAR(40) NOT NULL,
    updated_at VARCHAR(40) NOT NULL,
    CONSTRAINT fk_sesion_grupo FOREIGN KEY (group_id) REFERENCES grupos(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 6. Tabla de Control de Asistencia (1 registro vigente por estudiante y sesión)
CREATE TABLE asistencia (
    id VARCHAR(60) PRIMARY KEY,
    session_id VARCHAR(50) NOT NULL,
    student_id VARCHAR(50) NOT NULL,
    status ENUM('Presente', 'Tardanza', 'Falta', 'Justificado') NOT NULL,
    note VARCHAR(300) DEFAULT '',
    recorded_at VARCHAR(40) NOT NULL,
    created_at VARCHAR(40) NOT NULL,
    updated_at VARCHAR(40) NOT NULL,
    UNIQUE KEY uq_asistencia_sesion_estudiante (session_id, student_id),
    CONSTRAINT fk_asistencia_sesion FOREIGN KEY (session_id) REFERENCES sesiones(id) ON DELETE CASCADE,
    CONSTRAINT fk_asistencia_estudiante FOREIGN KEY (student_id) REFERENCES estudiantes(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 7. Tabla de Participación y Puntos (con operation_id para evitar duplicados)
CREATE TABLE participacion (
    id VARCHAR(60) PRIMARY KEY,
    operation_id VARCHAR(80) NOT NULL UNIQUE,
    session_id VARCHAR(50) NOT NULL,
    student_id VARCHAR(50) NOT NULL,
    activity VARCHAR(120) NOT NULL,
    points INT NOT NULL,
    note VARCHAR(300) DEFAULT '',
    date VARCHAR(20) NOT NULL,
    created_at VARCHAR(40) NOT NULL,
    updated_at VARCHAR(40) NOT NULL,
    CONSTRAINT fk_part_sesion FOREIGN KEY (session_id) REFERENCES sesiones(id) ON DELETE CASCADE,
    CONSTRAINT fk_part_estudiante FOREIGN KEY (student_id) REFERENCES estudiantes(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 8. Tabla de Auditoría y Trazabilidad
CREATE TABLE auditoria (
    id VARCHAR(60) PRIMARY KEY,
    entity VARCHAR(50) NOT NULL,
    entity_id VARCHAR(80) NOT NULL,
    action VARCHAR(255) NOT NULL,
    at VARCHAR(40) NOT NULL
) ENGINE=InnoDB;

-- ============================================================================
-- INSERCIÓN DE DATOS REALES DEL CASO PRÁCTICO SENATI
-- ============================================================================

INSERT INTO usuarios (id, username, email, password_plain, name, role, campus, active, created_at) VALUES
('inst-senati-01', 'jluque', 'jluque@senati.pe', '123456', 'Jorge Luque Chambi', 'Instructor – Escuela de Tecnologías de la Información', 'SENATI · CFP Independencia', 1, '2026-11-10T08:00:00.000'),
('adm-senati-01', 'admin', 'admin@senati.pe', 'admin123', 'Coordinación Académica TI', 'Administrador del Sistema – Escuela TI', 'SENATI · Sede Central Independencia', 1, '2026-11-10T08:00:00.000');

INSERT INTO grupos (id, code, name, program, period, section, instructor_id, active, created_at, updated_at) VALUES
('grp-202601', '202601', 'FORMACION MONITORES EMPRESA', '2026-20', '2026-20', '2026-20-202601', 'inst-senati-01', 1, '2026-11-10T08:00:00.000', '2026-11-10T08:00:00.000'),
('grp-pawd403', 'PAWD-403', 'APLICACIONES PARA DISPOSITIVOS MOVILES', '2026-20', '2026-20', '2026-20-PAWD403', 'inst-senati-01', 1, '2026-11-10T08:00:00.000', '2026-11-10T08:00:00.000'),
('grp-ingsw502', 'INGSW-502', 'ANALISIS Y DISEÑO DE SISTEMAS', '2026-20', '2026-20', '2026-20-INGSW502', 'inst-senati-01', 1, '2026-11-10T08:00:00.000', '2026-11-10T08:00:00.000');

INSERT INTO estudiantes (id, code, name, email, group_id, active, created_at, updated_at) VALUES
('est-001507084', '001507084', 'CABALLERO HUANAQUIRI, JULIANA FRANCESCA', '001507084@senati.pe', 'grp-202601', 1, '2026-11-10T08:00:00.000', '2026-11-10T08:00:00.000'),
('est-001607280', '001607280', 'CAMPOMANES CAPRISTANO, CHRISTIAN ANGEL', '001607280@senati.pe', 'grp-202601', 1, '2026-11-10T08:00:00.000', '2026-11-10T08:00:00.000'),
('est-001591227', '001591227', 'CASTROMONTE, JULIO BRANDO', '001591227@senati.pe', 'grp-202601', 1, '2026-11-10T08:00:00.000', '2026-11-10T08:00:00.000'),
('est-001286163', '001286163', 'HANCCO HUARHUACHI, PAOLO CESAR', '001286163@senati.pe', 'grp-202601', 1, '2026-11-10T08:00:00.000', '2026-11-10T08:00:00.000'),
('est-001556472', '001556472', 'HUAYTA TINOCO, ARIANNA GUADALUPE', '001556472@senati.pe', 'grp-202601', 1, '2026-11-10T08:00:00.000', '2026-11-10T08:00:00.000'),
('est-001131690', '001131690', 'MENDO MUÑOZ, AXEL PAOLO', '001131690@senati.pe', 'grp-202601', 1, '2026-11-10T08:00:00.000', '2026-11-10T08:00:00.000'),
('est-001593789', '001593789', 'NUÑEZ HERRERA, SALVADOR SANTIAGO', '001593789@senati.pe', 'grp-202601', 1, '2026-11-10T08:00:00.000', '2026-11-10T08:00:00.000'),
('est-001482910', '001482910', 'SAAVEDRA ALONSO, XIOMARA', '001482910@senati.pe', 'grp-pawd403', 1, '2026-11-10T08:00:00.000', '2026-11-10T08:00:00.000'),
('est-20260101', '20260101', 'PEREZ GOMEZ, JUAN', '20260101@senati.pe', 'grp-pawd403', 1, '2026-11-10T08:00:00.000', '2026-11-10T08:00:00.000'),
('est-20260102', '20260102', 'LOPEZ TORRES, MARIA', '20260102@senati.pe', 'grp-pawd403', 1, '2026-11-10T08:00:00.000', '2026-11-10T08:00:00.000'),
('est-20260103', '20260103', 'SILVA ROJAS, CARLOS', '20260103@senati.pe', 'grp-pawd403', 1, '2026-11-10T08:00:00.000', '2026-11-10T08:00:00.000'),
('est-001523401', '001523401', 'QUISPE MAMANI, DIEGO ALONSO', '001523401@senati.pe', 'grp-ingsw502', 1, '2026-11-10T08:00:00.000', '2026-11-10T08:00:00.000'),
('est-001539812', '001539812', 'VARGAS ROJAS, VALERIA NICOLE', '001539812@senati.pe', 'grp-ingsw502', 1, '2026-11-10T08:00:00.000', '2026-11-10T08:00:00.000'),
('est-001544109', '001544109', 'MENDOZA CASTILLO, LUIS FERNANDO', '001544109@senati.pe', 'grp-ingsw502', 1, '2026-11-10T08:00:00.000', '2026-11-10T08:00:00.000');

INSERT INTO actividades (id, name, description, value_points, max_points, active, created_at, updated_at) VALUES
('act-participacion', 'Participación en clase', 'Intervención oral y aportes técnicos durante la sesión', 2, 20, 1, '2026-11-10T08:00:00.000', '2026-11-10T08:00:00.000'),
('act-ejercicios', 'Resolución de ejercicios', 'Desarrollo correcto de casos prácticos propuestos', 3, 20, 1, '2026-11-10T08:00:00.000', '2026-11-10T08:00:00.000'),
('act-equipo', 'Trabajo en equipo', 'Colaboración efectiva en dinámicas grupales de taller', 3, 20, 1, '2026-11-10T08:00:00.000', '2026-11-10T08:00:00.000'),
('act-exposicion', 'Exposición', 'Sustentación de entregables y diagramas de arquitectura', 5, 20, 1, '2026-11-10T08:00:00.000', '2026-11-10T08:00:00.000'),
('act-practica', 'Actividad práctica', 'Implementación funcional en laboratorio de cómputo', 4, 20, 1, '2026-11-10T08:00:00.000', '2026-11-10T08:00:00.000');

INSERT INTO sesiones (id, group_id, session_number, topic, type, duration_hours, date, notes, created_at, updated_at) VALUES
('ses-202601-01', 'grp-202601', 1, 'FORMACION DUAL SENATI', 'Teoría (Tecnología)', 4, '2026-11-10', 'CLASE 01', '2026-11-10T08:00:00.000', '2026-11-10T08:00:00.000'),
('ses-202601-02', 'grp-202601', 2, 'PLAN ESPECIFICO DE APRENDIZAJE (PEA) Y MONITOREO', 'Taller / Práctica', 4, '2026-11-13', 'CLASE 02 - Evaluación participativa en empresa', '2026-11-13T08:00:00.000', '2026-11-13T08:00:00.000'),
('ses-pawd403-01', 'grp-pawd403', 1, 'ARQUITECTURA FLUTTER Y MATERIAL DESIGN 3', 'Laboratorio TI', 5, '2026-11-11', 'Diseño adaptativo para Android y Web', '2026-11-11T08:30:00.000', '2026-11-11T08:30:00.000'),
('ses-pawd403-02', 'grp-pawd403', 2, 'PERSISTENCIA OFFLINE Y SINCRONIZACION API REST', 'Laboratorio TI', 5, '2026-11-13', 'Caso Práctico Aula Puntos – SENATI', '2026-11-13T09:00:00.000', '2026-11-13T09:00:00.000'),
('ses-ingsw502-01', 'grp-ingsw502', 1, 'MODELADO ENTIDAD-RELACION Y REGLAS DE NEGOCIO', 'Teoría (Tecnología)', 4, '2026-11-12', 'Casos de uso, diccionario de datos y trazabilidad', '2026-11-12T08:00:00.000', '2026-11-12T08:00:00.000');

INSERT INTO asistencia (id, session_id, student_id, status, note, recorded_at, created_at, updated_at) VALUES
('att-s1-est-001507084', 'ses-202601-01', 'est-001507084', 'Presente', 'Asistencia puntual en sesión inaugural', '2026-11-10T08:15:00.000', '2026-11-10T08:15:00.000', '2026-11-10T08:15:00.000'),
('att-s1-est-001607280', 'ses-202601-01', 'est-001607280', 'Presente', 'Asistencia puntual en sesión inaugural', '2026-11-10T08:15:00.000', '2026-11-10T08:15:00.000', '2026-11-10T08:15:00.000'),
('att-s1-est-001591227', 'ses-202601-01', 'est-001591227', 'Presente', 'Asistencia puntual en sesión inaugural', '2026-11-10T08:15:00.000', '2026-11-10T08:15:00.000', '2026-11-10T08:15:00.000'),
('att-s1-est-001286163', 'ses-202601-01', 'est-001286163', 'Presente', 'Asistencia puntual en sesión inaugural', '2026-11-10T08:15:00.000', '2026-11-10T08:15:00.000', '2026-11-10T08:15:00.000'),
('att-s1-est-001556472', 'ses-202601-01', 'est-001556472', 'Presente', 'Asistencia puntual en sesión inaugural', '2026-11-10T08:15:00.000', '2026-11-10T08:15:00.000', '2026-11-10T08:15:00.000'),
('att-s1-est-001131690', 'ses-202601-01', 'est-001131690', 'Presente', 'Asistencia puntual en sesión inaugural', '2026-11-10T08:15:00.000', '2026-11-10T08:15:00.000', '2026-11-10T08:15:00.000'),
('att-s1-est-001593789', 'ses-202601-01', 'est-001593789', 'Presente', 'Asistencia puntual en sesión inaugural', '2026-11-10T08:15:00.000', '2026-11-10T08:15:00.000', '2026-11-10T08:15:00.000'),
('att-s2-est-001507084', 'ses-202601-02', 'est-001507084', 'Presente', '', '2026-11-13T08:10:00.000', '2026-11-13T08:10:00.000', '2026-11-13T08:10:00.000'),
('att-s2-est-001607280', 'ses-202601-02', 'est-001607280', 'Presente', '', '2026-11-13T08:10:00.000', '2026-11-13T08:10:00.000', '2026-11-13T08:10:00.000'),
('att-s2-est-001591227', 'ses-202601-02', 'est-001591227', 'Tardanza', 'Ingreso 12 minutos después del inicio', '2026-11-13T08:12:00.000', '2026-11-13T08:12:00.000', '2026-11-13T08:12:00.000'),
('att-s2-est-001286163', 'ses-202601-02', 'est-001286163', 'Presente', '', '2026-11-13T08:10:00.000', '2026-11-13T08:10:00.000', '2026-11-13T08:10:00.000'),
('att-s2-est-001556472', 'ses-202601-02', 'est-001556472', 'Presente', '', '2026-11-13T08:10:00.000', '2026-11-13T08:10:00.000', '2026-11-13T08:10:00.000'),
('att-s2-est-001131690', 'ses-202601-02', 'est-001131690', 'Justificado', 'Trámite de convenio de práctica dual en empresa', '2026-11-13T08:14:00.000', '2026-11-13T08:14:00.000', '2026-11-13T08:14:00.000'),
('att-s2-est-001593789', 'ses-202601-02', 'est-001593789', 'Presente', '', '2026-11-13T08:10:00.000', '2026-11-13T08:10:00.000', '2026-11-13T08:10:00.000'),
('att-pawd1-est-001482910', 'ses-pawd403-01', 'est-001482910', 'Presente', '', '2026-11-11T08:40:00.000', '2026-11-11T08:40:00.000', '2026-11-11T08:40:00.000'),
('att-pawd2-est-001482910', 'ses-pawd403-02', 'est-001482910', 'Presente', '', '2026-11-13T09:10:00.000', '2026-11-13T09:10:00.000', '2026-11-13T09:10:00.000'),
('att-pawd1-est-20260101', 'ses-pawd403-01', 'est-20260101', 'Presente', '', '2026-11-11T08:40:00.000', '2026-11-11T08:40:00.000', '2026-11-11T08:40:00.000'),
('att-pawd2-est-20260101', 'ses-pawd403-02', 'est-20260101', 'Presente', '', '2026-11-13T09:10:00.000', '2026-11-13T09:10:00.000', '2026-11-13T09:10:00.000'),
('att-pawd1-est-20260102', 'ses-pawd403-01', 'est-20260102', 'Presente', '', '2026-11-11T08:40:00.000', '2026-11-11T08:40:00.000', '2026-11-11T08:40:00.000'),
('att-pawd2-est-20260102', 'ses-pawd403-02', 'est-20260102', 'Presente', '', '2026-11-13T09:10:00.000', '2026-11-13T09:10:00.000', '2026-11-13T09:10:00.000'),
('att-pawd1-est-20260103', 'ses-pawd403-01', 'est-20260103', 'Presente', '', '2026-11-11T08:40:00.000', '2026-11-11T08:40:00.000', '2026-11-11T08:40:00.000'),
('att-pawd2-est-20260103', 'ses-pawd403-02', 'est-20260103', 'Tardanza', '', '2026-11-13T09:10:00.000', '2026-11-13T09:10:00.000', '2026-11-13T09:10:00.000'),
('att-ingsw1-est-001523401', 'ses-ingsw502-01', 'est-001523401', 'Presente', '', '2026-11-12T08:15:00.000', '2026-11-12T08:15:00.000', '2026-11-12T08:15:00.000'),
('att-ingsw1-est-001539812', 'ses-ingsw502-01', 'est-001539812', 'Presente', '', '2026-11-12T08:15:00.000', '2026-11-12T08:15:00.000', '2026-11-12T08:15:00.000'),
('att-ingsw1-est-001544109', 'ses-ingsw502-01', 'est-001544109', 'Presente', '', '2026-11-12T08:15:00.000', '2026-11-12T08:15:00.000', '2026-11-12T08:15:00.000');

INSERT INTO participacion (id, operation_id, session_id, student_id, activity, points, note, date, created_at, updated_at) VALUES
('part-01', 'op-seed-01', 'ses-202601-01', 'est-001507084', 'Participación en clase', 3, 'Aporte sobre normativa de formación práctica en empresa', '2026-11-10', '2026-11-10T09:20:00.000', '2026-11-10T09:20:00.000'),
('part-02', 'op-seed-02', 'ses-202601-01', 'est-001607280', 'Resolución de ejercicios', 3, 'Análisis completo del cuaderno de informe semanal', '2026-11-10', '2026-11-10T09:45:00.000', '2026-11-10T09:45:00.000'),
('part-03', 'op-seed-03', 'ses-202601-01', 'est-001286163', 'Trabajo en equipo', 4, 'Coordinación de grupo en estudio de caso dual', '2026-11-10', '2026-11-10T10:15:00.000', '2026-11-10T10:15:00.000'),
('part-04', 'op-seed-04', 'ses-202601-02', 'est-001507084', 'Exposición', 5, 'Sustentación de indicadores del PEA y rotación', '2026-11-13', '2026-11-13T09:10:00.000', '2026-11-13T09:10:00.000'),
('part-05', 'op-seed-05', 'ses-202601-02', 'est-001556472', 'Participación en clase', 3, 'Intervención destacada sobre seguridad industrial', '2026-11-13', '2026-11-13T09:30:00.000', '2026-11-13T09:30:00.000'),
('part-06', 'op-seed-06', 'ses-202601-02', 'est-001591227', 'Actividad práctica', 4, 'Elaboración de matriz de seguimiento de aprendices', '2026-11-13', '2026-11-13T10:00:00.000', '2026-11-13T10:00:00.000'),
('part-07', 'op-seed-07', 'ses-202601-02', 'est-001593789', 'Participación en clase', 2, 'Respuesta correcta en repaso de sesión', '2026-11-13', '2026-11-13T10:20:00.000', '2026-11-13T10:20:00.000'),
('part-08', 'op-seed-08', 'ses-pawd403-01', 'est-001482910', 'Actividad práctica', 10, 'Prototipo y navegación Material 3 completados al 100%', '2026-11-11', '2026-11-11T10:00:00.000', '2026-11-11T10:00:00.000'),
('part-09', 'op-seed-09', 'ses-pawd403-02', 'est-001482910', 'Exposición', 8, 'Demostración de sincronización offline/online y APK', '2026-11-13', '2026-11-13T10:00:00.000', '2026-11-13T10:00:00.000'),
('part-10', 'op-seed-10', 'ses-pawd403-01', 'est-20260101', 'Actividad práctica', 16, 'Implementación completa de vistas y validaciones', '2026-11-11', '2026-11-11T10:15:00.000', '2026-11-11T10:15:00.000'),
('part-11', 'op-seed-11', 'ses-pawd403-01', 'est-20260102', 'Exposición', 16, 'Sustentación de arquitectura y exportación PDF/Excel', '2026-11-11', '2026-11-11T10:30:00.000', '2026-11-11T10:30:00.000'),
('part-12', 'op-seed-12', 'ses-pawd403-02', 'est-20260103', 'Resolución de ejercicios', 9, 'Desarrollo de pruebas unitarias de almacenamiento', '2026-11-13', '2026-11-13T10:15:00.000', '2026-11-13T10:15:00.000'),
('part-13', 'op-seed-13', 'ses-ingsw502-01', 'est-001523401', 'Resolución de ejercicios', 5, 'Diseño de modelo E-R de 9 entidades sin inconsistencias', '2026-11-12', '2026-11-12T09:40:00.000', '2026-11-12T09:40:00.000'),
('part-14', 'op-seed-14', 'ses-ingsw502-01', 'est-001539812', 'Exposición', 5, 'Presentación de diagrama de actividades y casos de uso', '2026-11-12', '2026-11-12T10:05:00.000', '2026-11-12T10:05:00.000');

INSERT INTO auditoria (id, entity, entity_id, action, at) VALUES
('aud-seed-01', 'system', 'seed-senati-2026', 'Carga inicial de base de datos MySQL SENATI', '2026-11-10T08:00:00.000'),
('aud-seed-02', 'attendance', 'ses-202601-01', 'Registro de asistencia completado (Grupo 202601 · Sesión 1)', '2026-11-10T08:15:00.000'),
('aud-seed-03', 'participation', 'part-04', 'Asignación de +5 pts en Exposición (CABALLERO HUANAQUIRI)', '2026-11-13T09:10:00.000');
