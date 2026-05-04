$logPath = "C:\ProgramData\ESETLogs"
$logFile = "$logPath\firefox_update.log"

# Create log folder
if (!(Test-Path $logPath)) {
    New-Item -ItemType Directory -Path $logPath -Force | Out-Null
}

function Log {
    param ($msg)
    Add-Content -Path $logFile -Value "$(Get-Date) - $msg"
}

$hostname = $env:COMPUTERNAME
Log "===== [$hostname] Firefox Update Check Start ====="

# Detect Firefox path
$paths = @(
    "$env:ProgramFiles\Mozilla Firefox\firefox.exe",
    "$env:ProgramFiles(x86)\Mozilla Firefox\firefox.exe",
    "$env:LOCALAPPDATA\Mozilla Firefox\firefox.exe"
)

$ffPath = $paths | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($ffPath) {

    $installed = (Get-Item $ffPath).VersionInfo.ProductVersion
    Log "Installed Version: $installed"

    try {
        $json = Invoke-WebRequest "https://product-details.mozilla.org/1.0/firefox_versions.json" -UseBasicParsing | ConvertFrom-Json
        $latest = $json.LATEST_FIREFOX_VERSION
        Log "Latest Version: $latest"
    }
    catch {
        Log "ERROR: Unable to fetch latest version"
        exit 2
    }

    if ($installed -eq $latest) {
        Log "STATUS: UP-TO-DATE"
        exit 0
    }
    else {
        Log "STATUS: UPDATE AVAILABLE - Triggering update"

        # Stop Firefox
        Stop-Process -Name firefox -Force -ErrorAction SilentlyContinue
        Log "Firefox stopped"

        # Trigger update
        Start-Process $ffPath -ArgumentList "-silent" -WindowStyle Hidden
        Log "Update triggered"

        Start-Sleep -Seconds 60

        # Restart Firefox
        Stop-Process -Name firefox -Force -ErrorAction SilentlyContinue
        Start-Process $ffPath -WindowStyle Hidden
        Log "Firefox restarted"

        Start-Sleep -Seconds 5

        # Check version again
        $updated = (Get-Item $ffPath).VersionInfo.ProductVersion
        Log "After Version: $updated"

        if ($updated -ne $installed) {
            Log "STATUS: UPDATED SUCCESSFULLY"
            exit 0
        }
        else {
            Log "STATUS: UPDATE FAILED OR BLOCKED"
            exit 1
        }
    }
}
else {
    Log "Firefox not found"
    exit 1
}