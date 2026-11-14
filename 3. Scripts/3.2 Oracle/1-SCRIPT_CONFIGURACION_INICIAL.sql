-- ============================================================
-- MERCADO DIRECTO
-- CONFIGURACIÓN INICIAL DE ORACLE
-- ============================================================

-- ============================================================
-- NOTA GENERAL
-- ============================================================
-- Esta configuración se realiza dentro de la PDB donde
-- funcionará el proyecto Mercado Directo.
--
-- En Oracle, el esquema está asociado directamente a un usuario.
-- Por ello, no se utiliza CREATE SCHEMA como en PostgreSQL.
--
-- Este script debe ejecutarse con un usuario que ya tenga
-- privilegios de administrador (SYSTEM o un usuario con DBA),
-- ya que crea tablespaces, usuarios y roles.
--
-- Solo se piden 3 roles para el proyecto:
--   1) rol_esquema      -> dueño de las tablas (MD_OWNER)
--   2) rol_dba          -> administra usuarios/roles/tablespaces (bryan)
--   3) rol_aplicacion   -> solo se conecta y usa CRUD (app_service)
--
-- Estructura:
--
--     TS_MD_DATOS
--          ↓
--     datos del proyecto
--
--     TS_MD_INDICES
--          ↓
--     índices del proyecto
--
--     MD_OWNER  --------- rol_esquema
--          ↓
--     esquema Mercado Directo (tablas, vistas, secuencias...)
--
--     bryan     --------- rol_dba
--          ↓
--     administra usuarios, roles y tablespaces del proyecto
--
--     app_service ------- rol_aplicacion
--          ↓
--     se conecta y ejecuta CRUD sobre las tablas de MD_OWNER
-- ============================================================


-- ============================================================
-- 1. CREACIÓN DE TABLESPACE PARA DATOS
-- ============================================================

-- ------------------------------------------------------------
-- Este tablespace almacenará las tablas y demás objetos
-- principales de información del proyecto.
--
-- La ruta debe existir y ser accesible por Oracle.
--
-- EJEMPLO WINDOWS:
-- C:\Oracle\Tablespaces\ts_md_datos.dbf
-- ------------------------------------------------------------

CREATE TABLESPACE TS_MD_DATOS
DATAFILE 'C:\Oracle\Tablespaces\ts_md_datos.dbf'
SIZE 100M
AUTOEXTEND ON
NEXT 10M
MAXSIZE 1G
EXTENT MANAGEMENT LOCAL
SEGMENT SPACE MANAGEMENT AUTO;


-- ============================================================
-- 2. CREACIÓN DE TABLESPACE PARA ÍNDICES
-- ============================================================

-- ------------------------------------------------------------
-- Este tablespace estará destinado a los índices del proyecto.
-- ------------------------------------------------------------

CREATE TABLESPACE TS_MD_INDICES
DATAFILE 'C:\Oracle\Tablespaces\ts_md_indices.dbf'
SIZE 50M
AUTOEXTEND ON
NEXT 10M
MAXSIZE 500M
EXTENT MANAGEMENT LOCAL
SEGMENT SPACE MANAGEMENT AUTO;


-- ============================================================
-- 3. CREACIÓN DE LOS 3 ROLES DEL PROYECTO
-- ============================================================

-- ------------------------------------------------------------
-- 3.1 Rol de esquema (dueño de los objetos: tablas, vistas,
--     secuencias, procedimientos, triggers). Lo usará MD_OWNER,
--     el propietario real de las tablas del proyecto.
-- ------------------------------------------------------------

CREATE ROLE rol_esquema;

GRANT CREATE SESSION    TO rol_esquema;
GRANT CREATE TABLE      TO rol_esquema;
GRANT CREATE INDEX      TO rol_esquema;
GRANT CREATE VIEW       TO rol_esquema;
GRANT CREATE SEQUENCE   TO rol_esquema;
GRANT CREATE PROCEDURE  TO rol_esquema;
GRANT CREATE TRIGGER    TO rol_esquema;
GRANT CREATE SYNONYM    TO rol_esquema;


-- ------------------------------------------------------------
-- 3.2 Rol de DBA (administración): crear/alterar/eliminar
--     usuarios, roles y tablespaces. Esto es lo que distingue
--     a un DBA de un simple dueño de esquema: NO crea tablas
--     ni objetos de negocio, administra el entorno.
-- ------------------------------------------------------------

CREATE ROLE rol_dba;

