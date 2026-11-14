-- ============================================================
-- MERCADO DIRECTO
-- CONFIGURACIÓN INICIAL DEL SERVIDOR POSTGRESQL
-- ============================================================

-- ============================================================
-- NOTA GENERAL
-- ============================================================
-- PARTE I:
-- Los siguientes comandos se ejecutan conectado a la base
-- administrativa "postgres".
--
-- PARTE II:
-- Después de crear la base de datos "mercado_directo",
-- se debe establecer la conexión a dicha base de datos
-- para ejecutar la configuración del esquema y permisos.
--
-- Los TABLESPACES son objetos del servidor/cluster de
-- PostgreSQL, por lo que no se crean dentro de una base
-- de datos específica.
-- ============================================================


-- ============================================================
-- PARTE I
-- CONFIGURACIÓN DEL SERVIDOR POSTGRESQL
-- CONECTADO A: postgres
-- ============================================================


-- ============================================================
-- 1. CREACIÓN DE ROLES
-- ============================================================

-- ------------------------------------------------------------
-- 1.1 Rol de administración
-- ------------------------------------------------------------

CREATE ROLE dba_role
WITH
    NOSUPERUSER
    CREATEDB
    CREATEROLE
    INHERIT
    LOGIN
    PASSWORD 'DbaP4ss!';


-- ------------------------------------------------------------
-- 1.2 Rol de aplicación
-- ------------------------------------------------------------

CREATE ROLE app_role
WITH
    NOSUPERUSER
    NOCREATEDB
    NOCREATEROLE
    INHERIT
    LOGIN
    PASSWORD 'AppP4ss!';


-- ------------------------------------------------------------
-- 1.3 Rol de desarrollo
-- ------------------------------------------------------------

CREATE ROLE dev_role
WITH
    NOSUPERUSER
    NOCREATEDB
    NOCREATEROLE
    INHERIT
    NOLOGIN;


-- ============================================================
-- 2. CREACIÓN DE USUARIOS ASOCIADOS A LOS ROLES
-- ============================================================

-- ------------------------------------------------------------
-- 2.1 Usuario administrador
-- ------------------------------------------------------------
-- Usuario responsable de las tareas administrativas.
-- Hereda los privilegios de dba_role.
-- ------------------------------------------------------------

CREATE USER diego
WITH
    PASSWORD 'diEg0_P4ss!'
    IN ROLE dba_role;


-- ------------------------------------------------------------
-- 2.2 Usuarios desarrolladores
-- ------------------------------------------------------------
-- Los usuarios desarrolladores heredan los privilegios
-- definidos para dev_role.
-- ------------------------------------------------------------

CREATE USER isabella
WITH
    PASSWORD 'Is4bella_P4ss!'
    IN ROLE dev_role;

CREATE USER jheremy
WITH
    PASSWORD 'Jh3remy_P4ss!'
    IN ROLE dev_role;

CREATE USER misael
WITH
    PASSWORD 'Mis4el_P4ss!'
    IN ROLE dev_role;

CREATE USER bryan
WITH
    PASSWORD 'Bry4n_P4ss!'
    IN ROLE dev_role;


-- ------------------------------------------------------------
-- 2.3 Usuario de aplicación
-- ------------------------------------------------------------
-- Usuario técnico utilizado por la aplicación.
-- No representa a un integrante del equipo.
-- ------------------------------------------------------------

CREATE USER app_service
WITH
    PASSWORD 'S3rv1c10!'
    IN ROLE app_role;


-- ============================================================
-- 3. CREACIÓN DEL TABLESPACE PARA DATOS
-- ============================================================

-- ------------------------------------------------------------
-- Directorio físico que debe existir previamente en Windows:
--
-- C:\PostgreSQL\Tablespaces\ts_md_datos
--
-- El directorio debe estar vacío y contar con los permisos
-- necesarios para que PostgreSQL pueda utilizarlo.
--
-- Este tablespace será utilizado para almacenar los datos
-- principales de la base de datos.
-- ------------------------------------------------------------

CREATE TABLESPACE ts_md_datos
OWNER dba_role
LOCATION 'C:/PostgreSQL/Tablespaces/ts_md_datos';


-- ============================================================
-- 4. CREACIÓN DEL TABLESPACE PARA ÍNDICES
-- ============================================================

-- ------------------------------------------------------------
-- Directorio físico que debe existir previamente en Windows:
--
-- C:\PostgreSQL\Tablespaces\ts_md_indices
--
-- Este tablespace estará destinado al almacenamiento
-- de los índices.
--
-- Los índices podrán asignarse posteriormente de forma
-- explícita mediante TABLESPACE ts_md_indices.
-- ------------------------------------------------------------

CREATE TABLESPACE ts_md_indices
OWNER dba_role
LOCATION 'C:/PostgreSQL/Tablespaces/ts_md_indices';


-- ============================================================
-- 5. CREACIÓN DE LA BASE DE DATOS
-- ============================================================


CREATE DATABASE mercado_directo
WITH
    OWNER = dba_role
    ENCODING = 'UTF8'
    TEMPLATE = template0
    TABLESPACE = ts_md_datos
    CONNECTION LIMIT = 50;


-- ============================================================
-- IMPORTANTE
-- ============================================================
-- Hasta aquí se ejecuta conectado a:
--
--     postgres
--
-- Después de crear la base de datos, debes cambiar en pgAdmin
-- la conexión de "postgres" a:
--
--     mercado_directo
--
--
-- A partir de aquí comienza la PARTE II.
-- ============================================================



