#!/usr/bin/env bash
# Paso 4: demuestra la replicación asíncrona (tarda poco más de 1 minuto).
source "$(dirname "$0")/lib.sh"
msh --file /docker/3d_DEMOSTRACION_ASINCRONA_DOCKER.js
