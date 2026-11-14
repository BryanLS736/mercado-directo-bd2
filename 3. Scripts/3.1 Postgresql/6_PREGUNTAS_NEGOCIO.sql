-- =========================================================
-- PROCEDIMIENTO ALMACENADO (PREGUNTA DE NEGOCIO)
-- Pregunta: ¿Cuáles son los 5 productos más vendidos
-- (según número de pedidos) en un rango de fechas?
-- =========================================================

CREATE OR REPLACE PROCEDURE mercado.sp_top_productos( 
    p_fecha_ini DATE, 
    p_fecha_fin DATE 

) 
LANGUAGE plpgsql 
AS $$ 
DECLARE 
    r RECORD; 
BEGIN 
    -- Validar fechas 
    IF p_fecha_ini IS NULL OR p_fecha_fin IS NULL THEN 

        RAISE EXCEPTION 'Las fechas no pueden ser nulas'; 
    END IF; 

    IF p_fecha_ini > p_fecha_fin THEN 

        RAISE EXCEPTION 'La fecha inicial no puede ser mayor que la fecha final'; 
    END IF; 

    RAISE NOTICE 'TOP 5 PRODUCTOS MAS VENDIDOS'; 
    RAISE NOTICE '--------------------------------'; 
    FOR r IN 
        SELECT 
            pr.producto_id, 
            pr.nombre AS producto, 
            COUNT(DISTINCT dp.pedido_id) AS total_pedidos 
        FROM mercado.detalle_pedido dp 

        INNER JOIN mercado.oferta_cosecha oc 
            ON dp.oferta_id = oc.oferta_id 

        INNER JOIN mercado.producto pr 
            ON oc.producto_id = pr.producto_id 

        INNER JOIN mercado.pedido pe 
            ON dp.pedido_id = pe.pedido_id 

        WHERE pe.fecha_pedido >= p_fecha_ini::timestamp 
          AND pe.fecha_pedido < (p_fecha_fin + 1)::timestamp 
        GROUP BY pr.producto_id, pr.nombre 

        ORDER BY total_pedidos DESC, pr.nombre ASC 
        LIMIT 5 
    LOOP 
        RAISE NOTICE '% -> % pedidos', 
            r.producto, 
            r.total_pedidos; 
    END LOOP; 
END; 

$$; 

-- Uso:
CALL mercado.sp_top_productos('2026-01-01', '2026-6-30');


-- =========================================================
-- FUNCIÓN ALMACENADA (PREGUNTA DE NEGOCIO)
-- Pregunta: ¿Cuál es el ingreso total generado por un
-- producto específico?
-- =========================================================

CREATE OR REPLACE FUNCTION mercado.fn_ingreso_por_producto( 
    p_producto_id IN INT 
) 
RETURNS NUMERIC 
LANGUAGE plpgsql 
AS $$ 
DECLARE 
    v_total NUMERIC; 
BEGIN 
    -- Validar que el producto exista (si no, devolvería 0 sin avisar) 
    IF NOT EXISTS (SELECT 1 FROM mercado.producto 
                   WHERE producto_id = p_producto_id) THEN 
        RAISE EXCEPTION 'El producto con ID % no existe', p_producto_id; 
    END IF;
    
    SELECT 
        COALESCE( 
            SUM(dp.cantidad_kg * dp.precio_acordado), 
            0 
        ) 
    INTO v_total 
    FROM mercado.detalle_pedido dp 
    INNER JOIN mercado.oferta_cosecha oc 
        ON dp.oferta_id = oc.oferta_id 
    WHERE oc.producto_id = p_producto_id; 
    RETURN v_total; 
END; 
$$; 

-- Uso:
SELECT mercado.fn_ingreso_por_producto(11) AS ingreso_papa_blanca;