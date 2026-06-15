# Build release APK with current PC Wi-Fi IP as API host.
# Usage: .\scripts\build-apk.ps1
# Cloud API: .\scripts\build-apk.ps1 -ProductionUrl "https://your-api.vercel.app/api"

param([string]$ProductionUrl = "")

if ($ProductionUrl) {
    flutter build apk --release --dart-define=PRODUCTION_API_URL=$ProductionUrl
    exit $LASTEXITCODE
}

$ip = Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object {
        $_.IPAddress -notlike '127.*' -and
        $_.PrefixOrigin -ne 'WellKnown' -and
        $_.InterfaceAlias -match 'Wi-?Fi|Wireless|Ethernet' -and
        $_.IPAddress -notlike '172.*' -and
        $_.IPAddress -notlike '192.168.56.*'
    } |
    Sort-Object { if ($_.InterfaceAlias -match 'Wi') { 0 } else { 1 } } |
    Select-Object -First 1 -ExpandProperty IPAddress

if (-not $ip) {
    Write-Host "Could not detect IP. Use: flutter build apk --dart-define=API_HOST=YOUR_IP"
    exit 1
}

Write-Host "Building APK for API: http://${ip}:3000/api"
flutter build apk --release --dart-define=API_HOST=$ip
