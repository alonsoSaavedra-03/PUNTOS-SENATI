-- ============================================================================
-- ESQUEMA DE BASE DE DATOS RELACIONAL: AULA PUNTOS – SENATI
-- Basado en las 9 entidades y reglas de negocio del Caso Práctico SENATI
-- Compatible con SQL Server / T-SQL
-- ============================================================================

CREATE TABLE UsuarioRol (
    UsuarioId VARCHAR(50) PRIMARY KEY,
    Username VARCHAR(80) NOT NULL UNIQUE,
    PasswordHash VARCHAR(256) NOT NULL,
    Rol VARCHAR(30) NOT NULL CHECK (Rol IN ('Instructor', 'Administrador')),
    Estado BIT NOT NULL DEFAULT 1,
    FechaCreacion DATETIME2 NOT NULL DEFAULT SYSDATETIME()
);

CREATE TABLE Instructor (
    InstructorId VARCHAR(50) PRIMARY KEY,
    UsuarioId VARCHAR(50) NULL REFERENCES UsuarioRol(UsuarioId),
    Nombres VARCHAR(100) NOT NULL,
    Apellidos VARCHAR(100) NOT NULL,
    Correo VARCHAR(120) NOT NULL UNIQUE,
    Especialidad VARCHAR(150) NOT NULL,
    Sede VARCHAR(120) NOT NULL,
    Estado BIT NOT NULL DEFAULT 1
);

CREATE TABLE Grupo (
    GrupoId VARCHAR(50) PRIMARY KEY,
    Codigo VARCHAR(30) NOT NULL UNIQUE,
    Nombre VARCHAR(160) NOT NULL,
    Programa VARCHAR(40) NOT NULL,
    Periodo VARCHAR(40) NOT NULL,
    Seccion VARCHAR(60) NOT NULL,
    InstructorId VARCHAR(50) NOT NULL REFERENCES Instructor(InstructorId),
    Estado BIT NOT NULL DEFAULT 1
);

CREATE TABLE Estudiante (
    EstudianteId VARCHAR(50) PRIMARY KEY,
    CodigoInstitucional VARCHAR(30) NOT NULL UNIQUE,
    NombresApellidos VARCHAR(180) NOT NULL,
    Correo VARCHAR(120) NULL,
    Estado BIT NOT NULL DEFAULT 1
);

CREATE TABLE GrupoEstudiante (
    GrupoId VARCHAR(50) NOT NULL REFERENCES Grupo(GrupoId),
    EstudianteId VARCHAR(50) NOT NULL REFERENCES Estudiante(EstudianteId),
    FechaIncorporacion DATE NOT NULL DEFAULT CAST(SYSDATETIME() AS DATE),
    Estado BIT NOT NULL DEFAULT 1,
    PRIMARY KEY (GrupoId, EstudianteId)
);

CREATE TABLE Sesion (
    SesionId VARCHAR(50) PRIMARY KEY,
    GrupoId VARCHAR(50) NOT NULL REFERENCES Grupo(GrupoId),
    NumeroSesion INT NOT NULL,
    Fecha DATE NOT NULL,
    Tema VARCHAR(220) NOT NULL,
    TipoSesion VARCHAR(60) NOT NULL,
    DuracionHoras INT NOT NULL DEFAULT 4,
    Observaciones VARCHAR(300) NULL,
    Estado BIT NOT NULL DEFAULT 1
);

CREATE TABLE Asistencia (
    AsistenciaId VARCHAR(50) PRIMARY KEY,
    SesionId VARCHAR(50) NOT NULL REFERENCES Sesion(SesionId),
    EstudianteId VARCHAR(50) NOT NULL REFERENCES Estudiante(EstudianteId),
    Estado VARCHAR(20) NOT NULL CHECK (Estado IN ('Presente', 'Tardanza', 'Falta', 'Justificado')),
    FechaRegistro DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    Observacion VARCHAR(300) NULL,
    CONSTRAINT UQ_Asistencia_Sesion_Estudiante UNIQUE (SesionId, EstudianteId)
);

CREATE TABLE Actividad (
    ActividadId VARCHAR(50) PRIMARY KEY,
    Nombre VARCHAR(120) NOT NULL UNIQUE,
    Descripcion VARCHAR(250) NULL,
    ValorPuntos INT NOT NULL CHECK (ValorPuntos BETWEEN 0 AND 100),
    Estado BIT NOT NULL DEFAULT 1
);

CREATE TABLE Participacion (
    ParticipacionId VARCHAR(50) PRIMARY KEY,
    OperationId VARCHAR(80) NOT NULL UNIQUE,
    SesionId VARCHAR(50) NOT NULL REFERENCES Sesion(SesionId),
    EstudianteId VARCHAR(50) NOT NULL REFERENCES Estudiante(EstudianteId),
    ActividadId VARCHAR(50) NOT NULL REFERENCES Actividad(ActividadId),
    Puntos INT NOT NULL CHECK (Puntos BETWEEN 0 AND 100),
    Fecha DATE NOT NULL,
    Observacion VARCHAR(300) NULL
);

-- Datos Iniciales SENATI
INSERT INTO Instructor (InstructorId, Nombres, Apellidos, Correo, Especialidad, Sede, Estado)
VALUES ('inst-senati-01', 'Jorge', 'Luque Chambi', 'jluque@senati.pe', 'Escuela de Tecnologías de la Información', 'SENATI - CFP Independencia', 1);

INSERT INTO Grupo (GrupoId, Codigo, Nombre, Programa, Periodo, Seccion, InstructorId, Estado) VALUES
('grp-202601', '202601', 'FORMACION MONITORES EMPRESA', '2026-20', '2026-20', '2026-20-202601', 'inst-senati-01', 1),
('grp-pawd403', 'PAWD-403', 'APLICACIONES PARA DISPOSITIVOS MOVILES', '2026-20', '2026-20', '2026-20-PAWD403', 'inst-senati-01', 1),
('grp-ingsw502', 'INGSW-502', 'ANALISIS Y DISEÑO DE SISTEMAS', '2026-20', '2026-20', '2026-20-INGSW502', 'inst-senati-01', 1);
