# =====================================================================
# 6a_RESPALDO.ps1  -  Mercado Directo (MongoDB)
# Respaldo lógico de la base mercado_nosql con mongodump.
#
#  - Lee de un SECUNDARIO (readPreference=secondary): así el respaldo no
#    carga al nodo primario, que sigue atendiendo a la aplicación.
#  - Guarda cada respaldo en una carpeta con fecha y hora, comprimido (gzip).
#  - Conserva solo los últimos N respaldos.
#
# Requisito: MongoDB Database Tools (mongodump en el PATH).
# Uso:    .\6a_RESPALDO.ps1
#         .\6a_RESPALDO.ps1 -Destino D:\Respaldos\Mongo -Conservar 14
# Pide la contraseña de respaldo_mongo (no queda escrita en el archivo).
# =====================================================================
param(
  [string]$Uri = "mongodb://localhost:27017,localhost:27018/?replicaSet=rs_mercado&readPreference=secondary",
  [string]$Usuario = "respaldo_mongo",
  [string]$Destino = "C:\Respaldos\MongoDB",
  [int]$Conservar = 7
)

$sello = Get-Date -Format "yyyyMMdd_HHmm"
$ruta = Join-Path $Destino "mercado_nosql_$sello"
New-Item -ItemType Directory -Force -Path $ruta | Out-Null

Write-Host "Respaldando mercado_nosql en $ruta ..." -ForegroundColor Cyan
mongodump --uri $Uri --username $Usuario --authenticationDatabase admin `
          --db mercado_nosql --gzip --out $ruta
if ($LASTEXITCODE -ne 0) { Write-Host "El respaldo FALLÓ" -ForegroundColor Red; exit 1 }

# Resumen del respaldo
$tam = (Get-ChildItem $ruta -Recurse -File | Measure-Object Length -Sum).Sum / 1MB
Write-Host ("Respaldo terminado: {0:N1} MB" -f $tam) -ForegroundColor Green
Get-ChildItem "$ruta\mercado_nosql" -File | Select-Object Name, @{n='KB';e={[int]($_.Length/1KB)}}

# Conservar solo los últimos N respaldos
Get-ChildItem $Destino -Directory -Filter "mercado_nosql_*" |
    Sort-Object Name -Descending | Select-Object -Skip $Conservar |
    ForEach-Object { Write-Host "Eliminando respaldo antiguo $($_.Name)"; Remove-Item $_.FullName -Recurse -Force }
