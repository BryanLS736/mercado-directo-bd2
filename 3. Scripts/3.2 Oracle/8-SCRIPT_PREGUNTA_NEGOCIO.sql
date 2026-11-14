-- =========================================================
-- FUNCIÓN ALMACENADA (PREGUNTA DE NEGOCIO)
-- Pregunta: ¿Cuál es el volumen total de inventario
-- (en kg) recibido en un centro de acopio?
-- =========================================================

CREATE OR REPLACE FUNCTION fn_volumen_por_centro( 
    p_centro_id NUMBER, 
    p_fecha_inicio DATE DEFAULT TRUNC(SYSDATE) - 30, 
    p_fecha_fin DATE DEFAULT TRUNC(SYSDATE) 
) 

RETURN NUMBER 
IS 
    v_total_kg NUMBER := 0; 
BEGIN 

    -- Validar parámetros 
    IF p_centro_id IS NULL THEN 
        RAISE_APPLICATION_ERROR( 
            -20001, 
            'El centro de acopio es obligatorio' 
        ); 
    END IF; 

    IF p_fecha_inicio IS NULL OR p_fecha_fin IS NULL THEN 
        RAISE_APPLICATION_ERROR( 
            -20002, 
            'Las fechas no pueden ser nulas' 
        ); 
    END IF; 


    IF TRUNC(p_fecha_inicio) > TRUNC(p_fecha_fin) THEN 
        RAISE_APPLICATION_ERROR( 
            -20003, 
            'La fecha inicial no puede ser mayor que la fecha final' 
        ); 

    END IF; 

    SELECT 
        NVL(SUM(l.cantidad_inicial_kg), 0) 
    INTO v_total_kg 
    FROM lote l 
    INNER JOIN recepcion_acopio ra 
        ON l.recepcion_id = ra.recepcion_id 
    WHERE ra.centro_acopio_id = p_centro_id 
      AND ra.fecha_recepcion >= TRUNC(p_fecha_inicio) 
      AND ra.fecha_recepcion < TRUNC(p_fecha_fin) + 1; 
    RETURN v_total_kg; 
EXCEPTION 

    WHEN OTHERS THEN
        IF SQLCODE BETWEEN -20099 AND -20000 THEN
            RAISE;
        ELSE
            RAISE_APPLICATION_ERROR(
                -20004,
                'Error al calcular el volumen: ' || SQLERRM
            );
        END IF; 
END fn_volumen_por_centro; 
/ 

-- Ejecución 
-- Uso: últimos 30 días 
SELECT fn_volumen_por_centro(3) AS volumen_total FROM DUAL; 

-- Uso: periodo específico 
SELECT fn_volumen_por_centro( 
    3, 
    TO_DATE('2026-01-01', 'YYYY-MM-DD'), 
    TO_DATE('2026-01-31', 'YYYY-MM-DD') 
) AS volumen_total FROM DUAL;



-- =========================================================
-- PROCEDIMIENTO ALMACENADO (PREGUNTA DE NEGOCIO)
-- Pregunta: ¿Cuál es el estado actual del inventario
-- por lote (cantidad inicial, salida y disponible)?
-- =========================================================

CREATE OR REPLACE PROCEDURE sp_inventario_por_lote 
IS 
BEGIN 
    DBMS_OUTPUT.PUT_LINE( 
        'ESTADO ACTUAL DEL INVENTARIO POR LOTE' 
    ); 

    DBMS_OUTPUT.PUT_LINE( 
        '-------------------------------------------------------------' 
    ); 


    DBMS_OUTPUT.PUT_LINE( 
        'LOTE | CENTRO | INICIAL | ENTRADAS | SALIDAS | AJUSTES | ACTUAL' 
    ); 

    FOR v_inv IN ( 
        SELECT 
            l.codigo_lote, 
            ca.nombre AS centro, 


            l.cantidad_inicial_kg AS inicial, 
            -- Cantidad de entradas 
            NVL(SUM( 
                CASE 
                    WHEN UPPER(cd.valor) = 'ENT' 
                    THEN mi.cantidad_kg 
                    ELSE 0 
                END 
            ), 0) AS entradas, 


            -- Cantidad de salidas 
            NVL(SUM( 
                CASE 
                    WHEN UPPER(cd.valor) = 'SAL' 
                    THEN mi.cantidad_kg 
                    ELSE 0 
                END 

            ), 0) AS salidas, 
  
            -- Ajustes positivos 

            NVL(SUM( 
                CASE 
                    WHEN UPPER(cd.valor) = 'AJU_POS' 
                    THEN mi.cantidad_kg 
                    ELSE 0 
                END 

            ), 0) AS ajuste_positivo, 
  
            -- Ajustes negativos 
            NVL(SUM( 
                CASE 
                    WHEN UPPER(cd.valor) = 'AJU_NEG' 
                    THEN mi.cantidad_kg 
                    ELSE 0 
                END 
            ), 0) AS ajuste_negativo, 

            -- Inventario disponible 
            ROUND( 
                l.cantidad_inicial_kg 
                + NVL(SUM( 
                    CASE 
                        WHEN UPPER(cd.valor) = 'ENT' 
                        THEN mi.cantidad_kg 

                        WHEN UPPER(cd.valor) = 'SAL' 
                        THEN -mi.cantidad_kg 

                        WHEN UPPER(cd.valor) = 'AJU_POS' 
                        THEN mi.cantidad_kg 


                        WHEN UPPER(cd.valor) = 'AJU_NEG' 
                        THEN -mi.cantidad_kg 
                        ELSE 0 
                    END 
                ), 0), 
                2 
            ) AS actual 
        FROM lote l 

        INNER JOIN recepcion_acopio ra 
            ON l.recepcion_id = ra.recepcion_id 
        INNER JOIN centro_acopio ca 
            ON ra.centro_acopio_id = ca.centro_acopio_id 
        LEFT JOIN movimiento_inventario mi 
            ON l.lote_id = mi.lote_id 
        LEFT JOIN cat_detalle cd 
            ON mi.tipo_movimiento_id = cd.id 
           AND cd.id_mae = 4 
        GROUP BY 
            l.lote_id, 
            l.codigo_lote, 
            ca.nombre, 
            l.cantidad_inicial_kg 
        ORDER BY ca.nombre, l.codigo_lote 
    ) 
    LOOP 
        DBMS_OUTPUT.PUT_LINE( 
            v_inv.codigo_lote || ' | ' || 

            v_inv.centro || ' | ' || 

            v_inv.inicial || ' kg | ' || 

            v_inv.entradas || ' kg | ' || 

            v_inv.salidas || ' kg | ' || 

            (v_inv.ajuste_positivo - v_inv.ajuste_negativo) || 

            ' kg | ' || 
            v_inv.actual || ' kg' 
        ); 
    END LOOP; 
END sp_inventario_por_lote; 
/ 

-- Ejecución: 
SET SERVEROUTPUT ON; 
BEGIN 
    sp_inventario_por_lote; 
END; 

/