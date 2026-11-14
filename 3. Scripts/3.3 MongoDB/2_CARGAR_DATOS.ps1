# =====================================================================
# 2_CARGAR_DATOS.ps1  -  Mercado Directo (MongoDB)
# Carga los 4 archivos JSON de la carpeta "datos" con mongoimport.
#
# Requisitos: MongoDB Database Tools instalado (mongoimport en el PATH) y
# las colecciones ya creadas con 1_CREAR_COLECCIONES.js (para que se aplique
# el validador a cada documento).
#
# Uso (PowerShell, desde esta carpeta):
#     .\2_CARGAR_DATOS.ps1
#     .\2_CARGAR_DATOS.ps1 -Uri "mongodb://localhost:27017/?replicaSet=rs_mercado" -Usuario app_admin
# Si se indica -Usuario, mongoimport pedirá la contraseña (no queda escrita).
# =====================================================================
param(
  [string]$Uri = "mongodb://localhost:27017",
  [string]$Usuario = ""
)

$bd = "mercado_nosql"
$colecciones = "seguimiento_ruta", "calificaciones", "incidencias", "perfil_agricultor"

foreach ($c in $colecciones) {
    Write-Host "Cargando $c ..." -ForegroundColor Cyan
    $argumentos = @("--uri", $Uri, "--db", $bd, "--collection", $c,
              "--file", "datos\$c.jsonl", "--numInsertionWorkers", "4")
    if ($Usuario -ne "") { $argumentos += @("--username", $Usuario, "--authenticationDatabase", "admin") }
    & mongoimport @argumentos
    if ($LASTEXITCODE -ne 0) { Write-Host "Error cargando $c" -ForegroundColor Red; exit 1 }
}
Write-Host "`nCarga terminada. Verifiquen los conteos (deben ser 6446, 33077, 6625 y 2331):" -ForegroundColor Green
Write-Host '  mongosh --eval "db.getSiblingDB(''mercado_nosql'').getCollectionNames().forEach(c => print(c + '': '' + db.getSiblingDB(''mercado_nosql'')[c].countDocuments()))"'
