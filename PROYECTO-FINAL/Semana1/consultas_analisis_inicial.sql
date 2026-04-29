-- ============================================================
--  Base: OLTP_Universidad_Transact
--  Módulo: ACADÉMICO (Dashboards ejecutivo y operativo)
-- ============================================================

USE OLTP_Universidad_Transact;
GO

-- ════════════════════════════════════════════════════════════
--  BLOQUE 0 — RECONOCIMIENTO DE TABLAS FUENTE
--  ¿Qué tablas existen y cuántos registros tienen?
-- ════════════════════════════════════════════════════════════

-- QA-00: Listado completo de tablas del schema universidad
SELECT
    TABLE_NAME   AS tabla,
    TABLE_TYPE   AS tipo
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'universidad'
ORDER BY TABLE_TYPE, TABLE_NAME;
GO

-- QA-01: Conteo de registros por tabla
--        → Detecta tablas vacías antes de diseñar el ETL
SELECT 'estudiante'         AS tabla, COUNT(*) AS filas FROM universidad.estudiante        UNION ALL
SELECT 'persona',                     COUNT(*)           FROM universidad.persona           UNION ALL
SELECT 'carrera',                     COUNT(*)           FROM universidad.carrera           UNION ALL
SELECT 'facultad',                    COUNT(*)           FROM universidad.facultad          UNION ALL
SELECT 'materia',                     COUNT(*)           FROM universidad.materia           UNION ALL
SELECT 'plan_estudio',                COUNT(*)           FROM universidad.plan_estudio      UNION ALL
SELECT 'periodo_academico',           COUNT(*)           FROM universidad.periodo_academico UNION ALL
SELECT 'docente',                     COUNT(*)           FROM universidad.docente           UNION ALL
SELECT 'categoria_docente',           COUNT(*)           FROM universidad.categoria_docente UNION ALL
SELECT 'grupo',                       COUNT(*)           FROM universidad.grupo             UNION ALL
SELECT 'inscripcion',                 COUNT(*)           FROM universidad.inscripcion       UNION ALL
SELECT 'calificacion',                COUNT(*)           FROM universidad.calificacion      UNION ALL
SELECT 'asistencia',                  COUNT(*)           FROM universidad.asistencia        UNION ALL
SELECT 'evaluacion_docente',          COUNT(*)           FROM universidad.evaluacion_docente UNION ALL
SELECT 'genero',                      COUNT(*)           FROM universidad.genero            UNION ALL
SELECT 'estado_civil',                COUNT(*)           FROM universidad.estado_civil      UNION ALL
SELECT 'tipo_documento',              COUNT(*)           FROM universidad.tipo_documento    UNION ALL
SELECT 'municipio',                   COUNT(*)           FROM universidad.municipio         UNION ALL
SELECT 'departamento',                COUNT(*)           FROM universidad.departamento;
GO


-- ════════════════════════════════════════════════════════════
--  BLOQUE 1 — ANÁLISIS PARA dim_periodo
--  Justifica: granularidad año-semestre, campo nombre para label
-- ════════════════════════════════════════════════════════════

-- QA-02: Distribución de períodos académicos disponibles
--        → Confirma que el grano de la fact es por período
SELECT
    id_periodo,
    anio,
    semestre,
    nombre,
    fecha_inicio,
    fecha_fin,
    activo
FROM universidad.periodo_academico
ORDER BY anio, semestre;
GO

-- QA-03: ¿Cuántas inscripciones hay por período?
--        → Valida que existe actividad en cada período (fact no vacía)
SELECT
    pa.nombre                           AS periodo,
    pa.anio,
    pa.semestre,
    COUNT(i.id_inscripcion)             AS total_inscripciones,
    COUNT(DISTINCT i.id_estudiante)     AS estudiantes_distintos,
    COUNT(DISTINCT g.id_materia)        AS materias_distintas
FROM universidad.periodo_academico pa
LEFT JOIN universidad.grupo        g  ON g.id_periodo = pa.id_periodo
LEFT JOIN universidad.inscripcion  i  ON i.id_grupo   = g.id_grupo
GROUP BY pa.nombre, pa.anio, pa.semestre
ORDER BY pa.anio, pa.semestre;
GO


