-- =========================================================
-- CREACIÓN DE LAS TABLAS EN
-- -> ESQUEMA: mercado
-- -> TABLESPACE: ts_md_datos
-- =========================================================


-- =========================================================
-- 1. DEPARTAMENTO
-- =========================================================

CREATE TABLE mercado.departamento (
    departamento_id SERIAL PRIMARY KEY,
    nombre VARCHAR(80) NOT NULL,

    CONSTRAINT uq_departamento_nombre
        UNIQUE (nombre)
) TABLESPACE ts_md_datos;


-- =========================================================
-- 2. PROVINCIA
-- =========================================================

CREATE TABLE mercado.provincia (
    provincia_id SERIAL PRIMARY KEY,
    departamento_id INT NOT NULL,
    nombre VARCHAR(80) NOT NULL,

    CONSTRAINT fk_provincia_departamento
        FOREIGN KEY (departamento_id)
        REFERENCES mercado.departamento (departamento_id),

    CONSTRAINT uq_provincia_nombre
        UNIQUE (departamento_id, nombre)
) TABLESPACE ts_md_datos;


-- =========================================================
-- 3. DISTRITO
-- =========================================================

CREATE TABLE mercado.distrito (
    distrito_id SERIAL PRIMARY KEY,
    provincia_id INT NOT NULL,
    nombre VARCHAR(80) NOT NULL,

    CONSTRAINT fk_distrito_provincia
        FOREIGN KEY (provincia_id)
        REFERENCES mercado.provincia (provincia_id),

    CONSTRAINT uq_distrito_nombre
        UNIQUE (provincia_id, nombre)
) TABLESPACE ts_md_datos;


-- =========================================================
-- 4. AGRICULTOR
-- =========================================================

CREATE TABLE mercado.agricultor (
    agricultor_id SERIAL PRIMARY KEY,
    tipo_documento VARCHAR(3) NOT NULL,
    numero_documento VARCHAR(20) NOT NULL,
    nombres VARCHAR(100) NOT NULL,
    apellidos VARCHAR(100) NOT NULL,
    telefono VARCHAR(20) NOT NULL,
    correo_contacto VARCHAR(150),
    fecha_registro TIMESTAMP NOT NULL,

    CONSTRAINT uq_agricultor_documento
        UNIQUE (tipo_documento, numero_documento),

    CONSTRAINT ck_agricultor_tipo_documento
        CHECK (tipo_documento IN ('DNI', 'CE'))
) TABLESPACE ts_md_datos;


-- =========================================================
-- 5. UBICACION AGRICULTOR
-- =========================================================

CREATE TABLE mercado.ubicacion_agricultor (
    ubicacion_agricultor_id SERIAL PRIMARY KEY,
    agricultor_id INT NOT NULL,
    direccion VARCHAR(250) NOT NULL,
    distrito_id INT NOT NULL,
    referencia VARCHAR(250),
    es_principal BOOLEAN NOT NULL,

    CONSTRAINT fk_ubicacion_agricultor
        FOREIGN KEY (agricultor_id)
        REFERENCES mercado.agricultor (agricultor_id),

    CONSTRAINT fk_ubicacion_distrito
        FOREIGN KEY (distrito_id)
        REFERENCES mercado.distrito (distrito_id)
) TABLESPACE ts_md_datos;


-- =========================================================
-- 6. CATEGORIA
-- =========================================================

CREATE TABLE mercado.categoria (
    categoria_id SERIAL PRIMARY KEY,
    nombre VARCHAR(80) NOT NULL,
    descripcion VARCHAR(200),

    CONSTRAINT uq_categoria_nombre
        UNIQUE (nombre)
) TABLESPACE ts_md_datos;


-- =========================================================
-- 7. PRODUCTO
-- =========================================================

CREATE TABLE mercado.producto (
    producto_id SERIAL PRIMARY KEY,
    categoria_id INT NOT NULL,
    unidad_medida VARCHAR(2) NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    descripcion VARCHAR(250),

    CONSTRAINT fk_producto_categoria
        FOREIGN KEY (categoria_id)
        REFERENCES mercado.categoria (categoria_id),

    CONSTRAINT ck_producto_unidad_medida
        CHECK (unidad_medida = 'KG')
) TABLESPACE ts_md_datos;


-- =========================================================
-- 8. OFERTA COSECHA
-- =========================================================

CREATE TABLE mercado.oferta_cosecha (
    oferta_id SERIAL PRIMARY KEY,
    ubicacion_agricultor_id INT NOT NULL,
    producto_id INT NOT NULL,
    fecha_publicacion TIMESTAMP NOT NULL,
    fecha_cosecha_estimada DATE NOT NULL,
    fecha_disponibilidad DATE NOT NULL,
    precio_kg NUMERIC(12,2) NOT NULL,
    observaciones VARCHAR(300),

    CONSTRAINT fk_oferta_ubicacion
        FOREIGN KEY (ubicacion_agricultor_id)
        REFERENCES mercado.ubicacion_agricultor (ubicacion_agricultor_id),

    CONSTRAINT fk_oferta_producto
        FOREIGN KEY (producto_id)
        REFERENCES mercado.producto (producto_id)
) TABLESPACE ts_md_datos;


