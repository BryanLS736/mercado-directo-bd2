#!/usr/bin/env bash
# Paso 3: ejecuta las consultas de negocio.
source "$(dirname "$0")/lib.sh"
cql --request-timeout=120 -f /proyecto/cql/4_CONSULTAS_NEGOCIO.cql