-- ════════════════════════════════════════════════════════════
--  BLOQUE 2 — ANÁLISIS PARA dim_estudiante
--  Justifica: fusión persona + estudiante + genero + municipio
-- ════════════════════════════════════════════════════════════

-- QA-04: Distribución de estudiantes por carrera, modalidad de ingreso y estado
--        → Motiva los atributos modalidad_ingreso y estado en dim_estudiante
--        → Soporta el visual "Distribución por modalidad de ingreso" (Dashboard 1)
SELECT
    c.nombre                            AS carrera,
    e.modalidad_ingreso,
    e.estado,
    COUNT(*)                            AS total_estudiantes
FROM universidad.estudiante e
JOIN universidad.carrera    c ON c.id_carrera = e.id_carrera
GROUP BY c.nombre, e.modalidad_ingreso, e.estado
ORDER BY c.nombre, e.modalidad_ingreso, e.estado;
GO

-- QA-05: Distribución por género
--        → Valida que id_genero en persona no tiene NULLs masivos
SELECT
    g.descripcion                       AS genero,
    COUNT(*)                            AS cantidad,
    ROUND(COUNT(*) * 100.0
        / (SELECT COUNT(*) FROM universidad.persona), 1) AS pct
FROM universidad.persona p
LEFT JOIN universidad.genero g ON g.id_genero = p.id_genero
GROUP BY g.descripcion
ORDER BY cantidad DESC;
GO

-- QA-06: ¿Cuántos estudiantes no tienen municipio registrado?
--        → Detección de NULLs antes del ETL → fila "Sin dato" en dim_estudiante
SELECT
    COUNT(*) AS total_persona,
    SUM(CASE WHEN id_municipio IS NULL THEN 1 ELSE 0 END) AS sin_municipio,
    SUM(CASE WHEN id_genero    IS NULL THEN 1 ELSE 0 END) AS sin_genero,
    SUM(CASE WHEN fecha_nacimiento IS NULL THEN 1 ELSE 0 END) AS sin_fecha_nac
FROM universidad.persona;
GO


-- ════════════════════════════════════════════════════════════
--  BLOQUE 3 — ANÁLISIS PARA dim_materia
--  Justifica: incluir créditos, semestre_sugerido, horas como atributos
-- ════════════════════════════════════════════════════════════

-- QA-07: Materias activas de Ing. Sistemas ordenadas por créditos
--        → Muestra el rango de créditos y confirma semestre_sugerido
SELECT
    m.codigo,
    m.nombre                            AS materia,
    m.creditos,
    m.semestre_sugerido,
    m.horas_teoria,
    m.horas_practica,
    m.horas_teoria + m.horas_practica   AS horas_totales,
    m.activo
FROM universidad.materia    m
JOIN universidad.plan_estudio pe ON pe.id_plan    = m.id_plan
JOIN universidad.carrera      c  ON c.id_carrera  = pe.id_carrera
WHERE c.sigla = 'IS'
  AND pe.activo = 1
ORDER BY m.semestre_sugerido, m.creditos DESC;
GO

-- QA-08: ¿Hay materias sin plan de estudio activo?
--        → NULLs o inconsistencias que afectan al JOIN en el ETL
SELECT
    m.codigo,
    m.nombre,
    m.id_plan,
    pe.activo                           AS plan_activo
FROM universidad.materia m
LEFT JOIN universidad.plan_estudio pe ON pe.id_plan = m.id_plan
WHERE pe.activo = 0 OR pe.id_plan IS NULL;
GO


-- ════════════════════════════════════════════════════════════
--  BLOQUE 4 — ANÁLISIS PARA dim_docente
--  Justifica: fusión docente + persona + categoria_docente
-- ════════════════════════════════════════════════════════════

-- QA-09: Docentes activos por categoría y facultad
--        → Soporta "Top 5 docentes por evaluación" y "Carga docente" (Dashboards)
SELECT
    f.nombre                            AS facultad,
    cat.nombre                          AS categoria,
    d.titulo_maximo,
    COUNT(*)                            AS cantidad_docentes
