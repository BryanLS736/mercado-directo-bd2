-- =====================================================
-- FUNCIÓN BÁSICA: fn_contar_agricultores
-- Propósito: Retorna el número total de agricultores
-- registrados en el sistema.
-- Retorna: INTEGER - Cantidad de agricultores
-- =====================================================

CREATE OR REPLACE FUNCTION mercado.fn_contar_agricultores()
RETURNS INTEGER AS
$$
DECLARE
    v_count INTEGER; -- Variable local para almacenar el conteo
BEGIN

    -- Contar los agricultores registrados
    SELECT COUNT(*)
    INTO v_count
    FROM mercado.agricultor;

    -- Retornar el resultado
    RETURN v_count;

END;
$$
LANGUAGE plpgsql; -- plpgsql es el lenguaje procedural de PostgreSQL


-- ========== EJEMPLO DE USO ==========

-- ¿Cuántos agricultores están registrados?
SELECT mercado.fn_contar_agricultores() AS total_agricultores;


-- =====================================================
-- FUNCIÓN AVANZADA: fn_reporte_clientes_compras
-- Propósito: Retorna un reporte de los clientes que
-- han realizado pedidos, mostrando la cantidad de
-- pedidos, kilogramos comprados y monto total.
--
-- Retorna:
-- cliente_id
-- nombre_razon_social
-- tipo_cliente
-- total_pedidos
-- total_kg_comprados
-- monto_total
-- =====================================================

CREATE OR REPLACE FUNCTION mercado.fn_reporte_clientes_compras()
RETURNS TABLE(
    cliente_id INTEGER,
    nombre_razon_social VARCHAR(150),
    tipo_cliente VARCHAR(30),
    total_pedidos BIGINT,
    total_kg_comprados NUMERIC,
    monto_total NUMERIC
) AS
$$
BEGIN

    RETURN QUERY

    SELECT
        c.cliente_id,
        c.nombre_razon_social,
        c.tipo_cliente,
        COUNT(DISTINCT p.pedido_id) AS total_pedidos,
        COALESCE(SUM(dp.cantidad_kg), 0) AS total_kg_comprados,
        COALESCE(
            SUM(dp.cantidad_kg * dp.precio_acordado),
            0
        ) AS monto_total

    FROM mercado.cliente_consumidor c

    JOIN mercado.pedido p
        ON c.cliente_id = p.cliente_id

    JOIN mercado.detalle_pedido dp
        ON p.pedido_id = dp.pedido_id

    GROUP BY
        c.cliente_id,
        c.nombre_razon_social,
        c.tipo_cliente

    ORDER BY
        total_pedidos DESC,
        monto_total DESC;

END;
$$
LANGUAGE plpgsql;


-- ========== EJEMPLO DE USO ==========

-- Obtener el reporte de clientes con mayor cantidad de pedidos
SELECT *
FROM mercado.fn_reporte_clientes_compras();

-- Mostrar solamente los 5 clientes con mayor cantidad de pedidos
SELECT *
FROM mercado.fn_reporte_clientes_compras()
LIMIT 5;

-- =====================================================
-- PROCEDIMIENTO BÁSICO: sp_nuevo_pedido
-- Propósito: Registra un nuevo pedido en la tabla pedido.
-- Parámetros:
-- p_cliente_id    - ID del cliente consumidor
-- p_direccion_id  - ID de la dirección de entrega
-- p_fecha_entrega - Fecha solicitada para la entrega
-- p_costo_envio   - Costo del envío
-- p_observaciones - Observaciones del pedido
--
-- Validaciones agregadas:
--   * el cliente debe existir
--   * la dirección debe existir y pertenecer a ese cliente
--   * la fecha de entrega no puede ser anterior a hoy
--   * el costo de envío no puede ser nulo ni negativo
-- =====================================================

