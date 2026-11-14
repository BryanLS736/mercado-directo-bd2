/* ============================================================
   PROYECTO: MERCADO DIRECTO - ORACLE
   TRIGGERS DE INTEGRIDAD DE DOMINIO
   ============================================================
   Problema que resuelve:
     Las columnas estado_id / tipo_movimiento_id / metodo_pago_id /
     tipo_documento_id son FOREIGN KEY hacia cat_detalle(id), pero
     una FK por si sola solo garantiza que el id EXISTE en
     cat_detalle; no garantiza que pertenezca al catalogo (sigla)
     correcto. Sin esta validacion, un INSERT/UPDATE directo por
     SQL (sin pasar por los procedimientos del script 4) podria
     guardar, por ejemplo, el id de un estado de VEHICULO en el
     estado_id de una RUTA_REPARTO, porque para Oracle ambos son
     solo NUMBER y la FK no distingue el dominio.

     Oracle no permite subconsultas dentro de un CHECK constraint,
     asi que la forma correcta de cerrar este hueco es con
     triggers BEFORE INSERT OR UPDATE por cada columna sensible.

   Como esta organizado:
     1) Una funcion generica fn_validar_dominio_cat_detalle que
        centraliza la logica de validacion (evita repetir el
        mismo JOIN en cada trigger).
     2) Un trigger por cada columna que referencia un dominio de
        cat_detalle, cada uno con su propio codigo de error.

   Cuando ejecutar esto: DESPUES de 02_tablas.sql y 03_datos.sql
   (o al menos despues de 02_tablas.sql). Conectado como MD_OWNER,
   dueno de las tablas y unico con privilegio CREATE TRIGGER
   (otorgado via rol_esquema).
   ============================================================ */

SET SERVEROUTPUT ON;


/* ------------------------------------------------------------
   0. FUNCION GENERICA DE VALIDACION DE DOMINIO
   Para que: dado un id de cat_detalle y la sigla del catalogo al
   que deberia pertenecer (ECA, ERE, ELO, TMV, EVE, TDO, ETR, ERU,
   EEN, MPA, EPA), confirma que ese id realmente pertenece a ese
   catalogo. La reutilizan todos los triggers de abajo.
   ------------------------------------------------------------ */
CREATE OR REPLACE FUNCTION fn_validar_dominio_cat_detalle (
    p_id    IN cat_detalle.id%TYPE,
    p_sigla IN cat_maestro.sigla_tabla%TYPE
) RETURN VARCHAR2   -- 'S' si el id pertenece al dominio, 'N' si no
IS
    v_existe NUMBER;
BEGIN
    IF p_id IS NULL THEN
        RETURN 'S';   -- deja que la restriccion NOT NULL de la columna maneje este caso
    END IF;

    SELECT COUNT(*)
    INTO   v_existe
    FROM   cat_detalle cd
    JOIN   cat_maestro cm ON cm.id_mae = cd.id_mae
    WHERE  cd.id = p_id
    AND    cm.sigla_tabla = p_sigla;

    RETURN CASE WHEN v_existe > 0 THEN 'S' ELSE 'N' END;
END fn_validar_dominio_cat_detalle;
/


/* ------------------------------------------------------------
   1. CENTRO_ACOPIO.ESTADO_ID -> dominio ECA
   ------------------------------------------------------------ */
CREATE OR REPLACE TRIGGER trg_centro_acopio_estado_bi
BEFORE INSERT OR UPDATE OF estado_id ON centro_acopio
FOR EACH ROW
BEGIN
    IF fn_validar_dominio_cat_detalle(:NEW.estado_id, 'ECA') = 'N' THEN
        RAISE_APPLICATION_ERROR(-20101,
            'estado_id ' || :NEW.estado_id || ' no pertenece al dominio ECA (Estado Centro Acopio)');
    END IF;
END trg_centro_acopio_estado_bi;
/


/* ------------------------------------------------------------
   2. RECEPCION_ACOPIO.ESTADO_ID -> dominio ERE
   ------------------------------------------------------------ */
CREATE OR REPLACE TRIGGER trg_recepcion_acopio_estado_bi
BEFORE INSERT OR UPDATE OF estado_id ON recepcion_acopio
FOR EACH ROW
BEGIN
    IF fn_validar_dominio_cat_detalle(:NEW.estado_id, 'ERE') = 'N' THEN
        RAISE_APPLICATION_ERROR(-20102,
            'estado_id ' || :NEW.estado_id || ' no pertenece al dominio ERE (Estado Recepcion Acopio)');
    END IF;
END trg_recepcion_acopio_estado_bi;
/


/* ------------------------------------------------------------
   3. LOTE.ESTADO_ID -> dominio ELO
   ------------------------------------------------------------ */
CREATE OR REPLACE TRIGGER trg_lote_estado_bi
BEFORE INSERT OR UPDATE OF estado_id ON lote
FOR EACH ROW
BEGIN
    IF fn_validar_dominio_cat_detalle(:NEW.estado_id, 'ELO') = 'N' THEN
        RAISE_APPLICATION_ERROR(-20103,
            'estado_id ' || :NEW.estado_id || ' no pertenece al dominio ELO (Estado Lote)');
    END IF;
END trg_lote_estado_bi;
/


/* ------------------------------------------------------------
   4. MOVIMIENTO_INVENTARIO.TIPO_MOVIMIENTO_ID -> dominio TMV
   ------------------------------------------------------------ */
