
-- ============================================================
-- PARTE II
-- CONFIGURACIÓN DE LA BASE DE DATOS
-- CONECTADO A: mercado_directo
-- ============================================================


-- ============================================================
-- 6. REFORZAR LA SEGURIDAD DEL ESQUEMA PUBLIC
-- ============================================================

-- Evita que los usuarios puedan crear objetos dentro
-- del esquema public.

REVOKE CREATE
ON SCHEMA public
FROM PUBLIC;


-- Elimina los permisos otorgados por defecto a PUBLIC
-- sobre la base de datos.

REVOKE ALL
ON DATABASE mercado_directo
FROM PUBLIC;


-- ============================================================
-- 7. PERMISOS A NIVEL DE BASE DE DATOS
-- ============================================================

-- Permite que los roles de desarrollo y aplicación
-- puedan conectarse a la base de datos.

GRANT CONNECT
ON DATABASE mercado_directo
TO dev_role, app_role;


-- ============================================================
-- 8. CREACIÓN DEL ESQUEMA PROPIO
-- ============================================================

-- Se crea un esquema propio para organizar los objetos
-- pertenecientes al proyecto Mercado Directo.
--
-- Se evita utilizar "public" para mantener una estructura
-- más organizada y controlar los permisos.

CREATE SCHEMA IF NOT EXISTS mercado
AUTHORIZATION dba_role;


-- ============================================================
-- 9. PERMISOS PARA EL ROL DE DESARROLLO
-- ============================================================

-- CREATE:
-- Permite crear objetos dentro del esquema, como:
-- tablas, vistas, secuencias, etc.
--
-- USAGE:
-- Permite utilizar el esquema y acceder a sus objetos.

GRANT CREATE, USAGE
ON SCHEMA mercado
TO dev_role;


-- ============================================================
-- 10. PERMISOS PARA EL ROL DE APLICACIÓN
-- ============================================================

-- USAGE:
-- Permite que la aplicación utilice el esquema.
--
-- No se otorga CREATE porque la aplicación no debe crear
-- ni modificar la estructura de la base de datos.

GRANT USAGE
ON SCHEMA mercado
TO app_role;


-- ============================================================
-- 11. PERMISOS POR DEFECTO PARA NUEVOS OBJETOS
-- ============================================================

-- ------------------------------------------------------------
-- 11.1 PERMISOS POR DEFECTO PARA TABLAS
-- ------------------------------------------------------------
-- La aplicación podrá consultar las tablas que sean creadas
-- posteriormente por el usuario que genere los objetos.
--
-- Los permisos INSERT, UPDATE y DELETE se asignarán
-- posteriormente de manera específica para cada tabla.
-- ------------------------------------------------------------

ALTER DEFAULT PRIVILEGES
FOR ROLE dba_role
IN SCHEMA mercado
GRANT SELECT
ON TABLES
TO app_role;


-- ------------------------------------------------------------
-- 11.2 PERMISOS POR DEFECTO PARA SECUENCIAS
-- ------------------------------------------------------------
-- Las tablas que utilizan SERIAL generan automáticamente
-- secuencias para sus claves primarias.
--
-- Se otorgan permisos para que la aplicación pueda utilizar
-- dichas secuencias cuando realice inserciones.
-- ------------------------------------------------------------

ALTER DEFAULT PRIVILEGES
FOR ROLE dba_role
IN SCHEMA mercado
GRANT USAGE
ON SEQUENCES
TO app_role;

-- ------------------------------------------------------------
-- 11.3 PERMISOS PARA EL ROL DE DESARROLLO
-- ------------------------------------------------------------
-- dev_role puede crear objetos en el esquema (paso 9), pero
-- sin SELECT no podría consultar las tablas ya existentes ni
-- las creadas por dba_role. Se le otorga solo lectura.
--
-- (Los permisos sobre las tablas que ya existen se otorgan en
--  5_PERMISOS_APP.sql, sección 13.)
-- ------------------------------------------------------------

ALTER DEFAULT PRIVILEGES
FOR ROLE dba_role
IN SCHEMA mercado
GRANT SELECT
ON TABLES
TO dev_role;

ALTER DEFAULT PRIVILEGES
FOR ROLE dba_role
IN SCHEMA mercado
GRANT USAGE
ON SEQUENCES
TO dev_role;
-- ============================================================
-- FIN DE LA CONFIGURACIÓN INICIAL
-- ============================================================
