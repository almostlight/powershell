#Requires -Version 5.1
<#
NPPPowershell Installation Script for Notepad++
Automates installation of autocomplete, syntax highlighting, and RunMe plugin.
Source: https://github.com/Cmohan/NPPPowershell
#>

param(
    [switch]$Portable,
    [string]$NotepadPath
)

$ErrorActionPreference = 'Stop'
$AutomationPath = "C:\Users\Public\Automation\NPPPowershell"

if (-not (Test-Path $AutomationPath)) {
    New-Item -Path $AutomationPath -ItemType Directory -Force | Out-Null
}

$LogPath = Join-Path $AutomationPath "install.log"

# ---------------- Logging ----------------

function Write-Log {
    param(
        [string]$Message,
        [string]$Type = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Type] $Message"

    $color = switch ($Type) {
        "SUCCESS" { "Green" }
        "ERROR"   { "Red" }
        "WARNING" { "Yellow" }
        default   { "Cyan" }
    }

    Write-Host $logMessage -ForegroundColor $color
    Add-Content -Path $LogPath -Value $logMessage
}

# ---------------- Helpers ----------------

function Test-NotepadRunning {
    $proc = Get-Process -Name "notepad++" -ErrorAction SilentlyContinue
    if ($proc) {
        Write-Log "Notepad++ is currently running" "WARNING"
        $response = Read-Host "Close it now? (Y/N)"
        if ($response -match "^[Yy]$") {
            $proc | Stop-Process -Force
            Start-Sleep -Seconds 2
            Write-Log "Notepad++ closed" "SUCCESS"
        } else {
            Write-Log "Please close Notepad++ manually before continuing" "WARNING"
            return $true
        }
    }
    return $false
}

function Get-NotepadPlusPlusPath {
    Write-Log "Detecting Notepad++ installation..." "INFO"

    if ($NotepadPath -and (Test-Path (Join-Path $NotepadPath "notepad++.exe"))) {
        Write-Log "Using custom path: $NotepadPath" "SUCCESS"
        return $NotepadPath
    }

    $common = @(
        "$env:ProgramFiles\Notepad++",
        "$env:ProgramFiles(x86)\Notepad++",
        "$env:LOCALAPPDATA\Programs\Notepad++",
        "$env:ProgramData\Notepad++"
    )

    foreach ($p in $common) {
        if (Test-Path (Join-Path $p "notepad++.exe")) {
            Write-Log "Found Notepad++ at: $p" "SUCCESS"
            return $p
        }
    }

    $reg = Get-ItemProperty -Path "HKLM:\SOFTWARE\Notepad++" -ErrorAction SilentlyContinue
    if ($reg) {
        $regPath = $reg.'(default)'
        if ($regPath -and (Test-Path (Join-Path $regPath "notepad++.exe"))) {
            Write-Log "Found Notepad++ via registry: $regPath" "SUCCESS"
            return $regPath
        }
    }

    throw "Notepad++ installation not found. Use -NotepadPath to specify manually."
}

function Get-ConfigPath {
    param([string]$NppPath)

    if ($Portable -or (Test-Path (Join-Path $NppPath "plugins"))) {
        Write-Log "Using portable configuration" "INFO"
        return $NppPath
    }

    $cfg = Join-Path $env:APPDATA "Notepad++"
    Write-Log "Using standard configuration: $cfg" "INFO"
    return $cfg
}

function Backup-File {
    param([string]$FilePath)

    if (Test-Path $FilePath) {
        $backup = "$FilePath.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Copy-Item $FilePath $backup -Force
        Write-Log "Backed up: $backup" "INFO"
        return $backup
    }
}

