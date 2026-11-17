# Aula Puntos – SENATI

Aplicación Flutter multiplataforma (Android y Web) con servidor API REST y esquema de base de datos relacional para la gestión académica de instructores de **SENATI** (Escuela de Tecnologías de la Información).

Incluye módulos completos y funcionales de **Panel del Instructor, Grupos SENATI, Estudiantes, Sesiones Académicas, Control de Asistencia (P/T/F/J), Puntuación Rápida (+1/+2/+3) e Historial de Participación, Reportes Consolidados (PDF y Excel) y Configuración con Sincronización API REST**.

## Datos Académicos Reales Precargados

Al iniciar por primera vez (o desde *Configuración → Restaurar datos SENATI*), el sistema carga automáticamente los datos del Caso Práctico **Aula Puntos – SENATI**:

- **Instructor:** Jorge Luque Chambi (`jluque@senati.pe` · CFP Independencia)
- **Grupos SENATI:**
  - `202601` — `FORMACION MONITORES EMPRESA` (Sección `2026-20-202601`)
  - `PAWD-403` — `APLICACIONES PARA DISPOSITIVOS MOVILES` (Sección `2026-20-PAWD403`)
  - `INGSW-502` — `ANALISIS Y DISEÑO DE SISTEMAS` (Sección `2026-20-INGSW502`)
- **Estudiantes con ID institucional:** Incluye los integrantes del grupo `202601` (`001507084` Caballero Huanaquiri, `001607280` Campomanes Capristano, `001591227` Castromonte, `001286163` Hancco Huarhuachi, `001556472` Huayta Tinoco, `001131690` Mendo Muñoz, `001593789` Nuñez Herrera) y de `PAWD-403` e `INGSW-502`.
- **Sesiones, asistencias, actividades configurables y participaciones** con trazabilidad en auditoría.

## Ejecución del Proyecto

### 1. Iniciar el Servidor Backend API REST (Opcional para sincronización en red/local)

```sh
dart run backend/server.dart
```

El servidor queda activo en `http://localhost:8080/api` y persiste los datos en `backend/aula_puntos_db.json`. El esquema relacional SQL Server se encuentra en `backend/sql_server_schema.sql`.

### 2. Ejecutar la Aplicación Flutter

```sh
flutter pub get
flutter run -d edge
```

*(La aplicación funciona al 100% tanto conectada al servidor API REST como en modo offline/local gracias a su persistencia en `SharedPreferencesAsync`).*

## Verificación y Compilación

```sh
flutter analyze
flutter test
flutter build web
flutter build apk --release
```
