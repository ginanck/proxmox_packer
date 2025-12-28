# ===============================
# Install Python for Automation
# ===============================

$PythonVersion = "3.12.8"
$PythonInstaller = "python-$PythonVersion-amd64.exe"
$PythonUrl = "https://www.python.org/ftp/python/$PythonVersion/$PythonInstaller"
$PythonInstallPath = "C:\Python312"
$LogFile = "C:\python-install.log"

$ErrorActionPreference = "Stop"

function Log {
    param($Msg)
    $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Msg
    Write-Host $line
    Add-Content $LogFile $line
}

Log "Starting Python $PythonVersion installation"

# -------------------------------
# Check real Python installation
# -------------------------------
$pythonExe = "$PythonInstallPath\python.exe"

if (Test-Path $pythonExe) {
    $ver = & $pythonExe --version 2>&1
    Log "Python already installed: $ver"
} else {

    # -------------------------------
    # Download installer
    # -------------------------------
    Log "Downloading Python installer"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $PythonUrl -OutFile $PythonInstaller

    # -------------------------------
    # Install silently
    # -------------------------------
    Log "Installing Python"

    $installArgs = @(
        "/quiet",
        "InstallAllUsers=1",
        "Include_pip=1",
        "Include_test=0",
        "Include_doc=0",
        "TargetDir=$PythonInstallPath"
    )

    $proc = Start-Process `
        -FilePath $PythonInstaller `
        -ArgumentList $installArgs `
        -Wait `
        -NoNewWindow `
        -PassThru

    if ($proc.ExitCode -ne 0) {
        throw "Installer failed with exit code $($proc.ExitCode)"
    }

    Start-Sleep 3

    if (-not (Test-Path $pythonExe)) {
        throw "Python executable not found after install"
    }

    $ver = & $pythonExe --version 2>&1
    Log "Python installed successfully: $ver"
}

# -------------------------------
# Ensure Python is in SYSTEM PATH
# -------------------------------
Log "Ensuring Python is in system PATH"

$pathsToAdd = @(
    $PythonInstallPath,
    "$PythonInstallPath\Scripts"
)

$machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")

foreach ($p in $pathsToAdd) {
    if ($machinePath -notmatch [regex]::Escape($p)) {
        $machinePath = "$machinePath;$p"
        Log "Added to PATH: $p"
    } else {
        Log "PATH already contains: $p"
    }
}

[Environment]::SetEnvironmentVariable("Path", $machinePath, "Machine")

# Refresh PATH for current session
$env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine")

# -------------------------------
# pip & Ansible support
# -------------------------------
Log "Upgrading pip"
& $pythonExe -m pip install --upgrade pip --quiet

Log "Installing pywinrm"
& $pythonExe -m pip install pywinrm --quiet

# -------------------------------
# Cleanup
# -------------------------------
Remove-Item $PythonInstaller -Force -ErrorAction SilentlyContinue

Log "Python installation complete"
Log "Python is available globally:"
Log "  python"
Log "  pip"
