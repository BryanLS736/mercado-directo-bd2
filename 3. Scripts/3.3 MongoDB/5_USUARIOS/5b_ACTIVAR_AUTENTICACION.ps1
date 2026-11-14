# =====================================================================
# 5b_ACTIVAR_AUTENTICACION.ps1  -  Mercado Directo (MongoDB)
# Activa el control de acceso en el replica set:
#   1) genera el keyFile (clave compartida con la que los nodos se
#      autentican entre sí; es obligatoria al activar usuarios en un
#      replica set),
#   2) apaga los 3 nodos y
#   3) los vuelve a iniciar exigiendo autenticación.
# Antes debe haberse ejecutado 5a_CREAR_ADMIN.js.
# Uso:   .\5b_ACTIVAR_AUTENTICACION.ps1
# =====================================================================
$base = "C:\MongoDB\rs"
$keyfile = "$base\keyfile"

# 1) keyFile (756 bytes aleatorios en base64; MongoDB acepta hasta 1024 caracteres)
if (-not (Test-Path $keyfile)) {
    $bytes = New-Object byte[] 756
    [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    [IO.File]::WriteAllText($keyfile, [Convert]::ToBase64String($bytes))
    # Solo el usuario actual puede leer el archivo
    icacls $keyfile /inheritance:r /grant:r "$($env:USERNAME):(R)" | Out-Null
    Write-Host "keyFile creado en $keyfile" -ForegroundColor Cyan
}

# 2) apagar los nodos (todavía sin autenticación, se puede apagar sin credenciales)
foreach ($puerto in 27019, 27018, 27017) {
    mongosh --quiet --port $puerto --eval "db.getSiblingDB('admin').shutdownServer({force:true})" 2>$null | Out-Null
}
Start-Sleep -Seconds 5

# 3) iniciar los nodos con keyFile (esto activa la autenticación)
& "$PSScriptRoot\..\3_REPLICACION\3b_INICIAR_NODOS.ps1" -ConAuth
Write-Host "`nAutenticación activada. Siguiente paso:" -ForegroundColor Green
Write-Host '  mongosh "mongodb://localhost:27017/?replicaSet=rs_mercado" -u dba_mongo --authenticationDatabase admin --file 5c_CREAR_USUARIOS_Y_ROLES.js'