CREATE OR REPLACE PROCEDURE mercado.sp_nuevo_pedido(
    p_cliente_id INTEGER,
    p_direccion_id INTEGER,
    p_fecha_entrega DATE,
    p_costo_envio NUMERIC(12,2),
    p_observaciones VARCHAR(300)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_pedido_id INTEGER;
BEGIN

    -- Validar que el cliente exista
    IF NOT EXISTS (SELECT 1 FROM mercado.cliente_consumidor
                   WHERE cliente_id = p_cliente_id) THEN
        RAISE EXCEPTION 'El cliente con ID % no existe', p_cliente_id;
    END IF;
 
    -- Validar que la dirección exista y sea de ese cliente
    IF NOT EXISTS (SELECT 1 FROM mercado.direccion_cliente
                   WHERE direccion_id = p_direccion_id
                     AND cliente_id = p_cliente_id) THEN
        RAISE EXCEPTION 'La dirección % no existe o no pertenece al cliente %',
            p_direccion_id, p_cliente_id;
    END IF;
 
    -- Validar la fecha de entrega
    IF p_fecha_entrega IS NULL OR p_fecha_entrega < CURRENT_DATE THEN
        RAISE EXCEPTION 'La fecha de entrega no puede ser nula ni anterior a hoy';
    END IF;
 
    -- Validar el costo de envío
    IF p_costo_envio IS NULL OR p_costo_envio < 0 THEN
        RAISE EXCEPTION 'El costo de envío no puede ser nulo ni negativo';
    END IF;

    -- Insertar el nuevo pedido
    INSERT INTO mercado.pedido (
        cliente_id,
        direccion_id,
        fecha_pedido,
        fecha_entrega_solicitada,
        costo_envio,
        observaciones
    )
    VALUES (
        p_cliente_id,
        p_direccion_id,
        CURRENT_TIMESTAMP,
        p_fecha_entrega,
        p_costo_envio,
        p_observaciones
    )
    RETURNING pedido_id INTO v_pedido_id;

    -- Mensaje de confirmación
    RAISE NOTICE 'Pedido registrado con ID: %', v_pedido_id;

END;
$$;


-- =====================================================
-- EJEMPLO DE USO
-- Se ejecuta dentro de una transacción con ROLLBACK para
-- NO dejar un pedido de prueba guardado en la base.
-- (Para guardarlo de verdad, cambien ROLLBACK por COMMIT.)
-- =====================================================

BEGIN;
CALL mercado.sp_nuevo_pedido(
    1,              -- Cliente
    1,              -- Dirección (debe ser del cliente 1)
    CURRENT_DATE + 5,   -- Fecha de entrega (5 días después de hoy)
    15.00,          -- Costo de envío
    'Entregar por la mañana'
);
 
-- Verificar que se creó el pedido (aún dentro de la transacción)
SELECT *
FROM mercado.pedido
ORDER BY pedido_id DESC
LIMIT 1;
 
ROLLBACK;


-- =====================================================
-- PROCEDIMIENTO BÁSICO: sp_nueva_oferta_cosecha
-- Propósito: Registra una nueva oferta de cosecha
-- en la tabla oferta_cosecha.
-- Parámetros:
-- p_ubicacion_agricultor_id - ID de la ubicación del agricultor
-- p_producto_id             - ID del producto ofrecido
-- p_fecha_cosecha           - Fecha estimada de cosecha
-- p_fecha_disponibilidad    - Fecha en que estará disponible
-- p_precio_kg               - Precio por kilogramo
-- p_observaciones           - Observaciones de la oferta
--
-- Validaciones agregadas:
--   * la ubicación del agricultor y el producto deben existir
--   * la cosecha no puede ser anterior a hoy
--   * la disponibilidad no puede ser anterior a la cosecha
--   * el precio debe ser mayor que 0
-- =====================================================

CREATE OR REPLACE PROCEDURE mercado.sp_nueva_oferta_cosecha(
    p_ubicacion_agricultor_id INTEGER,
    p_producto_id INTEGER,
    p_fecha_cosecha DATE,
    p_fecha_disponibilidad DATE,
    p_precio_kg NUMERIC(12,2),
    p_observaciones VARCHAR(300)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_oferta_id INTEGER;
BEGIN

     -- Validar que la ubicación del agricultor exista
    IF NOT EXISTS (SELECT 1 FROM mercado.ubicacion_agricultor
                   WHERE ubicacion_agricultor_id = p_ubicacion_agricultor_id) THEN
        RAISE EXCEPTION 'La ubicación de agricultor % no existe',
            p_ubicacion_agricultor_id;
    END IF;
 
    -- Validar que el producto exista
    IF NOT EXISTS (SELECT 1 FROM mercado.producto
                   WHERE producto_id = p_producto_id) THEN
        RAISE EXCEPTION 'El producto con ID % no existe', p_producto_id;
    END IF;
 
    -- Validar las fechas
    IF p_fecha_cosecha IS NULL OR p_fecha_disponibilidad IS NULL THEN
        RAISE EXCEPTION 'Las fechas de cosecha y disponibilidad son obligatorias';
    END IF;
 
    IF p_fecha_cosecha < CURRENT_DATE THEN
        RAISE EXCEPTION 'La fecha de cosecha no puede ser anterior a hoy';
    END IF;
 
    IF p_fecha_disponibilidad < p_fecha_cosecha THEN
        RAISE EXCEPTION 'La disponibilidad no puede ser anterior a la cosecha';
    END IF;
 
    -- Validar el precio
    IF p_precio_kg IS NULL OR p_precio_kg <= 0 THEN
        RAISE EXCEPTION 'El precio por kg debe ser mayor que 0';
    END IF;

    -- Insertar la nueva oferta de cosecha
    INSERT INTO mercado.oferta_cosecha (
        ubicacion_agricultor_id,
        producto_id,
        fecha_publicacion,
        fecha_cosecha_estimada,
        fecha_disponibilidad,
        precio_kg,
        observaciones
    )
    VALUES (
        p_ubicacion_agricultor_id,
        p_producto_id,
        CURRENT_TIMESTAMP,
        p_fecha_cosecha,
        p_fecha_disponibilidad,
        p_precio_kg,
        p_observaciones
    )
    RETURNING oferta_id INTO v_oferta_id;

    -- Mensaje de confirmación
    RAISE NOTICE 'Oferta de cosecha registrada con ID: %', v_oferta_id;

END;
$$;

-- =====================================================
-- EJEMPLO DE USO (con ROLLBACK: no deja datos de prueba)
-- =====================================================

BEGIN;
 
CALL mercado.sp_nueva_oferta_cosecha(
    1,                      -- Ubicación del agricultor
    1,                      -- Producto
    CURRENT_DATE + 5,       -- Fecha estimada de cosecha
    CURRENT_DATE + 8,       -- Fecha de disponibilidad
    4.50,                   -- Precio por KG
    'Producto fresco de cosecha reciente'
);
 
-- Verificar que se creó la oferta (aún dentro de la transacción)
SELECT *
FROM mercado.oferta_cosecha
ORDER BY oferta_id DESC
LIMIT 1;
 
ROLLBACK;


-- =====================================================
-- PROCEDIMIENTO: sp_procesar_entrega
-- Propósito: Registra la entrega de un pedido, calcula
-- el retraso y el recargo (S/ 5.00 por día) y lo agrega
-- al final de observaciones (sin borrar lo que ya había).
--
-- Parámetros:
-- p_pedido_id          - ID del pedido
-- p_fecha_entrega_real - Fecha en que se entregó el pedido
--
-- Validaciones agregadas:
--   * el pedido debe existir
--   * la fecha de entrega real es obligatoria y no puede
--     ser anterior a la fecha en que se hizo el pedido
--   * el pedido no puede procesarse dos veces
-- =====================================================

CREATE OR REPLACE PROCEDURE mercado.sp_procesar_entrega(
    p_pedido_id INTEGER,
    p_fecha_entrega_real DATE
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_fecha_solicitada DATE;
    v_fecha_pedido DATE;
    v_observaciones VARCHAR(300);
    v_dias_retraso INTEGER;
    v_recargo NUMERIC(12,2);
BEGIN
    -- Buscar los datos del pedido
    SELECT fecha_entrega_solicitada, fecha_pedido::date, observaciones
    INTO v_fecha_solicitada, v_fecha_pedido, v_observaciones
    FROM mercado.pedido
    WHERE pedido_id = p_pedido_id;

    -- Verificar que el pedido exista
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El pedido con ID % no existe', p_pedido_id;
    END IF;

    -- Validar la fecha de entrega real
    IF p_fecha_entrega_real IS NULL THEN
        RAISE EXCEPTION 'La fecha de entrega real es obligatoria';
    END IF;
 
    IF p_fecha_entrega_real < v_fecha_pedido THEN
        RAISE EXCEPTION 'La entrega (%) no puede ser anterior al pedido (%)',
            p_fecha_entrega_real, v_fecha_pedido;
    END IF;
 
    -- Evitar procesar dos veces el mismo pedido
    IF COALESCE(v_observaciones, '') LIKE '%Entregado el %' THEN
        RAISE EXCEPTION 'El pedido % ya fue procesado como entregado', p_pedido_id;
    END IF;

    -- Calcular días de retraso y recargo
    v_dias_retraso := GREATEST(0, p_fecha_entrega_real - v_fecha_solicitada);
    v_recargo := v_dias_retraso * 5;

    -- Agregar el resultado a observaciones (sin borrar el texto anterior)
    UPDATE mercado.pedido
    SET observaciones = LEFT(
            COALESCE(observaciones || ' | ', '')
            || 'Entregado el ' || p_fecha_entrega_real
            || '. Días de retraso: ' || v_dias_retraso
            || '. Recargo: S/ ' || v_recargo,
            300)
    WHERE pedido_id = p_pedido_id;

    -- Mostrar mensaje
    IF v_dias_retraso > 0 THEN
        RAISE NOTICE 'Pedido % con % días de retraso. Recargo: S/ %',
            p_pedido_id, v_dias_retraso, v_recargo;
    ELSE
        RAISE NOTICE 'Pedido % entregado a tiempo.', p_pedido_id;
    END IF;
END;
$$;

-- =====================================================
-- EJEMPLO DE USO (con ROLLBACK: no modifica el pedido real)
-- =====================================================
 
BEGIN;
 
-- Procesar la entrega del pedido ID 1 (solicitado para el 29/01/2026):
-- se entrega el 31/01/2026, o sea 2 días tarde -> recargo S/ 10.00
CALL mercado.sp_procesar_entrega(1, '2026-01-31');
 
-- Ver el resultado (aún dentro de la transacción)
SELECT pedido_id, observaciones
FROM mercado.pedido
WHERE pedido_id = 1;
 
ROLLBACK;
