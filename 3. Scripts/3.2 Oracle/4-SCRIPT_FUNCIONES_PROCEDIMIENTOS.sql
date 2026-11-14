/* ============================================================
   PROYECTO: MERCADO DIRECTO - ORACLE
   FUNCIONES Y PROCEDIMIENTOS ALMACENADOS
   ============================================================ */

SET SERVEROUTPUT ON;


/* ------------------------------------------------------------
   1. FN_STOCK_ACTUAL_LOTE
   Para que: calcular el stock real de un lote (cantidad inicial
   +/- todos sus movimientos), sin repetir esa suma en cada
   consulta o reporte.
   Donde se usaria: antes de autorizar una SALIDA de inventario
   y en SP_REGISTRAR_MOVIMIENTO_INVENTARIO.
   ------------------------------------------------------------ */
CREATE OR REPLACE FUNCTION fn_stock_actual_lote (
    p_lote_id IN lote.lote_id%TYPE
) RETURN NUMBER
IS
    v_cantidad_inicial lote.cantidad_inicial_kg%TYPE;
    v_movimientos      NUMBER := 0;
BEGIN
    SELECT cantidad_inicial_kg
      INTO v_cantidad_inicial
      FROM lote
     WHERE lote_id = p_lote_id;

    -- E (ingreso, devolucion) suma; S (despacho, merma) resta
    SELECT NVL(SUM(
             CASE cd.valor
                WHEN 'E' THEN  mi.cantidad_kg
                WHEN 'S' THEN -mi.cantidad_kg
                ELSE           0
             END
           ), 0)
      INTO v_movimientos
      FROM movimiento_inventario mi
      JOIN cat_detalle cd ON cd.id = mi.tipo_movimiento_id
      JOIN cat_maestro cm ON cm.id_mae = cd.id_mae
     WHERE mi.lote_id = p_lote_id
       AND cm.sigla_tabla = 'TMV';

    RETURN v_cantidad_inicial + v_movimientos;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN NULL;
END fn_stock_actual_lote;
/


/* ------------------------------------------------------------
   2. SP_REGISTRAR_MOVIMIENTO_INVENTARIO
   Para que: centralizar la regla "todo movimiento valida el
   tipo, se inserta, y si el lote se queda sin stock pasa a
   AGOTADO (o vuelve a DISPONIBLE si recupera stock)".
   Donde se usaria: cuando el centro de acopio despacha un lote
   hacia una ruta, o en un ajuste manual de inventario.

   IMPORTANTE: p_tipo_movimiento recibe el NOMBRE del catalogo
   TMV: INGRESO POR RECEPCION, SALIDA POR DESPACHO, MERMA o
   DEVOLUCION (no 'ENTRADA').
   ------------------------------------------------------------ */
CREATE OR REPLACE PROCEDURE sp_registrar_movimiento_inventario (
    p_lote_id         IN lote.lote_id%TYPE,
    p_tipo_movimiento IN VARCHAR2,
    p_cantidad_kg     IN NUMBER,
    p_observaciones   IN VARCHAR2 DEFAULT NULL
)
IS
    v_tipo_movimiento_id   cat_detalle.id%TYPE;
    v_signo                cat_detalle.valor%TYPE;   -- 'E' o 'S'
    v_id_estado_agotado    cat_detalle.id%TYPE;
    v_id_estado_disponible cat_detalle.id%TYPE;
    v_lote_bloqueado       lote.lote_id%TYPE;
    v_stock_actual         NUMBER;
    v_stock_resultante     NUMBER;
