# =====================================================================
# 3b_INICIAR_NODOS.ps1  -  Mercado Directo (MongoDB)
# Crea las carpetas e inicia los 3 nodos del replica set en este mismo PC:
#     nodo 1 -> puerto 27017  (será el PRIMARIO, prioridad 2)
#     nodo 2 -> puerto 27018  (secundario normal)
#     nodo 3 -> puerto 27019  (secundario oculto con retraso de 60 s)
#
# Requisito: MongoDB Server instalado y "mongod" en el PATH.
# Uso:   .\3b_INICIAR_NODOS.ps1              (sin autenticación)
#        .\3b_INICIAR_NODOS.ps1 -ConAuth     (con usuarios; ver carpeta 5_USUARIOS)
# =====================================================================
param([switch]$ConAuth)

$base = "C:\MongoDB\rs"
foreach ($n in 1..3) {
    New-Item -ItemType Directory -Force -Path "$base\nodo$n\data", "$base\logs" | Out-Null
}

foreach ($n in 1..3) {
    $argumentos = @("--config", "$PSScriptRoot\mongod_nodo$n.cfg")
    # En un replica set, activar la autenticación exige un keyFile compartido por todos los nodos
    if ($ConAuth) { $argumentos += @("--keyFile", "$base\keyfile") }
    Start-Process -FilePath "mongod" -ArgumentList $argumentos -WindowStyle Minimized
    Write-Host "Nodo $n iniciado (puerto $(27016 + $n))" -ForegroundColor Cyan
}
Write-Host "`nEspere unos segundos y ejecute: mongosh --port 27017 --file 3c_INICIAR_REPLICA_SET.js"