CREATE OR REPLACE TRIGGER trg_movimiento_inv_tipo_bi
BEFORE INSERT OR UPDATE OF tipo_movimiento_id ON movimiento_inventario
FOR EACH ROW
BEGIN
    IF fn_validar_dominio_cat_detalle(:NEW.tipo_movimiento_id, 'TMV') = 'N' THEN
        RAISE_APPLICATION_ERROR(-20104,
            'tipo_movimiento_id ' || :NEW.tipo_movimiento_id || ' no pertenece al dominio TMV (Tipo Movimiento Inventario)');
    END IF;
END trg_movimiento_inv_tipo_bi;
/


/* ------------------------------------------------------------
   5. VEHICULO.ESTADO_ID -> dominio EVE
   ------------------------------------------------------------ */
CREATE OR REPLACE TRIGGER trg_vehiculo_estado_bi
BEFORE INSERT OR UPDATE OF estado_id ON vehiculo
FOR EACH ROW
BEGIN
    IF fn_validar_dominio_cat_detalle(:NEW.estado_id, 'EVE') = 'N' THEN
        RAISE_APPLICATION_ERROR(-20105,
            'estado_id ' || :NEW.estado_id || ' no pertenece al dominio EVE (Estado Vehiculo)');
    END IF;
END trg_vehiculo_estado_bi;
/


/* ------------------------------------------------------------
   6. TRANSPORTISTA.TIPO_DOCUMENTO_ID -> dominio TDO
   ------------------------------------------------------------ */
CREATE OR REPLACE TRIGGER trg_transportista_tipodoc_bi
BEFORE INSERT OR UPDATE OF tipo_documento_id ON transportista
FOR EACH ROW
BEGIN
    IF fn_validar_dominio_cat_detalle(:NEW.tipo_documento_id, 'TDO') = 'N' THEN
        RAISE_APPLICATION_ERROR(-20106,
            'tipo_documento_id ' || :NEW.tipo_documento_id || ' no pertenece al dominio TDO (Tipo Documento Transportista)');
    END IF;
END trg_transportista_tipodoc_bi;
/


/* ------------------------------------------------------------
   7. TRANSPORTISTA.ESTADO_ID -> dominio ETR
   ------------------------------------------------------------ */
CREATE OR REPLACE TRIGGER trg_transportista_estado_bi
BEFORE INSERT OR UPDATE OF estado_id ON transportista
FOR EACH ROW
BEGIN
    IF fn_validar_dominio_cat_detalle(:NEW.estado_id, 'ETR') = 'N' THEN
        RAISE_APPLICATION_ERROR(-20107,
            'estado_id ' || :NEW.estado_id || ' no pertenece al dominio ETR (Estado Transportista)');
    END IF;
END trg_transportista_estado_bi;
/


/* ------------------------------------------------------------
   8. RUTA_REPARTO.ESTADO_ID -> dominio ERU
   ------------------------------------------------------------ */
CREATE OR REPLACE TRIGGER trg_ruta_reparto_estado_bi
BEFORE INSERT OR UPDATE OF estado_id ON ruta_reparto
FOR EACH ROW
BEGIN
    IF fn_validar_dominio_cat_detalle(:NEW.estado_id, 'ERU') = 'N' THEN
        RAISE_APPLICATION_ERROR(-20108,
            'estado_id ' || :NEW.estado_id || ' no pertenece al dominio ERU (Estado Ruta Reparto)');
    END IF;
END trg_ruta_reparto_estado_bi;
/


/* ------------------------------------------------------------
   9. ENTREGA.ESTADO_ID -> dominio EEN
   ------------------------------------------------------------ */
CREATE OR REPLACE TRIGGER trg_entrega_estado_bi
BEFORE INSERT OR UPDATE OF estado_id ON entrega
FOR EACH ROW
BEGIN
    IF fn_validar_dominio_cat_detalle(:NEW.estado_id, 'EEN') = 'N' THEN
        RAISE_APPLICATION_ERROR(-20109,
            'estado_id ' || :NEW.estado_id || ' no pertenece al dominio EEN (Estado Entrega)');
    END IF;
END trg_entrega_estado_bi;
/


/* ------------------------------------------------------------
   10. PAGO.METODO_PAGO_ID -> dominio MPA
   ------------------------------------------------------------ */
CREATE OR REPLACE TRIGGER trg_pago_metodo_bi
BEFORE INSERT OR UPDATE OF metodo_pago_id ON pago
FOR EACH ROW
BEGIN
    IF fn_validar_dominio_cat_detalle(:NEW.metodo_pago_id, 'MPA') = 'N' THEN
        RAISE_APPLICATION_ERROR(-20110,
            'metodo_pago_id ' || :NEW.metodo_pago_id || ' no pertenece al dominio MPA (Metodo de Pago)');
    END IF;
END trg_pago_metodo_bi;
/


/* ------------------------------------------------------------
   11. PAGO.ESTADO_ID -> dominio EPA
   ------------------------------------------------------------ */
CREATE OR REPLACE TRIGGER trg_pago_estado_bi
BEFORE INSERT OR UPDATE OF estado_id ON pago
FOR EACH ROW
BEGIN
    IF fn_validar_dominio_cat_detalle(:NEW.estado_id, 'EPA') = 'N' THEN
        RAISE_APPLICATION_ERROR(-20111,
            'estado_id ' || :NEW.estado_id || ' no pertenece al dominio EPA (Estado Pago)');
    END IF;
END trg_pago_estado_bi;
/

/* ============================================================
   FIN DE TRIGGERS DE INTEGRIDAD DE DOMINIO

   NOTA: estos triggers tambien se disparan cuando insertas/
   actualizas a traves de los procedimientos del script 4
   (sp_registrar_movimiento_inventario, etc.). Eso es correcto y
   deseado: son una segunda capa de defensa, no un reemplazo de
   la validacion que ya hacen esos procedimientos.
   ============================================================ */