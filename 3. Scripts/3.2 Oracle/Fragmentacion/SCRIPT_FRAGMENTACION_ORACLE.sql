/* ============================================================
   FRAGMENTACION HORIZONTAL POR RANGO - MOVIMIENTO_INVENTARIO
   Criterio: fecha_movimiento, trimestral
   Gestor: Oracle 21c  |  Usuario: MD_OWNER
   ============================================================ */
SET SERVEROUTPUT ON;

/* ------------------------------------------------------------
   PASO 0. VERIFICACIONES PREVIAS
   ------------------------------------------------------------ */

-- 0.1 Confirmar que la opcion Partitioning esta habilitada (debe dar TRUE)
SELECT parameter, value
  FROM v$option
 WHERE parameter = 'Partitioning';

-- 0.2 Estado actual: la tabla NO debe estar particionada (debe dar 'NO')
SELECT table_name, partitioned
  FROM user_tables
 WHERE table_name = 'MOVIMIENTO_INVENTARIO';

-- 0.3 Rango de fechas y volumen actual (referencia ANTES)
SELECT COUNT(*)                AS total_filas,
       MIN(fecha_movimiento)   AS fecha_minima,
       MAX(fecha_movimiento)   AS fecha_maxima,
       SUM(cantidad_kg)        AS suma_kg
  FROM movimiento_inventario;


/* ------------------------------------------------------------
   PASO 1. CONVERSION A TABLA PARTICIONADA (EN LINEA)
   - 4 particiones de rango (F1..F4) para 2026
   - INTERVAL: los trimestres desde 2027-01-01 se crean solos
   - ONLINE: la tabla sigue disponible durante la conversion
   - UPDATE INDEXES: la PK se mantiene valida (indice global)
   ------------------------------------------------------------ */
ALTER TABLE movimiento_inventario
  MODIFY PARTITION BY RANGE (fecha_movimiento)
  INTERVAL (NUMTOYMINTERVAL(3, 'MONTH'))
  (
    PARTITION p_mov_2026_q1 VALUES LESS THAN (TIMESTAMP '2026-04-01 00:00:00') TABLESPACE TS_MD_DATOS,
    PARTITION p_mov_2026_q2 VALUES LESS THAN (TIMESTAMP '2026-07-01 00:00:00') TABLESPACE TS_MD_DATOS,
    PARTITION p_mov_2026_q3 VALUES LESS THAN (TIMESTAMP '2026-10-01 00:00:00') TABLESPACE TS_MD_DATOS,
    PARTITION p_mov_2026_q4 VALUES LESS THAN (TIMESTAMP '2027-01-01 00:00:00') TABLESPACE TS_MD_DATOS
  )
  ONLINE
  UPDATE INDEXES;


/* ------------------------------------------------------------
   PASO 2. INDICES LOCALES (uno por particion, se mantienen solos)
   - lote_id: lo usan fn_stock_actual_lote y el procedimiento
   - tipo_movimiento_id: columna FK sin indice
   ------------------------------------------------------------ */
DROP INDEX idx_movimiento_lote_fecha;

CREATE INDEX idx_movimiento_lote_fecha
    ON movimiento_inventario (lote_id, fecha_movimiento)
    LOCAL
    TABLESPACE TS_MD_INDICES;

CREATE INDEX idx_mov_tipo
    ON movimiento_inventario (tipo_movimiento_id)
    LOCAL
    TABLESPACE TS_MD_INDICES;

/* ------------------------------------------------------------
   PASO 3. RECOMPILAR OBJETOS DEPENDIENTES Y ESTADISTICAS
   ------------------------------------------------------------ */
ALTER PROCEDURE sp_registrar_movimiento_inventario COMPILE;
ALTER FUNCTION  fn_stock_actual_lote COMPILE;
ALTER FUNCTION  fn_capacidad_disponible_centro COMPILE;

BEGIN
    DBMS_STATS.GATHER_TABLE_STATS(
        ownname     => USER,
        tabname     => 'MOVIMIENTO_INVENTARIO',
        granularity => 'AUTO',
        cascade     => TRUE
    );
END;
/


/* ------------------------------------------------------------
   PASO 4. VERIFICACION
   ------------------------------------------------------------ */

