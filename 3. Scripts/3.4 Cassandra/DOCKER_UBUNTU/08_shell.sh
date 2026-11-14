#!/usr/bin/env bash
# Abre cqlsh interactivo (autenticado como administrador) sobre mercado_cassandra.
source "$(dirname "$0")/lib.sh"
cql -t -k mercado_cassandra