GRANT CREATE SESSION       TO rol_dba;
GRANT CREATE USER          TO rol_dba;
GRANT ALTER USER           TO rol_dba;
GRANT DROP USER            TO rol_dba;
GRANT CREATE ROLE          TO rol_dba;
GRANT DROP ANY ROLE        TO rol_dba;
GRANT CREATE TABLESPACE    TO rol_dba;
GRANT ALTER TABLESPACE     TO rol_dba;
GRANT DROP TABLESPACE      TO rol_dba;
GRANT GRANT ANY ROLE       TO rol_dba;


-- ------------------------------------------------------------
-- 3.3 Rol de aplicación: solo necesita conectarse. Los permisos
--     CRUD sobre las tablas de MD_OWNER se otorgarán más
--     adelante, cuando esas tablas ya existan.
-- ------------------------------------------------------------

CREATE ROLE rol_aplicacion;

GRANT CREATE SESSION TO rol_aplicacion;


-- ============================================================
-- 4. CREACIÓN DEL USUARIO PROPIETARIO DEL ESQUEMA
-- ============================================================

-- ------------------------------------------------------------
-- MD_OWNER será el propietario del esquema de Mercado Directo:
-- aquí vivirán todas las tablas, vistas, secuencias, etc.
--
-- DEFAULT TABLESPACE:
--     TS_MD_DATOS
--
-- TEMPORARY TABLESPACE:
--     TEMP
--
-- QUOTA:
--     1G sobre el tablespace de datos.
--     500M sobre el tablespace de índices (necesario para
--     crear índices explícitos e implícitos de PK/UNIQUE).
-- ------------------------------------------------------------

CREATE USER MD_OWNER
IDENTIFIED BY "MdOwnerP4ss!"
DEFAULT TABLESPACE TS_MD_DATOS
TEMPORARY TABLESPACE TEMP
QUOTA 1G ON TS_MD_DATOS;

ALTER USER MD_OWNER QUOTA 500M ON TS_MD_INDICES;

-- MD_OWNER recibe el rol de ESQUEMA, no el de DBA.
GRANT rol_esquema TO MD_OWNER;


-- ============================================================
-- 5. CREACIÓN DEL USUARIO ADMINISTRADOR (DBA) DEL PROYECTO
-- ============================================================

-- ------------------------------------------------------------
-- bryan administrará el proyecto (usuarios, roles, tablespaces)
-- de aquí en adelante, sin depender de SYSTEM.
--
-- Su propio esquema (bryan) no almacenará las tablas del
-- proyecto; esas siguen viviendo en MD_OWNER.
-- ------------------------------------------------------------

CREATE USER bryan
IDENTIFIED BY "Bryan_P4ss!"
DEFAULT TABLESPACE TS_MD_DATOS
TEMPORARY TABLESPACE TEMP
QUOTA 500M ON TS_MD_DATOS;

-- bryan recibe el rol de DBA (administración), no el de esquema.
GRANT rol_dba TO bryan;


-- ============================================================
-- 6. CREACIÓN DEL USUARIO DE APLICACIÓN
-- ============================================================

-- ------------------------------------------------------------
-- app_service será utilizado por la aplicación.
--
-- No se le asigna una cuota sobre TS_MD_DATOS porque
-- inicialmente no será propietario de tablas: solo consulta y
-- modifica datos en las tablas de MD_OWNER.
-- ------------------------------------------------------------

CREATE USER app_service
IDENTIFIED BY "S3rv1c10!"
DEFAULT TABLESPACE TS_MD_DATOS
TEMPORARY TABLESPACE TEMP;

GRANT rol_aplicacion TO app_service;


-- ============================================================
-- 7. PERMISOS CRUD PARA LA APLICACIÓN SOBRE MD_OWNER
-- ============================================================

-- ------------------------------------------------------------
-- Como las tablas pertenecen a MD_OWNER, los privilegios sobre
-- ellas deben otorgarse explícitamente a rol_aplicacion.
--
-- Se aplicará una vez creadas las tablas, por ejemplo:
--
-- GRANT SELECT, INSERT, UPDATE, DELETE
-- ON MD_OWNER.NOMBRE_TABLA
-- TO rol_aplicacion;

-- El script ya esta creado y se llama: GRANTS_USR_APP.sql
-- ------------------------------------------------------------


-- ============================================================
-- FIN DE LA CONFIGURACIÓN INICIAL DE ORACLE
-- ============================================================