-- 4.1 Tipo de particionamiento
SELECT table_name, partitioning_type, interval, partition_count
  FROM user_part_tables
 WHERE table_name = 'MOVIMIENTO_INVENTARIO';

-- 4.2 Particiones (fragmentos) con su limite superior y filas
SELECT partition_position AS posicion,
       partition_name     AS fragmento,
       high_value         AS limite_superior,
       num_rows           AS filas,
       interval           AS es_automatica
  FROM user_tab_partitions
 WHERE table_name = 'MOVIMIENTO_INVENTARIO'
 ORDER BY partition_position;

-- 4.3 Distribucion de filas por fragmento (conteo directo)
SELECT 'F1 - P_MOV_2026_Q1' AS fragmento, COUNT(*) AS filas
  FROM movimiento_inventario PARTITION (p_mov_2026_q1)
UNION ALL
SELECT 'F2 - P_MOV_2026_Q2', COUNT(*)
  FROM movimiento_inventario PARTITION (p_mov_2026_q2)
UNION ALL
SELECT 'F3 - P_MOV_2026_Q3', COUNT(*)
  FROM movimiento_inventario PARTITION (p_mov_2026_q3)
UNION ALL
SELECT 'F4 - P_MOV_2026_Q4', COUNT(*)
  FROM movimiento_inventario PARTITION (p_mov_2026_q4);

-- 4.4 Los datos no se perdieron (comparar con el Paso 0.3)
SELECT COUNT(*) AS total_filas, SUM(cantidad_kg) AS suma_kg
  FROM movimiento_inventario;

-- 4.5 Indices: PK global y los dos locales
SELECT index_name, partitioned, status
  FROM user_indexes
 WHERE table_name = 'MOVIMIENTO_INVENTARIO'
 ORDER BY index_name;

-- 4.6 Objetos PL/SQL en estado VALID
SELECT object_name, object_type, status
  FROM user_objects
 WHERE object_name IN ('SP_REGISTRAR_MOVIMIENTO_INVENTARIO',
                       'FN_STOCK_ACTUAL_LOTE',
                       'FN_CAPACIDAD_DISPONIBLE_CENTRO');


/* ------------------------------------------------------------
   PASO 5. PRUEBA DE PARTITION PRUNING
   Una consulta del trimestre en curso solo debe leer F4
   ------------------------------------------------------------ */
EXPLAIN PLAN FOR
SELECT *
  FROM movimiento_inventario
 WHERE fecha_movimiento >= TIMESTAMP '2026-10-01 00:00:00'
   AND fecha_movimiento <  TIMESTAMP '2027-01-01 00:00:00';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, NULL, 'BASIC +PARTITION'));
-- En el plan, Pstart y Pstop deben mostrar el mismo numero (4):
-- "PARTITION RANGE SINGLE", es decir, lee 1 fragmento y no los demas.


/* ------------------------------------------------------------
   PASO 6. PRUEBA DE CREACION AUTOMATICA DE FRAGMENTOS (2027)
   Se inserta una fila de prueba en un trimestre que no existe
   ------------------------------------------------------------ */
INSERT INTO movimiento_inventario
       (lote_id, tipo_movimiento_id, fecha_movimiento, cantidad_kg, observaciones)
SELECT l.lote_id,
       (SELECT cd.id
          FROM cat_detalle cd
          JOIN cat_maestro cm ON cm.id_mae = cd.id_mae
         WHERE cm.sigla_tabla = 'TMV'
           AND cd.nombre = 'INGRESO POR RECEPCION'),
       TIMESTAMP '2027-02-15 10:00:00',
       1,
       'PRUEBA: creacion automatica de particion'
  FROM lote l
 FETCH FIRST 1 ROW ONLY;

-- Debe aparecer una particion nueva con nombre SYS_Pxxx e INTERVAL = YES
SELECT partition_name, high_value, interval
  FROM user_tab_partitions
 WHERE table_name = 'MOVIMIENTO_INVENTARIO'
 ORDER BY partition_position;

-- Limpieza de la prueba: deshacer la fila y eliminar el fragmento de prueba
ROLLBACK;

ALTER TABLE movimiento_inventario
  DROP PARTITION FOR (TIMESTAMP '2027-02-15 10:00:00');