BEGIN
    -- 1. Cantidad positiva
    IF p_cantidad_kg IS NULL OR p_cantidad_kg <= 0 THEN
        RAISE_APPLICATION_ERROR(-20002,
            'La cantidad debe ser un numero mayor a cero');
    END IF;

    -- 2. Tipo de movimiento valido (catalogo TMV)
    BEGIN
        SELECT cd.id, cd.valor
          INTO v_tipo_movimiento_id, v_signo
          FROM cat_detalle cd
          JOIN cat_maestro cm ON cm.id_mae = cd.id_mae
         WHERE cm.sigla_tabla = 'TMV'
           AND UPPER(cd.nombre) = UPPER(TRIM(p_tipo_movimiento))
           AND cd.estado = 'S';
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20001,
                'Tipo de movimiento no valido: ' || p_tipo_movimiento);
    END;

    -- 3. Bloquear el lote (concurrencia)
    BEGIN
        SELECT lote_id
          INTO v_lote_bloqueado
          FROM lote
         WHERE lote_id = p_lote_id
           FOR UPDATE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20006,
                'El lote ' || p_lote_id || ' no existe');
    END;

    -- 4. Si el movimiento resta (valor 'S'), exigir stock suficiente
    IF v_signo = 'S' THEN
        v_stock_actual := NVL(fn_stock_actual_lote(p_lote_id), 0);

        IF v_stock_actual < p_cantidad_kg THEN
            RAISE_APPLICATION_ERROR(-20005,
                'Stock insuficiente en el lote ' || p_lote_id ||
                '. Disponible: ' || v_stock_actual ||
                ' kg, solicitado: ' || p_cantidad_kg || ' kg');
        END IF;
    END IF;

    -- 5. Registrar el movimiento
    INSERT INTO movimiento_inventario
        (lote_id, tipo_movimiento_id, fecha_movimiento, cantidad_kg, observaciones)
    VALUES
        (p_lote_id, v_tipo_movimiento_id, SYSTIMESTAMP, p_cantidad_kg, p_observaciones);

    -- 6. Actualizar el estado del lote segun el stock resultante
    v_stock_resultante := NVL(fn_stock_actual_lote(p_lote_id), 0);

    BEGIN
        SELECT cd.id
          INTO v_id_estado_agotado
          FROM cat_detalle cd
          JOIN cat_maestro cm ON cm.id_mae = cd.id_mae
         WHERE cm.sigla_tabla = 'ELO'
           AND cd.nombre = 'AGOTADO';
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20004,
                'No se encontro el estado AGOTADO en el catalogo ELO');
    END;

    BEGIN
        SELECT cd.id
          INTO v_id_estado_disponible
          FROM cat_detalle cd
          JOIN cat_maestro cm ON cm.id_mae = cd.id_mae
         WHERE cm.sigla_tabla = 'ELO'
           AND cd.nombre = 'DISPONIBLE';
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20008,
                'No se encontro el estado DISPONIBLE en el catalogo ELO');
    END;

    IF v_stock_resultante <= 0 THEN
        UPDATE lote
           SET estado_id = v_id_estado_agotado
         WHERE lote_id = p_lote_id;
    ELSE
        -- Si estaba AGOTADO y recupero stock, vuelve a DISPONIBLE
        UPDATE lote
           SET estado_id = v_id_estado_disponible
         WHERE lote_id = p_lote_id
           AND estado_id = v_id_estado_agotado;
    END IF;

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END sp_registrar_movimiento_inventario;
/


/* ------------------------------------------------------------
   3. FN_CAPACIDAD_DISPONIBLE_CENTRO
   Para que: saber cuanto espacio le queda a un centro de acopio,
   restando de su capacidad maxima el stock actual de los lotes
   que siguen en el centro (DISPONIBLE o RESERVADO).
   Donde se usaria: al registrar una nueva RECEPCION_ACOPIO, para
   validar que el centro tiene sitio antes de aceptar el ingreso.
   ------------------------------------------------------------ */
CREATE OR REPLACE FUNCTION fn_capacidad_disponible_centro (
    p_centro_acopio_id IN centro_acopio.centro_acopio_id%TYPE
) RETURN NUMBER
IS
    v_capacidad_maxima centro_acopio.capacidad_maxima_kg%TYPE;
    v_kg_ocupados      NUMBER := 0;
BEGIN
    BEGIN
        SELECT capacidad_maxima_kg
          INTO v_capacidad_maxima
          FROM centro_acopio
         WHERE centro_acopio_id = p_centro_acopio_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20007,
                'El centro de acopio ' || p_centro_acopio_id || ' no existe');
    END;

    SELECT NVL(SUM(NVL(fn_stock_actual_lote(l.lote_id), 0)), 0)
      INTO v_kg_ocupados
      FROM lote l
      JOIN recepcion_acopio ra ON ra.recepcion_id = l.recepcion_id
      JOIN cat_detalle cd      ON cd.id = l.estado_id
      JOIN cat_maestro cm      ON cm.id_mae = cd.id_mae
     WHERE ra.centro_acopio_id = p_centro_acopio_id
       AND cm.sigla_tabla = 'ELO'
       AND cd.nombre IN ('DISPONIBLE', 'RESERVADO');

    RETURN v_capacidad_maxima - v_kg_ocupados;
END fn_capacidad_disponible_centro;
/


/* ------------------------------------------------------------
   4. SP_ASIGNAR_PEDIDO_A_RUTA
   Para que: evitar que quede un pedido asignado a una ruta sin
   su registro de ENTREGA. Hace ambos inserts (RUTA_PEDIDO y
   ENTREGA) dentro de una sola transaccion.
   Donde se usaria: cuando el modulo de PostgreSQL confirma que
   un pedido (INTERGESTOR) se sube a una ruta.
   ------------------------------------------------------------ */
CREATE OR REPLACE PROCEDURE sp_asignar_pedido_a_ruta (
    p_ruta_id       IN ruta_reparto.ruta_id%TYPE,
    p_pedido_id     IN NUMBER,   -- referencia INTERGESTOR (PostgreSQL)
    p_orden_entrega IN NUMBER
)
IS
    v_ruta_pedido_id   ruta_pedido.ruta_pedido_id%TYPE;
    v_fecha_salida     ruta_reparto.fecha_hora_salida%TYPE;
    v_estado_ruta      cat_detalle.nombre%TYPE;
    v_id_estado_pend   cat_detalle.id%TYPE;
