# =====================================================================
# 6b_RESTAURAR_Y_VERIFICAR.ps1  -  Mercado Directo (MongoDB)
# Un respaldo solo sirve si se puede restaurar. Este script restaura el
# respaldo en una base SEPARADA (mercado_restaurada) sin tocar la original
# y comprueba que los datos, índices y validadores sean los mismos.
#
# Requisito: MongoDB Database Tools (mongorestore) y mongosh en el PATH.
# Uso:    .\6b_RESTAURAR_Y_VERIFICAR.ps1 -Respaldo C:\Respaldos\MongoDB\mercado_nosql_20261108_0200
# Pide la contraseña de dba_mongo (necesita permisos de restauración).
# =====================================================================
param(
  [Parameter(Mandatory=$true)][string]$Respaldo,
  [string]$Uri = "mongodb://localhost:27017/?replicaSet=rs_mercado",
  [string]$Usuario = "dba_mongo"
)

Write-Host "Restaurando $Respaldo en mercado_restaurada ..." -ForegroundColor Cyan
mongorestore --uri $Uri --username $Usuario --authenticationDatabase admin --gzip `
             --nsInclude "mercado_nosql.*" --nsFrom "mercado_nosql.*" --nsTo "mercado_restaurada.*" `
             --drop $Respaldo
if ($LASTEXITCODE -ne 0) { Write-Host "La restauración FALLÓ" -ForegroundColor Red; exit 1 }

Write-Host "`nVerificando ..." -ForegroundColor Cyan
mongosh $Uri -u $Usuario --authenticationDatabase admin --file "$PSScriptRoot\6c_VERIFICAR_RESTAURACION.js"

Write-Host "`nSi todo dio OK, pueden eliminar la copia de prueba con:"
Write-Host "  mongosh `"$Uri`" -u $Usuario --authenticationDatabase admin --eval `"db.getSiblingDB('mercado_restaurada').dropDatabase()`""
