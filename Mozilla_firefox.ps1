$logPath = "C:\ProgramData\ESETLogs"
$logFile = "$logPath\firefox_update.log"

# Create log folder
if (!(Test-Path $logPath)) {
    New-Item -ItemType Directory -Path $logPath -Force | Out-Null
}

function Log {
    param ($msg)
    Add-Content -Path $logFile -Value "$(Get-Date -Format 'MM/dd/yyyy HH:mm:ss') - $msg"
}

$hostname = $env:COMPUTERNAME
Log "===== [$hostname] Firefox Update Check Start ====="

# Detect Firefox installation
$paths = @(
    "$env:ProgramFiles\Mozilla Firefox\firefox.exe",
    "${env:ProgramFiles(x86)}\Mozilla Firefox\firefox.exe",
    "$env:LOCALAPPDATA\Mozilla Firefox\firefox.exe"
)

# First check standard locations
$ffPath = $paths | Where-Object { Test-Path $_ } | Select-Object -First 1

# Check all user profiles if not found
if (!$ffPath) {
    $ffPath = Get-ChildItem "C:\Users\*\AppData\Local\Mozilla Firefox\firefox.exe" -ErrorAction SilentlyContinue |
    Select-Object -First 1 -ExpandProperty FullName
}

if ($ffPath) {

    Log "Firefox found at: $ffPath"

    try {
        $installed = (Get-Item $ffPath).VersionInfo.ProductVersion
        Log "Installed Version: $installed"
    }
    catch {
        Log "ERROR: Unable to read installed version"
        exit 1
    }

    # Get latest Firefox version
    try {
        $json = Invoke-WebRequest "https://product-details.mozilla.org/1.0/firefox_versions.json" -UseBasicParsing | ConvertFrom-Json
        $latest = $json.LATEST_FIREFOX_VERSION
        Log "Latest Version: $latest"
    }
    catch {
        Log "ERROR: Unable to fetch latest version"
        exit 2
    }

    # Compare versions
    try {
        if ([version]$installed -ge [version]$latest) {
            Log "STATUS: UP-TO-DATE"
            exit 0
        }
    }
    catch {
        Log "WARNING: Version comparison failed, continuing update"
    }

    Log "STATUS: UPDATE AVAILABLE - Triggering update"

    # Stop Firefox
    Stop-Process -Name firefox -Force -ErrorAction SilentlyContinue
    Log "Firefox stopped"

    # Find updater.exe
    $ffFolder = Split-Path $ffPath
    $updater = Join-Path $ffFolder "updater.exe"

    if (Test-Path $updater) {

        try {
            Start-Process $updater -ArgumentList "/S" -Wait -WindowStyle Hidden
            Log "Updater executed"
        }
        catch {
            Log "ERROR: Failed to execute updater"
            exit 1
        }

        Start-Sleep -Seconds 60

        # Verify updated version
        try {
            $updated = (Get-Item $ffPath).VersionInfo.ProductVersion
            Log "After Version: $updated"

            if ([version]$updated -gt [version]$installed) {
                Log "STATUS: UPDATED SUCCESSFULLY"
                exit 0
            }
            elseif ([version]$updated -ge [version]$latest) {
                Log "STATUS: UPDATED TO LATEST"
                exit 0
            }
            else {
                Log "STATUS: UPDATE FAILED OR BLOCKED"
                exit 1
            }
        }
        catch {
            Log "ERROR: Unable to verify updated version"
            exit 1
        }
    }
    else {
        Log "ERROR: updater.exe not found"
        exit 1
    }
}
else {
    Log "Firefox not found"
    exit 1
}