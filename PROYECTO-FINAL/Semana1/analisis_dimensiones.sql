USE OLTP_Universidad_Transact;
GO

SELECT
    TABLE_NAME          AS Tabla,
    COLUMN_NAME         AS Columna,
    DATA_TYPE           AS Tipo_Dato,
    CHARACTER_MAXIMUM_LENGTH AS Longitud,
    IS_NULLABLE         AS Permite_Nulo,
    ORDINAL_POSITION    AS Orden
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'universidad'
  AND TABLE_NAME IN (
      'estudiante',
      'persona',
      'carrera',
      'facultad',
      'materia',
      'plan_estudio',
      'docente',
      'categoria_docente',
      'periodo_academico',
      'genero',
      'estado_civil',
      'tipo_documento',
      'municipio',
      'departamento'
  )
ORDER BY TABLE_NAME, ORDINAL_POSITION;
GO
