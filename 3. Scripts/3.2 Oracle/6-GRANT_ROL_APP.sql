/* ============================================================
   PROYECTO: MERCADO DIRECTO - ORACLE
   GRANTS DE APLICACION (rol_aplicacion / app_service)
   ============================================================
   Cuando ejecutar esto: DESPUES de correr, en este orden:
     1) 01_configuracion_inicial.sql   (crea rol_aplicacion)
     2) 02_tablas.sql                  (crea las tablas)
     3) 04_funciones_procedimientos.sql (crea las funciones/SP)

   Con que usuario conectarse: MD_OWNER.
   Los objetos (tablas, funciones, procedimientos) pertenecen a
   MD_OWNER, asi que solo MD_OWNER (o alguien con privilegio
   GRANT ANY OBJECT PRIVILEGE, como bryan/rol_dba) puede otorgar
   privilegios sobre ellos. Lo mas simple y explicito es conectar
   como MD_OWNER y correr este script tal cual.

   Filosofia de los permisos:
     - Tablas de CATALOGO / REFERENCIA (cat_maestro, cat_detalle,
       departamento, provincia, distrito, tipo_vehiculo): la app
       solo LEE estos valores, no los mantiene. Se otorga SELECT
       unicamente. Si en el futuro la app necesita un CRUD de
       administracion de catalogos, se amplia puntualmente.
     - Tablas TRANSACCIONALES (centro_acopio, recepcion_acopio,
       lote, movimiento_inventario, vehiculo, transportista,
       ruta_reparto, ruta_pedido, entrega, pago): la app necesita
       operar el dia a dia del negocio, se otorga CRUD completo
       (SELECT, INSERT, UPDATE, DELETE).
   ============================================================ */


/* ============================================================
   1. TABLAS DE CATALOGO / REFERENCIA -> SOLO LECTURA
   ============================================================ */

GRANT SELECT ON MD_OWNER.cat_maestro   TO rol_aplicacion;
GRANT SELECT ON MD_OWNER.cat_detalle   TO rol_aplicacion;
GRANT SELECT ON MD_OWNER.departamento  TO rol_aplicacion;
GRANT SELECT ON MD_OWNER.provincia     TO rol_aplicacion;
GRANT SELECT ON MD_OWNER.distrito      TO rol_aplicacion;
GRANT SELECT ON MD_OWNER.tipo_vehiculo TO rol_aplicacion;


/* ============================================================
   2. TABLAS TRANSACCIONALES
   ============================================================ */

GRANT SELECT, INSERT, UPDATE ON MD_OWNER.centro_acopio  TO rol_aplicacion;
GRANT SELECT, INSERT, UPDATE ON MD_OWNER.vehiculo       TO rol_aplicacion;
GRANT SELECT, INSERT, UPDATE ON MD_OWNER.transportista  TO rol_aplicacion;

GRANT SELECT, INSERT, UPDATE ON MD_OWNER.lote             TO rol_aplicacion;
GRANT SELECT, INSERT, UPDATE ON MD_OWNER.recepcion_acopio TO rol_aplicacion;
GRANT SELECT, INSERT, UPDATE ON MD_OWNER.pago             TO rol_aplicacion;
GRANT SELECT, INSERT, UPDATE ON MD_OWNER.entrega          TO rol_aplicacion;

GRANT SELECT ON MD_OWNER.movimiento_inventario TO rol_aplicacion;
GRANT SELECT ON MD_OWNER.ruta_pedido           TO rol_aplicacion;
GRANT SELECT ON MD_OWNER.ruta_reparto          TO rol_aplicacion;


/* ============================================================
   3. EXECUTE SOBRE FUNCIONES Y PROCEDIMIENTOS
   ============================================================
   Sin esto, app_service no puede invocar la logica de negocio
   centralizada (sp_registrar_movimiento_inventario, etc.) aunque
   ya tenga permisos CRUD sobre las tablas subyacentes.
   ------------------------------------------------------------ */

GRANT EXECUTE ON MD_OWNER.fn_stock_actual_lote             TO rol_aplicacion;
GRANT EXECUTE ON MD_OWNER.sp_registrar_movimiento_inventario TO rol_aplicacion;
GRANT EXECUTE ON MD_OWNER.fn_capacidad_disponible_centro    TO rol_aplicacion;
GRANT EXECUTE ON MD_OWNER.sp_asignar_pedido_a_ruta          TO rol_aplicacion;
GRANT EXECUTE ON MD_OWNER.fn_monto_total_pagado_pedido      TO rol_aplicacion;
GRANT EXECUTE ON MD_OWNER.sp_actualizar_estado_ruta         TO rol_aplicacion;