FROM universidad.docente           d
JOIN universidad.facultad          f   ON f.id_facultad   = d.id_facultad
JOIN universidad.categoria_docente cat ON cat.id_categoria = d.id_categoria
WHERE d.activo = 1
GROUP BY f.nombre, cat.nombre, d.titulo_maximo
ORDER BY f.nombre, categoria, cantidad_docentes DESC;
GO

-- QA-10: Carga docente por período (grupos asignados)
--        → Soporta el panel "Carga docente actual" del Dashboard operativo
SELECT
    pa.nombre                           AS periodo,
    per.apellido_paterno + ', ' + per.nombres AS docente,
    cat.nombre                          AS categoria,
    COUNT(ad.id_grupo)                  AS grupos_asignados,
    SUM(m.creditos)                     AS creditos_a_cargo
FROM universidad.asignacion_docente ad
JOIN universidad.docente            d   ON d.id_docente    = ad.id_docente
JOIN universidad.persona            per ON per.id_persona  = d.id_persona
JOIN universidad.categoria_docente  cat ON cat.id_categoria = d.id_categoria
JOIN universidad.grupo              g   ON g.id_grupo      = ad.id_grupo
JOIN universidad.materia            m   ON m.id_materia    = g.id_materia
JOIN universidad.periodo_academico  pa  ON pa.id_periodo   = g.id_periodo
GROUP BY pa.nombre, pa.anio, pa.semestre,
         per.apellido_paterno, per.nombres, cat.nombre
ORDER BY pa.anio DESC, pa.semestre DESC, grupos_asignados DESC;
GO


-- ════════════════════════════════════════════════════════════
--  BLOQUE 5 — ANÁLISIS DE LAS MÉTRICAS DE LA FACT TABLE
--  Justifica cada columna métrica de fact_rendimiento_academico
-- ════════════════════════════════════════════════════════════

-- QA-11: Distribución de nota_final (¿qué rango tienen?)
--        → Valida tipo DECIMAL y rango; detecta notas fuera de rango
SELECT
    MIN(nota_final)                     AS nota_min,
    MAX(nota_final)                     AS nota_max,
    ROUND(AVG(CAST(nota_final AS FLOAT)),2) AS nota_promedio,
    COUNT(*)                            AS total_calificaciones,
    SUM(CASE WHEN nota_final IS NULL THEN 1 ELSE 0 END) AS notas_nulas,
    SUM(CASE WHEN aprobado   = 1    THEN 1 ELSE 0 END) AS aprobados,
    SUM(CASE WHEN aprobado   = 0    THEN 1 ELSE 0 END) AS reprobados
FROM universidad.calificacion;
GO

-- QA-12: Tasa de aprobación por materia y período
--        → Métrica principal del Dashboard ejecutivo: "% Aprobación por materia"
SELECT
    m.codigo,
    m.nombre                                AS materia,
    pa.nombre                               AS periodo,
    COUNT(cal.id_calificacion)              AS inscritos,
    SUM(CASE WHEN cal.aprobado = 1 THEN 1 ELSE 0 END) AS aprobados,
    ROUND(
        CAST(SUM(CASE WHEN cal.aprobado = 1 THEN 1 ELSE 0 END) AS FLOAT)
        / NULLIF(COUNT(cal.id_calificacion),0) * 100, 1
    )                                       AS pct_aprobacion
FROM universidad.calificacion      cal
JOIN universidad.inscripcion       i  ON i.id_inscripcion = cal.id_inscripcion
JOIN universidad.grupo             g  ON g.id_grupo       = i.id_grupo
JOIN universidad.materia           m  ON m.id_materia     = g.id_materia
JOIN universidad.periodo_academico pa ON pa.id_periodo    = g.id_periodo
WHERE i.estado != 'Retirado'
GROUP BY m.codigo, m.nombre, pa.nombre, pa.anio, pa.semestre
ORDER BY pa.anio, pa.semestre, pct_aprobacion;
GO

-- QA-13: Promedio general por período (evolución últimos 6 períodos)
--        → Soporta "Evolución del promedio — últimos 6 períodos" (Dashboard 1)
SELECT TOP 6
    pa.nombre                               AS periodo,
    pa.anio,
    pa.semestre,
    COUNT(cal.id_calificacion)              AS calificados,
    ROUND(AVG(CAST(cal.nota_final AS FLOAT)),2) AS promedio_general,
    COUNT(DISTINCT i.id_estudiante)         AS estudiantes_activos
