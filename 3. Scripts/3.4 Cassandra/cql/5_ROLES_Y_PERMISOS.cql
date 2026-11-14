-- =====================================================================
-- 5_ROLES_Y_PERMISOS.cql  -  Mercado Directo (Cassandra)
-- Administración de usuarios. En Cassandra TODO es un "role": un rol puede
-- iniciar sesión (usuario) o solo agrupar permisos (rol de permisos).
-- Aquí se crean 2 roles de permisos; los usuarios los crea 05_usuarios.sh
-- (con contraseña pedida por pantalla, sin guardarla en ningún archivo).
--
-- Ejecutar como administrador:  ./05_usuarios.sh
--
-- EQUIVALENCIA CON LOS OTROS GESTORES
--   Cassandra               MongoDB                PostgreSQL        Oracle
--   dba_cassandra (superuser)  dba_mongo (root)    diego / dba_role  rol_dba
--   rol_aplicacion          rol_aplicacion_mongo   app_role          rol_aplicacion
--   rol_lectura             read                   dev/lectura_role  -
--
-- LIMITACIÓN IMPORTANTE: Cassandra no tiene permiso solo de insertar. El permiso
-- MODIFY incluye INSERT, UPDATE, DELETE y TRUNCATE. Por eso la aplicación puede
-- borrar en las tablas donde se le da MODIFY. Se compensa dando MODIFY solo en las
-- tablas que la aplicación escribe, y únicamente SELECT en las demás.
-- =====================================================================

-- Rol de la aplicación (no inicia sesión por sí mismo)
CREATE ROLE IF NOT EXISTS rol_aplicacion WITH LOGIN = false;
GRANT SELECT ON TABLE mercado_cassandra.pedidos_por_cliente          TO rol_aplicacion;
GRANT MODIFY ON TABLE mercado_cassandra.pedidos_por_cliente          TO rol_aplicacion;
GRANT SELECT ON TABLE mercado_cassandra.pagos_por_metodo_dia         TO rol_aplicacion;
GRANT MODIFY ON TABLE mercado_cassandra.pagos_por_metodo_dia         TO rol_aplicacion;
GRANT SELECT ON TABLE mercado_cassandra.movimientos_por_tipo_mes     TO rol_aplicacion;
GRANT MODIFY ON TABLE mercado_cassandra.movimientos_por_tipo_mes     TO rol_aplicacion;
GRANT SELECT ON TABLE mercado_cassandra.recepciones_por_centro       TO rol_aplicacion;
GRANT MODIFY ON TABLE mercado_cassandra.recepciones_por_centro       TO rol_aplicacion;
-- Tabla de totales calculados: solo lectura para la aplicación
GRANT SELECT ON TABLE mercado_cassandra.recaudacion_por_metodo_mes TO rol_aplicacion;

-- Rol de solo lectura (analistas y desarrolladores del equipo)
CREATE ROLE IF NOT EXISTS rol_lectura WITH LOGIN = false;
GRANT SELECT ON KEYSPACE mercado_cassandra TO rol_lectura;