-- =========================================================
-- 9. CLIENTE CONSUMIDOR
-- =========================================================

CREATE TABLE mercado.cliente_consumidor (
    cliente_id SERIAL PRIMARY KEY,
    tipo_cliente VARCHAR(30) NOT NULL,
    tipo_documento VARCHAR(10) NOT NULL,
    numero_documento VARCHAR(20) NOT NULL,
    nombre_razon_social VARCHAR(150) NOT NULL,
    telefono VARCHAR(20) NOT NULL,
    correo_contacto VARCHAR(150),
    fecha_registro TIMESTAMP NOT NULL,

    CONSTRAINT uq_cliente_documento
        UNIQUE (tipo_documento, numero_documento),

    CONSTRAINT ck_cliente_tipo
        CHECK (tipo_cliente IN ('FAMILIA', 'RESTAURANTE', 'MAYORISTA')),

    CONSTRAINT ck_cliente_tipo_documento
        CHECK (tipo_documento IN ('DNI', 'RUC'))
) TABLESPACE ts_md_datos;


-- =========================================================
-- 10. DIRECCION CLIENTE
-- =========================================================

CREATE TABLE mercado.direccion_cliente (
    direccion_id SERIAL PRIMARY KEY,
    cliente_id INT NOT NULL,
    direccion VARCHAR(250) NOT NULL,
    distrito_id INT NOT NULL,
    referencia VARCHAR(250),
    es_principal BOOLEAN NOT NULL,

    CONSTRAINT fk_direccion_cliente
        FOREIGN KEY (cliente_id)
        REFERENCES mercado.cliente_consumidor (cliente_id),

    CONSTRAINT fk_direccion_distrito
        FOREIGN KEY (distrito_id)
        REFERENCES mercado.distrito (distrito_id)
) TABLESPACE ts_md_datos;


-- =========================================================
-- 11. PEDIDO
-- =========================================================

CREATE TABLE mercado.pedido (
    pedido_id SERIAL PRIMARY KEY,
    cliente_id INT NOT NULL,
    direccion_id INT NOT NULL,
    fecha_pedido TIMESTAMP NOT NULL,
    fecha_entrega_solicitada DATE NOT NULL,
    costo_envio NUMERIC(12,2) NOT NULL,
    observaciones VARCHAR(300),

    CONSTRAINT fk_pedido_cliente
        FOREIGN KEY (cliente_id)
        REFERENCES mercado.cliente_consumidor (cliente_id),

    CONSTRAINT fk_pedido_direccion
        FOREIGN KEY (direccion_id)
        REFERENCES mercado.direccion_cliente (direccion_id)
) TABLESPACE ts_md_datos;


-- =========================================================
-- 12. DETALLE PEDIDO
-- =========================================================

CREATE TABLE mercado.detalle_pedido (
    detalle_pedido_id SERIAL PRIMARY KEY,
    pedido_id INT NOT NULL,
    oferta_id INT NOT NULL,
    cantidad_kg NUMERIC(12,3) NOT NULL,
    precio_acordado NUMERIC(12,2) NOT NULL,

    CONSTRAINT fk_detalle_pedido
        FOREIGN KEY (pedido_id)
        REFERENCES mercado.pedido (pedido_id),

    CONSTRAINT fk_detalle_oferta
        FOREIGN KEY (oferta_id)
        REFERENCES mercado.oferta_cosecha (oferta_id)
) TABLESPACE ts_md_datos;


-- =========================================================
-- 13. PEDIDO AGRUPADO
-- =========================================================

CREATE TABLE mercado.pedido_agrupado (
    pedido_agrupado_id SERIAL PRIMARY KEY,
    fecha_agrupacion TIMESTAMP NOT NULL,
    fecha_entrega_programada DATE NOT NULL,
    observaciones VARCHAR(300)
) TABLESPACE ts_md_datos;


-- =========================================================
-- 14. DETALLE PEDIDO AGRUPADO
-- =========================================================

CREATE TABLE mercado.detalle_pedido_agrupado (
    detalle_pedido_agrupado_id SERIAL PRIMARY KEY,
    pedido_agrupado_id INT NOT NULL,
    detalle_pedido_id INT NOT NULL,
    cantidad_agrupada NUMERIC(12,3) NOT NULL,

    CONSTRAINT fk_detalle_agrupado_pedido
        FOREIGN KEY (pedido_agrupado_id)
        REFERENCES mercado.pedido_agrupado (pedido_agrupado_id),

    CONSTRAINT fk_detalle_agrupado_detalle
        FOREIGN KEY (detalle_pedido_id)
        REFERENCES mercado.detalle_pedido (detalle_pedido_id),

    CONSTRAINT uq_pedido_agrupado_detalle
        UNIQUE (pedido_agrupado_id, detalle_pedido_id)
) TABLESPACE ts_md_datos;

