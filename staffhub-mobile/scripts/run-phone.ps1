# Run Flutter on a physical phone with the correct PC API IP.
# Usage: .\scripts\run-phone.ps1
# USB fallback (no Wi-Fi): .\scripts\run-phone.ps1 -Usb

param([switch]$Usb)

$apiPort = 3000

if ($Usb) {
    Write-Host "USB mode: adb reverse tcp:$apiPort tcp:$apiPort"
    adb reverse tcp:$apiPort tcp:$apiPort
    if ($LASTEXITCODE -ne 0) {
        Write-Host "adb failed. Connect phone via USB and enable USB debugging."
        exit 1
    }
    flutter run --dart-define=API_BASE_URL=http://127.0.0.1:${apiPort}/api
    exit $LASTEXITCODE
}

# Prefer Wi-Fi adapter (skip virtual/WSL adapters)
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
    Write-Host "Could not detect LAN IP. Set manually:"
    Write-Host "  flutter run --dart-define=API_HOST=YOUR_PC_IP"
    exit 1
}

Write-Host "API will be: http://${ip}:${apiPort}/api"
Write-Host "Ensure staffhub-api is running (npm run dev) and phone is on same Wi-Fi."
Write-Host ""

flutter run --dart-define=API_HOST=$ip
