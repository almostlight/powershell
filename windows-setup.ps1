#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Comprehensive Windows system setup and automation script
.DESCRIPTION
    Configures system settings, installs software, and sets up automation environment
#>

param()

$ErrorActionPreference = "Continue"
$AutomationPath = "C:\Users\Public\Automation"
$LogPath = Join-Path $AutomationPath "setup.log"
$DownloadsPath = "$env:USERPROFILE\Downloads"

# Initialize logging
function Write-Log {
    param(
        [string]$Message,
        [string]$Type = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Type] $Message"
    
    $color = switch ($Type) {
        "SUCCESS" { "Green" }
        "ERROR" { "Red" }
        "WARNING" { "Yellow" }
        default { "Cyan" }
    }
    
    Write-Host $logMessage -ForegroundColor $color
    Add-Content -Path $LogPath -Value $logMessage
}

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-LatestGitHubRelease {
    param([string]$Repo, [string]$AssetPattern)
    try {
        $release = Invoke-RestMethod "https://api.github.com/repos/$Repo/releases/latest"
        $asset = $release.assets | Where-Object { $_.name -like $AssetPattern } | Select-Object -First 1
        return $asset.browser_download_url
    } catch {
        throw "Failed to get latest release from $Repo : $_"
    }
}

# Check admin privileges
if (-not (Test-Administrator)) {
    Write-Host "Script must be run as Administrator. Attempting to elevate..." -ForegroundColor Yellow
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

# Create automation directory
try {
    if (-not (Test-Path $AutomationPath)) {
        New-Item -ItemType Directory -Path $AutomationPath -Force | Out-Null
        Write-Log "Created automation directory: $AutomationPath" "SUCCESS"
    } else {
        Write-Log "Automation directory already exists" "INFO"
    }
} catch {
    Write-Log "Failed to create automation directory: $_" "ERROR"
    exit 1
}

Write-Log "=== Windows Automation Setup Started ===" "INFO"
Write-Log "Running with Administrator privileges" "SUCCESS"

# Enable sudo (PowerShell 7.4+ feature)
try {
    Write-Log "Enabling sudo functionality..." "INFO"
    if (Get-Command sudo -ErrorAction SilentlyContinue) {
        Write-Log "Sudo already available" "SUCCESS"
    } else {
        Import-Module Microsoft.PowerShell.SudoProvider -ErrorAction SilentlyContinue
        if ($?) {
            Write-Log "Sudo module imported" "SUCCESS"
        } else {
            Write-Log "Sudo module not available on this system" "WARNING"
        }
    }
} catch {
    Write-Log "Could not enable sudo: $_" "WARNING"
}

# Install Git
try {
    Write-Log "Installing Git..." "INFO"
    if (Get-Command git -ErrorAction SilentlyContinue) {
        Write-Log "Git already installed" "SUCCESS"
    } else {
        $gitUrl = "https://github.com/git-for-windows/git/releases/latest/download/Git-2.47.1-64-bit.exe"
        $gitInstaller = Join-Path $DownloadsPath "git-installer.exe"
        Invoke-WebRequest -Uri $gitUrl -OutFile $gitInstaller
        Start-Process -FilePath $gitInstaller -ArgumentList "/VERYSILENT /NORESTART" -Wait
        Write-Log "Git installed" "SUCCESS"
    }
} catch {
    Write-Log "Failed to install Git: $_" "ERROR"
}

# Install latest PowerShell
try {
    Write-Log "Installing latest PowerShell..." "INFO"
    $pwshUrl = "https://github.com/PowerShell/PowerShell/releases/latest/download/PowerShell-7.5.0-win-x64.msi"
    $pwshInstaller = Join-Path $DownloadsPath "PowerShell.msi"
    Invoke-WebRequest -Uri $pwshUrl -OutFile $pwshInstaller
    Start-Process msiexec.exe -ArgumentList "/i `"$pwshInstaller`" /quiet /norestart ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ADD_FILE_CONTEXT_MENU_RUNPOWERSHELL=1" -Wait
    Write-Log "PowerShell 7 installed" "SUCCESS"
} catch {
    Write-Log "Failed to install PowerShell: $_" "ERROR"
}

# Install Winget (if not present)
try {
    Write-Log "Checking Winget installation..." "INFO"
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Log "Winget already installed" "SUCCESS"
    } else {
        Write-Log "Installing Winget..." "INFO"
        Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe
        Write-Log "Winget installed" "SUCCESS"
    }
} catch {
    Write-Log "Failed to install Winget: $_" "ERROR"
}

# Install Chocolatey
try {
    Write-Log "Installing Chocolatey..." "INFO"
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Log "Chocolatey already installed" "SUCCESS"
    } else {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        Write-Log "Chocolatey installed" "SUCCESS"
    }
} catch {
    Write-Log "Failed to install Chocolatey: $_" "ERROR"
}

# Refresh environment variables
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# Install 7-Zip
try {
    Write-Log "Installing 7-Zip..." "INFO"
    choco install 7zip -y
    Write-Log "7-Zip installed" "SUCCESS"
} catch {
    Write-Log "Failed to install 7-Zip: $_" "ERROR"
}

# Run Chris Titus Tech Windows Utility
try {
    Write-Log "Launching Chris Titus Tech Windows Utility..." "INFO"
    iwr -useb https://christitus.com/win | iex
    Write-Log "Windows Utility executed" "SUCCESS"
} catch {
    Write-Log "Failed to run Windows Utility: $_" "ERROR"
}

# Enable Administrator account
try {
    Write-Log "Enabling built-in Administrator account..." "INFO"
    net user administrator /active:yes
    Write-Log "Administrator account enabled" "SUCCESS"
} catch {
    Write-Log "Failed to enable Administrator account: $_" "ERROR"
}

# Download and unpack Looking Glass
try {
    Write-Log "Downloading Looking Glass host..." "INFO"
    $lgPath = Join-Path $DownloadsPath "looking-glass-host.zip"
    Invoke-WebRequest -Uri "https://looking-glass.io/artifact/stable/host" -OutFile $lgPath
    
    $lgExtractPath = Join-Path $DownloadsPath "LookingGlass"
    Expand-Archive -Path $lgPath -DestinationPath $lgExtractPath -Force
    Write-Log "Looking Glass downloaded and extracted to $lgExtractPath" "SUCCESS"
} catch {
    Write-Log "Failed to download Looking Glass: $_" "ERROR"
}

# Install OpenSSH Server
try {
    Write-Log "Installing OpenSSH Server..." "INFO"
    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
    Start-Service sshd
    Set-Service -Name sshd -StartupType 'Automatic'
    
    # Configure firewall
    New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 -ErrorAction SilentlyContinue
    Write-Log "OpenSSH Server installed and started" "SUCCESS"
} catch {
    Write-Log "Failed to install OpenSSH Server: $_" "ERROR"
}

# Install PowerToys
try {
    Write-Log "Installing PowerToys..." "INFO"
    winget install Microsoft.PowerToys --accept-source-agreements --accept-package-agreements
    Write-Log "PowerToys installed" "SUCCESS"
} catch {
    Write-Log "Failed to install PowerToys: $_" "ERROR"
}

# Download Virtual Display Driver
try {
    Write-Log "Downloading Virtual Display Driver..." "INFO"
    $vddUrl = Get-LatestGitHubRelease -Repo "VirtualDrivers/Virtual-Display-Driver" -AssetPattern "*.zip"
    $vddPath = Join-Path $DownloadsPath "virtual-display-driver.zip"
    Invoke-WebRequest -Uri $vddUrl -OutFile $vddPath
    
    $vddExtractPath = Join-Path $DownloadsPath "VirtualDisplayDriver"
    Expand-Archive -Path $vddPath -DestinationPath $vddExtractPath -Force
    Write-Log "Virtual Display Driver downloaded and extracted to $vddExtractPath" "SUCCESS"
} catch {
    Write-Log "Failed to download Virtual Display Driver: $_" "ERROR"
}

# Download Autologon
try {
    Write-Log "Downloading Autologon..." "INFO"
    $autologonUrl = "https://live.sysinternals.com/Autologon.exe"
    $autologonPath = Join-Path $DownloadsPath "Autologon"
    New-Item -ItemType Directory -Path $autologonPath -Force | Out-Null
    Invoke-WebRequest -Uri $autologonUrl -OutFile (Join-Path $autologonPath "Autologon.exe")
    
    # Also download Autologon64
    Invoke-WebRequest -Uri "https://live.sysinternals.com/Autologon64.exe" -OutFile (Join-Path $autologonPath "Autologon64.exe")
    Write-Log "Autologon downloaded to $autologonPath" "SUCCESS"
} catch {
    Write-Log "Failed to download Autologon: $_" "ERROR"
}

# Download NVCleaninstall
try {
    Write-Log "Downloading NVCleaninstall..." "INFO"
    Write-Log "Note: NVCleaninstall requires manual download from https://www.techpowerup.com/nvcleanstall/" "WARNING"
} catch {
    Write-Log "NVCleaninstall step noted" "WARNING"
}

# Download and run virtio-win-guest-tools
try {
    Write-Log "Downloading virtio-win-guest-tools..." "INFO"
    $virtioUrl = "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/latest-virtio/virtio-win-guest-tools.exe"
    $virtioPath = Join-Path $DownloadsPath "virtio-win-guest-tools.exe"
    Invoke-WebRequest -Uri $virtioUrl -OutFile $virtioPath
    
    Write-Log "Running virtio-win-guest-tools installer..." "INFO"
    Start-Process -FilePath $virtioPath -ArgumentList "/quiet" -Wait
    Write-Log "virtio-win-guest-tools installed" "SUCCESS"
} catch {
    Write-Log "Failed to download/install virtio-win-guest-tools: $_" "ERROR"
}

# Download and run WinFSP
try {
    Write-Log "Downloading WinFSP..." "INFO"
    $winfspUrl = Get-LatestGitHubRelease -Repo "winfsp/winfsp" -AssetPattern "*.msi"
    $winfspPath = Join-Path $DownloadsPath "winfsp.msi"
    Invoke-WebRequest -Uri $winfspUrl -OutFile $winfspPath
    
    Write-Log "Installing WinFSP..." "INFO"
    Start-Process msiexec.exe -ArgumentList "/i `"$winfspPath`" /quiet /norestart" -Wait
    Write-Log "WinFSP installed" "SUCCESS"
} catch {
    Write-Log "Failed to download/install WinFSP: $_" "ERROR"
}

# Install NSSM
try {
    Write-Log "Installing NSSM..." "INFO"
    choco install nssm -y
    Write-Log "NSSM installed" "SUCCESS"
} catch {
    Write-Log "Failed to install NSSM: $_" "ERROR"
}

# Install Display Driver Uninstaller (DDU)
try {
    Write-Log "Installing Display Driver Uninstaller (DDU)..." "INFO"
    $dduUrl = "https://www.wagnardsoft.com/DDU/download/DDU%20v18.0.8.5.exe"
    $dduPath = Join-Path $DownloadsPath "DDU.exe"
    Invoke-WebRequest -Uri $dduUrl -OutFile $dduPath
    Write-Log "DDU downloaded to $dduPath" "SUCCESS"
} catch {
    Write-Log "Failed to download DDU: $_" "ERROR"
}

# Install HWiNFO64
try {
    Write-Log "Installing HWiNFO64..." "INFO"
    choco install hwinfo -y
    Write-Log "HWiNFO64 installed" "SUCCESS"
} catch {
    Write-Log "Failed to install HWiNFO64: $_" "ERROR"
}

# Install Ungoogled Chromium
try {
    Write-Log "Installing Ungoogled Chromium..." "INFO"
    choco install ungoogled-chromium -y
    Write-Log "Ungoogled Chromium installed" "SUCCESS"
} catch {
    Write-Log "Failed to install Ungoogled Chromium: $_" "ERROR"
}

# Enable RDP
try {
    Write-Log "Enabling Remote Desktop..." "INFO"
    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0
    Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
    Write-Log "Remote Desktop enabled" "SUCCESS"
} catch {
    Write-Log "Failed to enable RDP: $_" "ERROR"
}

# Show hidden files
try {
    Write-Log "Configuring Explorer to show hidden files..." "INFO"
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value 1
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowSuperHidden" -Value 1
    Write-Log "Hidden files now visible" "SUCCESS"
} catch {
    Write-Log "Failed to show hidden files: $_" "ERROR"
}

# Restore classic context menu (Windows 11)
try {
    Write-Log "Restoring classic context menu..." "INFO"
    New-Item -Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" -Force | Out-Null
    New-Item -Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" -Force | Out-Null
    Set-ItemProperty -Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" -Name "(Default)" -Value ""
    Write-Log "Classic context menu restored (restart Explorer to apply)" "SUCCESS"
} catch {
    Write-Log "Failed to restore classic context menu: $_" "ERROR"
}

# Disable web search in Start
try {
    Write-Log "Disabling web search in Start menu..." "INFO"
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "BingSearchEnabled" -Value 0 -Type DWord
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "CortanaConsent" -Value 0 -Type DWord
    Write-Log "Web search in Start menu disabled" "SUCCESS"
} catch {
    Write-Log "Failed to disable web search: $_" "ERROR"
}

# Git clone powershell repository
try {
    Write-Log "Cloning powershell repository..." "INFO"
    $gitClonePath = Join-Path $AutomationPath "powershell"
    if (Test-Path $gitClonePath) {
        Write-Log "Repository directory already exists, pulling latest changes..." "INFO"
        Set-Location $gitClonePath
        git pull
    } else {
        git clone https://github.com/almostlight/powershell $gitClonePath
    }
    Write-Log "Repository cloned/updated at $gitClonePath" "SUCCESS"
} catch {
    Write-Log "Failed to clone repository: $_" "ERROR"
}

# Exclude automation directory from Windows Defender
try {
    Write-Log "Excluding $AutomationPath from Windows Defender..." "INFO"
    Add-MpPreference -ExclusionPath $AutomationPath
    Write-Log "Windows Defender exclusion added" "SUCCESS"
} catch {
    Write-Log "Failed to add Defender exclusion: $_" "ERROR"
}

# Disable UAC prompts for automation directory (via registry)
try {
    Write-Log "Configuring UAC settings for automation..." "INFO"
    # Note: Full UAC bypass for specific paths isn't directly supported
    # This lowers UAC level but doesn't exclude specific paths
    Write-Log "Note: UAC cannot be selectively disabled per-directory" "WARNING"
    Write-Log "Consider running automation scripts as scheduled tasks with SYSTEM privileges" "INFO"
} catch {
    Write-Log "UAC configuration noted: $_" "WARNING"
}

# Enable headless start and autologon for current user
try {
    Write-Log "Configuring autologon for current user..." "INFO"
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name.Split('\')[1]
    
    Write-Log "To complete autologon setup, run Autologon.exe from $DownloadsPath\Autologon\" "WARNING"
    Write-Log "Enter your username and password in the Autologon utility" "INFO"
    
    # Configure for headless operation
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "AutoAdminLogon" -Value "1"
    Write-Log "Autologon registry keys configured" "SUCCESS"
} catch {
    Write-Log "Failed to configure autologon: $_" "ERROR"
}

# Add Startup folder to Quick Access
try {
    Write-Log "Adding Startup folder to Quick Access..." "INFO"
    $startupPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
    
    $shell = New-Object -ComObject Shell.Application
    $folder = $shell.Namespace($startupPath)
    $folder.Self.InvokeVerb("pintohome")
    
    Write-Log "Startup folder added to Quick Access" "SUCCESS"
} catch {
    Write-Log "Failed to add Startup to Quick Access: $_" "ERROR"
}

# Restart Explorer to apply changes
try {
    Write-Log "Restarting Explorer to apply changes..." "INFO"
    Stop-Process -Name explorer -Force
    Start-Sleep -Seconds 2
    Write-Log "Explorer restarted" "SUCCESS"
} catch {
    Write-Log "Failed to restart Explorer: $_" "WARNING"
}

Write-Log "`n=== Setup Complete ===" "SUCCESS"
Write-Log "Automation directory: $AutomationPath" "INFO"
Write-Log "Downloads directory: $DownloadsPath" "INFO"
Write-Log "Log file: $LogPath" "INFO"
Write-Log "`nPlease review the log file for any warnings or errors." "INFO"
Write-Log "Some changes may require a system restart to take effect." "WARNING"

# Offer to open log file
$openLog = Read-Host "`nWould you like to open the log file? (Y/N)"
if ($openLog -eq 'Y' -or $openLog -eq 'y') {
    notepad $LogPath
}