-- ============================================================
-- MERCADO DIRECTO
-- CREACIÓN DE ÍNDICES
-- ============================================================
-- Los índices se almacenan en el tablespace:
--     ts_md_indices
--
-- PostgreSQL ya crea automáticamente índices para:
--     PRIMARY KEY
--     UNIQUE
--
-- Por ello, aquí solo se crean índices adicionales
-- para las claves foráneas y columnas de consulta frecuente.
-- ============================================================


-- ============================================================
-- 1. ÍNDICES DE AGRICULTORES
-- ============================================================
 
-- Permite consultar rápidamente las ubicaciones
-- registradas para cada agricultor.
CREATE INDEX idx_ubicacion_agricultor_agricultor
ON mercado.ubicacion_agricultor (agricultor_id)
TABLESPACE ts_md_indices;
 
 
-- Permite consultar las ubicaciones según distrito.
CREATE INDEX idx_ubicacion_agricultor_distrito
ON mercado.ubicacion_agricultor (distrito_id)
TABLESPACE ts_md_indices;
 
 
-- ============================================================
-- 2. ÍNDICES DE PRODUCTOS
-- ============================================================
 
-- Permite consultar rápidamente los productos
-- pertenecientes a una categoría.
CREATE INDEX idx_producto_categoria
ON mercado.producto (categoria_id)
TABLESPACE ts_md_indices;
 
 
-- ============================================================
-- 3. ÍNDICES DE OFERTAS DE COSECHA
-- ============================================================
 
-- Permite consultar las ofertas asociadas
-- a una ubicación de agricultor.
CREATE INDEX idx_oferta_ubicacion
ON mercado.oferta_cosecha (ubicacion_agricultor_id)
TABLESPACE ts_md_indices;
 
 
-- Permite consultar las ofertas según producto.
CREATE INDEX idx_oferta_producto
ON mercado.oferta_cosecha (producto_id)
TABLESPACE ts_md_indices;
 
 
-- Permite buscar ofertas según fecha de disponibilidad.
CREATE INDEX idx_oferta_fecha_disponibilidad
ON mercado.oferta_cosecha (fecha_disponibilidad)
TABLESPACE ts_md_indices;
 
 
-- ============================================================
-- 4. ÍNDICES DE CLIENTES
-- ============================================================
 
-- Permite consultar rápidamente las direcciones
-- pertenecientes a un cliente.
CREATE INDEX idx_direccion_cliente_cliente
ON mercado.direccion_cliente (cliente_id)
TABLESPACE ts_md_indices;
 
 
-- Permite consultar las direcciones según distrito.
CREATE INDEX idx_direccion_cliente_distrito
ON mercado.direccion_cliente (distrito_id)
TABLESPACE ts_md_indices;
 
 
-- ============================================================
-- 5. ÍNDICES DE PEDIDOS
-- ============================================================
 
-- Permite consultar rápidamente los pedidos
-- realizados por un cliente.
CREATE INDEX idx_pedido_cliente
ON mercado.pedido (cliente_id)
TABLESPACE ts_md_indices;
 
 
-- Permite consultar los pedidos asociados
-- a una dirección.
CREATE INDEX idx_pedido_direccion
ON mercado.pedido (direccion_id)
TABLESPACE ts_md_indices;
 
 
-- Permite consultar pedidos según la fecha solicitada
-- de entrega.
CREATE INDEX idx_pedido_fecha_entrega
ON mercado.pedido (fecha_entrega_solicitada)
TABLESPACE ts_md_indices;
 
 
-- ============================================================
-- 6. ÍNDICES DE DETALLE DE PEDIDO
-- ============================================================
 
-- Permite consultar rápidamente los detalles
-- pertenecientes a un pedido.
CREATE INDEX idx_detalle_pedido_pedido
ON mercado.detalle_pedido (pedido_id)
TABLESPACE ts_md_indices;
 
 
-- Permite consultar los pedidos que utilizan
-- una determinada oferta de cosecha.
CREATE INDEX idx_detalle_pedido_oferta
ON mercado.detalle_pedido (oferta_id)
TABLESPACE ts_md_indices;
 
 
-- ============================================================
-- 7. ÍNDICES DE PEDIDOS AGRUPADOS
-- ============================================================
 
-- Permite consultar los pedidos agrupados
-- a partir de un detalle de pedido.
-- (Es la segunda columna de la UNIQUE compuesta
--  uq_pedido_agrupado_detalle, por lo que SÍ necesita
--  su propio índice: el índice compuesto no sirve
--  para buscar solo por esta columna).

CREATE INDEX idx_detalle_agrupado_detalle_pedido
ON mercado.detalle_pedido_agrupado (detalle_pedido_id)
TABLESPACE ts_md_indices;
 
 
-- Permite consultar pedidos agrupados
-- según su fecha de entrega programada.

CREATE INDEX idx_pedido_agrupado_fecha_entrega
ON mercado.pedido_agrupado (fecha_entrega_programada)
TABLESPACE ts_md_indices;
 
 
-- ============================================================
-- FIN DE LA CREACIÓN DE ÍNDICES
-- ============================================================