FROM universidad.calificacion      cal
JOIN universidad.inscripcion       i  ON i.id_inscripcion = cal.id_inscripcion
JOIN universidad.grupo             g  ON g.id_grupo       = i.id_grupo
JOIN universidad.periodo_academico pa ON pa.id_periodo    = g.id_periodo
WHERE i.estado != 'Retirado'
  AND cal.nota_final IS NOT NULL
GROUP BY pa.nombre, pa.anio, pa.semestre
ORDER BY pa.anio DESC, pa.semestre DESC;
GO

-- QA-14: Créditos aprobados por estudiante
--        → Métrica "Avance de créditos por estudiante" (Dashboard operativo)
SELECT
    e.codigo_estudiante,
    per.apellido_paterno + ', ' + per.nombres AS estudiante,
    car.nombre                              AS carrera,
    SUM(CASE WHEN cal.aprobado = 1
             THEN m.creditos ELSE 0 END)    AS creditos_aprobados,
    (SELECT SUM(m2.creditos)
     FROM universidad.materia    m2
     JOIN universidad.plan_estudio pl ON pl.id_plan    = m2.id_plan
     JOIN universidad.carrera     c2  ON c2.id_carrera = pl.id_carrera
     WHERE c2.id_carrera = car.id_carrera
       AND pl.activo = 1)                   AS creditos_totales
FROM universidad.estudiante        e
JOIN universidad.persona           per ON per.id_persona   = e.id_persona
JOIN universidad.carrera           car ON car.id_carrera   = e.id_carrera
JOIN universidad.inscripcion       i   ON i.id_estudiante  = e.id_estudiante
JOIN universidad.calificacion      cal ON cal.id_inscripcion = i.id_inscripcion
JOIN universidad.grupo             g   ON g.id_grupo        = i.id_grupo
JOIN universidad.materia           m   ON m.id_materia      = g.id_materia
WHERE i.estado != 'Retirado'
GROUP BY e.codigo_estudiante, per.apellido_paterno, per.nombres,
         car.nombre, car.id_carrera
ORDER BY creditos_aprobados DESC;
GO

-- QA-15: Estudiantes en riesgo (nota < 60 en 2+ materias en el mismo período)
--        → Soporta KPI "Estudiantes en riesgo" y alerta de reprobación (Dashboards)
SELECT
    e.codigo_estudiante,
    per.apellido_paterno + ', ' + per.nombres AS estudiante,
    pa.nombre                               AS periodo,
    COUNT(*)                                AS materias_en_riesgo,
    STRING_AGG(m.nombre, ', ')              AS materias
FROM universidad.calificacion      cal
JOIN universidad.inscripcion       i  ON i.id_inscripcion = cal.id_inscripcion
JOIN universidad.estudiante        e  ON e.id_estudiante  = i.id_estudiante
JOIN universidad.persona           per ON per.id_persona  = e.id_persona
JOIN universidad.grupo             g  ON g.id_grupo       = i.id_grupo
JOIN universidad.materia           m  ON m.id_materia     = g.id_materia
JOIN universidad.periodo_academico pa ON pa.id_periodo    = g.id_periodo
WHERE cal.nota_final < 60
  AND i.estado != 'Retirado'
GROUP BY e.codigo_estudiante, per.apellido_paterno, per.nombres,
         pa.nombre, pa.anio, pa.semestre
HAVING COUNT(*) >= 2
ORDER BY pa.anio DESC, pa.semestre DESC, materias_en_riesgo DESC;
GO

-- QA-16: Evaluación docente por período y dimensión de puntaje
--        → Soporta "Evaluación docente promedio" y "Top 5 docentes" (Dashboard 1)
SELECT
    pa.nombre                               AS periodo,
    per.apellido_paterno + ', ' + per.nombres AS docente,
    cat.nombre                              AS categoria,
    ed.puntaje_metodologia,
    ed.puntaje_puntualidad,
    ed.puntaje_dominio,
    ed.puntaje_comunicacion,
    ed.puntaje_total,
    ed.cantidad_respuestas
