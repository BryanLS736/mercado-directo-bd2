-- ======================================================================================================================================
-- MERCADO DIRECTO
-- PERMISOS DEL ROL app_role y dev_role
-- EJECUTAR DESPUÉS DE CREAR LAS TABLAS
-- ======================================================================================================================================


-- ============================================================
-- 1. TABLAS DE UBICACIÓN
-- ============================================================
-- Son tablas de referencia geográfica.
-- La aplicación únicamente necesita consultarlas.
-- ============================================================

GRANT SELECT
ON TABLE
    mercado.departamento,
    mercado.provincia,
    mercado.distrito
TO app_role;


-- ============================================================
-- 2. CATEGORÍAS Y PRODUCTOS
-- ============================================================
-- Se permite consultar, registrar y actualizar información.
-- No se permite DELETE para conservar los registros.
-- ============================================================

GRANT SELECT, INSERT, UPDATE
ON TABLE
    mercado.categoria,
    mercado.producto
TO app_role;


-- ============================================================
-- 3. AGRICULTORES
-- ============================================================
-- La aplicación puede registrar y actualizar agricultores.
-- No se permite DELETE para conservar el historial.
-- ============================================================

GRANT SELECT, INSERT, UPDATE
ON TABLE
    mercado.agricultor
TO app_role;


-- ============================================================
-- 4. UBICACIONES DE AGRICULTORES
-- ============================================================

GRANT SELECT, INSERT, UPDATE
ON TABLE
    mercado.ubicacion_agricultor
TO app_role;


-- ============================================================
-- 5. OFERTAS DE COSECHA
-- ============================================================
-- Las ofertas pueden registrarse y actualizarse.
-- No se elimina físicamente una oferta.
-- ============================================================

GRANT SELECT, INSERT, UPDATE
ON TABLE
    mercado.oferta_cosecha
TO app_role;


-- ============================================================
-- 6. CLIENTES
-- ============================================================

GRANT SELECT, INSERT, UPDATE
ON TABLE
    mercado.cliente_consumidor
TO app_role;


-- ============================================================
-- 7. DIRECCIONES DE CLIENTES
-- ============================================================

GRANT SELECT, INSERT, UPDATE
ON TABLE
    mercado.direccion_cliente
TO app_role;


-- ============================================================
-- 8. PEDIDOS
-- ============================================================
-- Los pedidos forman parte del historial de operaciones.
-- Por ello no se permite DELETE.
-- ============================================================

GRANT SELECT, INSERT, UPDATE
ON TABLE
    mercado.pedido
TO app_role;


-- ============================================================
-- 9. DETALLE DE PEDIDOS
-- ============================================================

GRANT SELECT, INSERT, UPDATE
ON TABLE
    mercado.detalle_pedido
TO app_role;


-- ============================================================
-- 10. PEDIDOS AGRUPADOS
-- ============================================================

GRANT SELECT, INSERT, UPDATE
ON TABLE
    mercado.pedido_agrupado
TO app_role;


-- ============================================================
-- 11. DETALLE DE PEDIDOS AGRUPADOS
-- ============================================================

GRANT SELECT, INSERT, UPDATE
ON TABLE
    mercado.detalle_pedido_agrupado
TO app_role;


-- ============================================================
-- 12. PERMISOS SOBRE SECUENCIAS
-- ============================================================
-- Las tablas utilizan SERIAL en sus claves primarias.
-- Por ello app_role necesita USAGE sobre las secuencias
-- para poder realizar INSERT correctamente.
-- ============================================================

GRANT USAGE, SELECT
ON ALL SEQUENCES
IN SCHEMA mercado
TO app_role;


-- ============================================================
-- 13. PERMISOS DE LECTURA PARA EL ROL DE DESARROLLO
-- ============================================================
-- Los desarrolladores (dev_role) necesitan consultar los datos
-- para probar y depurar. Solo lectura: no se les da INSERT,
-- UPDATE ni DELETE sobre las tablas.
-- ============================================================

GRANT SELECT
ON ALL TABLES
IN SCHEMA mercado
TO dev_role;

GRANT USAGE, SELECT
ON ALL SEQUENCES
IN SCHEMA mercado
TO dev_role;


-- ============================================================
-- FIN DE LOS PERMISOS DE app_role Y dev_role
-- ============================================================