function Get-NPPPowershellRepo {
    $temp = Join-Path $env:TEMP "NPPPowershell"
    $zip  = Join-Path $env:TEMP "NPPPowershell.zip"
    $url  = "https://github.com/Cmohan/NPPPowershell/archive/refs/heads/master.zip"

    Write-Log "Downloading repository..." "INFO"

    if (Test-Path $temp) { Remove-Item $temp -Recurse -Force }
    if (Test-Path $zip)  { Remove-Item $zip -Force }

    Invoke-WebRequest -Uri $url -OutFile $zip
    Expand-Archive -Path $zip -DestinationPath $temp -Force

    $extracted = Join-Path $temp "NPPPowershell-master"
    if (-not (Test-Path $extracted)) {
        throw "Repository extraction failed"
    }

    Write-Log "Repository ready" "SUCCESS"
    return $extracted
}

function Install-AutoComplete {
    param($RepoPath, $ConfigPath)

    Write-Log "Installing autocomplete..." "INFO"

    $destDir = Join-Path $ConfigPath "autoCompletion"
    if (-not (Test-Path $destDir)) { New-Item -Path $destDir -ItemType Directory -Force | Out-Null }

    $src = Join-Path $RepoPath "AutoComplete\powershell.xml"
    $dst = Join-Path $destDir "powershell.xml"

    if (Test-Path $src) {
        Backup-File $dst
        Copy-Item $src $dst -Force
        Write-Log "Autocomplete installed" "SUCCESS"
    } else {
        Write-Log "Autocomplete file missing in repo" "WARNING"
    }
}

function Install-Configuration {
    param($RepoPath, $ConfigPath)

    Write-Log "Installing syntax highlighting..." "INFO"

    $src = Join-Path $RepoPath "ConfigurationFiles\langs.xml"
    $dst = Join-Path $ConfigPath "langs.xml"

    if (Test-Path $src) {
        Backup-File $dst
        Copy-Item $src $dst -Force
        Write-Log "Syntax highlighting installed" "SUCCESS"
    } else {
        Write-Log "langs.xml missing in repo" "WARNING"
    }
}

function Install-RunMePlugin {
    param($RepoPath, $ConfigPath)

    Write-Log "Installing RunMe plugin..." "INFO"

    $pluginDir = Join-Path $ConfigPath "plugins\RunMe"
    if (-not (Test-Path $pluginDir)) { New-Item -Path $pluginDir -ItemType Directory -Force | Out-Null }

    $dll = Get-ChildItem -Path (Join-Path $RepoPath "Plugins") -Recurse -Filter "RunMe.dll" | Select-Object -First 1

    if ($dll) {
        Copy-Item $dll.FullName (Join-Path $pluginDir "RunMe.dll") -Force
        Write-Log "RunMe installed" "SUCCESS"
    } else {
        Write-Log "RunMe plugin not found (optional)" "WARNING"
    }
}

# ---------------- Main ----------------

Write-Log "=== Starting NPPPowershell Installation ===" "INFO"

try {
    $wasRunning = Test-NotepadRunning
    $nppPath    = Get-NotepadPlusPlusPath
    $configPath = Get-ConfigPath $nppPath

    if (-not (Test-Path $configPath)) {
        New-Item -Path $configPath -ItemType Directory -Force | Out-Null
        Write-Log "Created config directory: $configPath" "INFO"
    }

    $repo = Get-NPPPowershellRepo

    Install-AutoComplete  $repo $configPath
    Install-Configuration $repo $configPath
    Install-RunMePlugin   $repo $configPath

    Remove-Item (Join-Path $env:TEMP "NPPPowershell") -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $env:TEMP "NPPPowershell.zip") -Force -ErrorAction SilentlyContinue

    Write-Log "Temporary files cleaned" "INFO"
    Write-Log "=== Installation Complete! ===" "SUCCESS"

} catch {
    Write-Log "Installation failed: $($_.Exception.Message)" "ERROR"

    if ($_.ScriptStackTrace) {
        Add-Content -Path $LogPath -Value @"
Stack Trace:
$($_.ScriptStackTrace)
"@
    }

    exit 1
}