FROM universidad.evaluacion_docente ed
JOIN universidad.docente            d   ON d.id_docente   = ed.id_docente
JOIN universidad.persona            per ON per.id_persona = d.id_persona
JOIN universidad.categoria_docente  cat ON cat.id_categoria = d.id_categoria
JOIN universidad.periodo_academico  pa  ON pa.id_periodo  = ed.id_periodo
ORDER BY pa.anio DESC, pa.semestre DESC, ed.puntaje_total DESC;
GO

-- QA-17: % Asistencia por estudiante y materia
--        → Soporta "Mapa de asistencia — últimas 6 semanas" (Dashboard operativo)
SELECT
    per.apellido_paterno + ', ' + per.nombres AS estudiante,
    m.codigo                                AS materia,
    pa.nombre                               AS periodo,
    COUNT(a.id_asistencia)                  AS clases_totales,
    SUM(CAST(a.presente AS INT))            AS clases_presentes,
    ROUND(
        CAST(SUM(CAST(a.presente AS INT)) AS FLOAT)
        / NULLIF(COUNT(a.id_asistencia),0) * 100, 1
    )                                       AS pct_asistencia
FROM universidad.asistencia        a
JOIN universidad.inscripcion       i  ON i.id_inscripcion = a.id_inscripcion
JOIN universidad.estudiante        e  ON e.id_estudiante  = i.id_estudiante
JOIN universidad.persona           per ON per.id_persona  = e.id_persona
JOIN universidad.grupo             g  ON g.id_grupo       = i.id_grupo
JOIN universidad.materia           m  ON m.id_materia     = g.id_materia
JOIN universidad.periodo_academico pa ON pa.id_periodo    = g.id_periodo
GROUP BY per.apellido_paterno, per.nombres, m.codigo, pa.nombre,
         pa.anio, pa.semestre
ORDER BY pa.anio DESC, pa.semestre DESC, pct_asistencia;
GO


-- ════════════════════════════════════════════════════════════
--  BLOQUE 6 — CALIDAD DE DATOS (obligatorio antes del ETL)
-- ════════════════════════════════════════════════════════════

-- QA-18: Inscripciones sin calificación → filas con nota NULL en la fact
SELECT
    COUNT(*) AS inscripciones_sin_calificacion
FROM universidad.inscripcion  i
LEFT JOIN universidad.calificacion cal ON cal.id_inscripcion = i.id_inscripcion
WHERE cal.id_calificacion IS NULL
  AND i.estado != 'Retirado';
GO

-- QA-19: Duplicados posibles (mismo estudiante, misma materia, mismo período)
SELECT
    e.codigo_estudiante,
    m.codigo,
    pa.nombre,
    COUNT(*) AS veces_inscrito
FROM universidad.inscripcion       i
JOIN universidad.estudiante        e  ON e.id_estudiante = i.id_estudiante
JOIN universidad.grupo             g  ON g.id_grupo      = i.id_grupo
JOIN universidad.materia           m  ON m.id_materia    = g.id_materia
JOIN universidad.periodo_academico pa ON pa.id_periodo   = g.id_periodo
GROUP BY e.codigo_estudiante, m.codigo, pa.nombre
HAVING COUNT(*) > 1;
GO

-- QA-20: Resumen de NULLs críticos para el ETL
SELECT
    'calificacion.nota_final IS NULL'   AS campo,
    COUNT(*) AS cantidad
FROM universidad.calificacion WHERE nota_final IS NULL
UNION ALL
SELECT
    'calificacion.aprobado IS NULL',
    COUNT(*) FROM universidad.calificacion WHERE aprobado IS NULL
UNION ALL
SELECT
    'estudiante.modalidad_ingreso IS NULL',
    COUNT(*) FROM universidad.estudiante WHERE modalidad_ingreso IS NULL
UNION ALL
SELECT
    'docente.titulo_maximo IS NULL',
    COUNT(*) FROM universidad.docente WHERE titulo_maximo IS NULL
UNION ALL
SELECT
    'asistencia.justificado IS NULL',
    COUNT(*) FROM universidad.asistencia WHERE justificado IS NULL;
GO