BEGIN
    -- 1. Orden de entrega valido
    IF p_orden_entrega IS NULL OR p_orden_entrega <= 0 THEN
        RAISE_APPLICATION_ERROR(-20010,
            'El orden de entrega debe ser un numero mayor a cero');
    END IF;

    -- 2. La ruta debe existir y poder recibir pedidos
    BEGIN
        SELECT r.fecha_hora_salida, cd.nombre
          INTO v_fecha_salida, v_estado_ruta
          FROM ruta_reparto r
          JOIN cat_detalle cd ON cd.id = r.estado_id
         WHERE r.ruta_id = p_ruta_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20011,
                'La ruta ' || p_ruta_id || ' no existe');
    END;

    IF v_estado_ruta IN ('COMPLETADA', 'CANCELADA') THEN
        RAISE_APPLICATION_ERROR(-20012,
            'No se pueden asignar pedidos a una ruta ' || v_estado_ruta);
    END IF;

    -- 3. Estado inicial de la entrega: PENDIENTE (catalogo EEN)
    BEGIN
        SELECT cd.id
          INTO v_id_estado_pend
          FROM cat_detalle cd
          JOIN cat_maestro cm ON cm.id_mae = cd.id_mae
         WHERE cm.sigla_tabla = 'EEN'
           AND cd.nombre = 'PENDIENTE';
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20013,
                'No se encontro el estado PENDIENTE en el catalogo EEN');
    END;

    -- 4. Asignar el pedido a la ruta
    BEGIN
        INSERT INTO ruta_pedido (ruta_id, pedido_id, orden_entrega, fecha_asignacion)
        VALUES (p_ruta_id, p_pedido_id, p_orden_entrega, SYSTIMESTAMP)
        RETURNING ruta_pedido_id INTO v_ruta_pedido_id;
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            RAISE_APPLICATION_ERROR(-20014,
                'El pedido ' || p_pedido_id ||
                ' ya esta asignado a la ruta ' || p_ruta_id);
    END;

    -- 5. Crear su entrega
    INSERT INTO entrega (ruta_pedido_id, fecha_programada, estado_id)
    VALUES (v_ruta_pedido_id, TRUNC(v_fecha_salida), v_id_estado_pend);

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END sp_asignar_pedido_a_ruta;
/


/* ------------------------------------------------------------
   5. FN_MONTO_TOTAL_PAGADO_PEDIDO
   Para que: sumar los pagos en estado PAGADO de un pedido. Como
   el pedido vive en PostgreSQL (INTERGESTOR), esta funcion es el
   punto para reconciliar "cuanto se ha pagado ya a este pedido"
   sin traer todas las filas de PAGO al backend.
   Donde se usaria: detalle de pedido / conciliacion de pagos
   entre Oracle y PostgreSQL.
   ------------------------------------------------------------ */
CREATE OR REPLACE FUNCTION fn_monto_total_pagado_pedido (
    p_pedido_id IN NUMBER   -- referencia INTERGESTOR (PostgreSQL)
) RETURN NUMBER
IS
    v_total NUMBER := 0;
BEGIN
    SELECT NVL(SUM(p.monto), 0)
      INTO v_total
      FROM pago p
      JOIN cat_detalle cd ON cd.id = p.estado_id
      JOIN cat_maestro cm ON cm.id_mae = cd.id_mae
     WHERE p.pedido_id = p_pedido_id
       AND cm.sigla_tabla = 'EPA'
       AND cd.nombre = 'PAGADO';

    RETURN v_total;
END fn_monto_total_pagado_pedido;
/


/* ------------------------------------------------------------
   6. SP_ACTUALIZAR_ESTADO_RUTA
   Para que: cambiar el estado de una ruta validando que el
   estado recibido pertenece al catalogo ERU. Sin esto, un UPDATE
   directo podria asignar el id de un estado de otro catalogo,
   ya que estado_id es solo un NUMBER.
   Donde se usaria: cuando el transportista marca la ruta como
   EN CURSO, COMPLETADA o CANCELADA desde la app movil.

   p_nuevo_estado recibe el NOMBRE: PROGRAMADA, EN CURSO,
   COMPLETADA o CANCELADA.
   ------------------------------------------------------------ */
CREATE OR REPLACE PROCEDURE sp_actualizar_estado_ruta (
    p_ruta_id       IN ruta_reparto.ruta_id%TYPE,
    p_nuevo_estado  IN VARCHAR2
)
IS
    v_estado_id cat_detalle.id%TYPE;
BEGIN
    SELECT cd.id
      INTO v_estado_id
      FROM cat_detalle cd
      JOIN cat_maestro cm ON cm.id_mae = cd.id_mae
     WHERE cm.sigla_tabla = 'ERU'
       AND UPPER(cd.nombre) = UPPER(TRIM(p_nuevo_estado))
       AND cd.estado = 'S';

    UPDATE ruta_reparto
       SET estado_id = v_estado_id
     WHERE ruta_id = p_ruta_id;

    IF SQL%ROWCOUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20003,
            'No existe la ruta con id ' || p_ruta_id);
    END IF;

    COMMIT;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20009,
            'Estado de ruta no valido: ' || p_nuevo_estado);
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END sp_actualizar_estado_ruta;
/