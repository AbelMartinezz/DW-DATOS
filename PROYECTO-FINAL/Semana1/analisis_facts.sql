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
      'calificacion', 
      'inscripcion',   
      'asistencia', 
      'evaluacion_docente',
      'grupo', 
      'asignacion_docente'  
  )
ORDER BY TABLE_NAME, ORDINAL_POSITION;
GO
