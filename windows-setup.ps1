#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Windows system setup and automation script
.DESCRIPTION
    Configures system settings, installs software, and sets up automation environment
#>

param()

$ErrorActionPreference = "Continue"
$AutomationPath = "C:\Users\Public\Automation"
$LogPath = Join-Path $AutomationPath "setup.log"
$gitClonePath = Join-Path $AutomationPath "powershell"
#$DownloadsPath = "$env:USERPROFILE\Downloads"
$DownloadsPath = "C:\Users\Public\Automation\Downloads"
$quickAccessPaths = @(
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup",
    "C:\Users\Public\Automation",
    "C:\Program Files\VDD_Control",
    "C:\ProgramData\Looking Glass (host)"
)

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

Write-Log "=== Windows Automation Setup Started ===" "INFO"

# Check admin privileges
if (-not (Test-Administrator)) {
    Write-Host "Script must be run as Administrator. Attempting to elevate..." -ForegroundColor Yellow
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

Write-Log "Running with Administrator privileges" "SUCCESS"

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
    Write-Log "Note: UAC cannot be selectively disabled per-directory" "WARNING"
    Write-Log "Consider running automation scripts as scheduled tasks with SYSTEM privileges" "INFO"
} catch {
    Write-Log "UAC configuration noted: $_" "WARNING"
}

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

# Install Winget
try {
    Write-Log "Checking WinGet availability..." "INFO"
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Log "WinGet already installed" "SUCCESS"
    } else {
        Write-Log "Installing WinGet..." "INFO"
        $wingetUrl = "https://aka.ms/getwinget"
        $wingetPkg = Join-Path $DownloadsPath "Microsoft.DesktopAppInstaller.msixbundle"
        Invoke-WebRequest -Uri $wingetUrl -OutFile $wingetPkg
        Add-AppxPackage -Path $wingetPkg
        Write-Log "WinGet installed successfully" "SUCCESS"
    }
} catch {
    Write-Log "Failed to install WinGet: $_" "ERROR"
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

# Install latest PowerShell via Winget
try {
    Write-Log "Installing latest PowerShell via Winget..." "INFO"
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $winget) { throw "Winget is not available on this system" }
    Start-Process winget -ArgumentList "install --id Microsoft.PowerShell --silent --accept-package-agreements --accept-source-agreements" -Wait -NoNewWindow
    Write-Log "PowerShell installed successfully via Winget" "SUCCESS"
} catch {
    Write-Log "Failed to install PowerShell via Winget: $($_.Exception.Message)" "ERROR"
}

$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
            [System.Environment]::GetEnvironmentVariable("Path","User")

# Install Git
try {
    Write-Log "Installing Git..." "INFO"
    winget install Git.Git --accept-source-agreements --accept-package-agreements
    Write-Log "Git installed" "SUCCESS"
} catch {
    Write-Log "Failed to install Git: $_" "ERROR"
}

# Git clone this repository
try {
    Write-Log "Cloning powershell repository..." "INFO"
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

# Install 7-Zip
try {
    Write-Log "Installing 7-Zip..." "INFO"
    choco install 7zip -y
    Write-Log "7-Zip installed" "SUCCESS"
} catch {
    Write-Log "Failed to install 7-Zip: $_" "ERROR"
}

# Install and enable OpenSSH Server
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

# Enable RDP
try {
    Write-Log "Enabling Remote Desktop..." "INFO"
    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0
    Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
    Write-Log "Remote Desktop enabled" "SUCCESS"
} catch {
    Write-Log "Failed to enable RDP: $_" "ERROR"
}

# Install Notepad++
try {
    Write-Log "Installing Notepad++..." "INFO"
    winget install Notepad++.Notepad++ --accept-source-agreements --accept-package-agreements
    Write-Log "Notepad++ installed" "SUCCESS"
} catch {
    Write-Log "Failed to install Notepad++: $_" "ERROR"
}

try {
    Write-Log "Running NPPPowershell install script..." "INFO"
    Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$gitClonePath\npp_powershell_installer.ps1`"" -Wait -NoNewWindow
    Write-Log "NPPPowershell installed" "SUCCESS"
} catch {
    Write-Log "Failed to download/install NPPPowershell: $_" "ERROR"
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

# Enable Administrator account
try {
    Write-Log "Enabling built-in Administrator account..." "INFO"
    net user administrator /active:yes
    Write-Log "Administrator account enabled" "SUCCESS"
} catch {
    Write-Log "Failed to enable Administrator account: $_" "ERROR"
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

######## Configure VM + PCI passthrough (wip)

# Download and run virtio-win-guest-tools
try {
    Write-Log "Downloading virtio-win-guest-tools..." "INFO"
    
    $virtioUrl = "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/latest-virtio/virtio-win-guest-tools.exe"
    $virtioPath = Join-Path $DownloadsPath "virtio-win-guest-tools.exe"
    
    # Remove existing file if present
    if (Test-Path $virtioPath) {
        Remove-Item $virtioPath -Force
    }
    
    # Disable progress bar for faster download
    $ProgressPreference = 'SilentlyContinue'
    
    # Try BITS first (fastest), fallback to Invoke-WebRequest
    try {
        Start-BitsTransfer -Source $virtioUrl -Destination $virtioPath -Description "VirtIO Guest Tools"
        Write-Log "Downloaded using BITS transfer" "INFO"
    } catch {
        Write-Log "BITS failed, using standard download..." "INFO"
        Invoke-WebRequest -Uri $virtioUrl -OutFile $virtioPath -UseBasicParsing
    }
    
    $ProgressPreference = 'Continue'
    
    # Verify download
    if (-not (Test-Path $virtioPath)) {
        throw "Download failed - file not found at $virtioPath"
    }
    
    Write-Log "Download complete. Running virtio-win-guest-tools installer..." "INFO"
    Start-Process -FilePath $virtioPath -ArgumentList "/quiet" -Wait
    Write-Log "virtio-win-guest-tools installed successfully" "SUCCESS"
    
} catch {
    Write-Log "Failed to download/install virtio-win-guest-tools: $($_.Exception.Message)" "ERROR"
    $ProgressPreference = 'Continue'
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

# Download Virtual Display Driver
try {
    Write-Log "Downloading Virtual Display Driver..." "INFO"
    
    # Define installation path
    $vddInstallPath = "C:\Program Files\VDD_Control"
    
    # Create directory if it doesn't exist (requires admin rights)
    if (-not (Test-Path $vddInstallPath)) {
        New-Item -Path $vddInstallPath -ItemType Directory -Force | Out-Null
        Write-Log "Created directory: $vddInstallPath" "INFO"
    }
    
    # Get latest release
    $vddUrl = Get-LatestGitHubRelease `
		-Repo "VirtualDrivers/Virtual-Display-Driver" `
		-AssetPattern "VDD.Control.*.zip"
	
    if (-not $vddUrl) {
        throw "Could not find download URL for Virtual Display Driver"
    }
    
    # Download to temp location first
    $vddPath = Join-Path $env:TEMP "virtual-display-driver.zip"
    
    Write-Log "Downloading from: $vddUrl" "INFO"
    Invoke-WebRequest -Uri $vddUrl -OutFile $vddPath -UseBasicParsing
    
    # Verify download
    if (-not (Test-Path $vddPath)) {
        throw "Download failed - file not found"
    }
    
    Write-Log "Extracting to $vddInstallPath..." "INFO"
    
    # Extract directly to Program Files
    Expand-Archive -Path $vddPath -DestinationPath $vddInstallPath -Force
    
    # Clean up temp zip
    Remove-Item $vddPath -Force -ErrorAction SilentlyContinue
    
    Write-Log "Virtual Display Driver installed to $vddInstallPath" "SUCCESS"
    
    # Run VDD Control
    $vddExePath = Join-Path $vddInstallPath "VDD Control.exe"
    
    if (Test-Path $vddExePath) {
        Write-Log "Launching VDD Control..." "INFO"
        Start-Process -FilePath $vddExePath
        Write-Log "VDD Control launched successfully" "SUCCESS"
    } else {
        # Search for the exe in subdirectories
        $vddExe = Get-ChildItem -Path $vddInstallPath -Filter "VDD Control.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        
        if ($vddExe) {
            Write-Log "Found VDD Control at: $($vddExe.FullName)" "INFO"
            Start-Process -FilePath $vddExe.FullName
            Write-Log "VDD Control launched successfully" "SUCCESS"
        } else {
            Write-Log "VDD Control.exe not found in $vddInstallPath" "WARNING"
            Write-Log "Available files:" "INFO"
            Get-ChildItem -Path $vddInstallPath -Recurse | ForEach-Object {
                Write-Log "  $($_.FullName)" "INFO"
            }
        }
    }
    
} catch {
    Write-Log "Failed to install Virtual Display Driver: $($_.Exception.Message)" "ERROR"
    
    # Check if it's a permissions issue
    if ($_.Exception.Message -like "*Access*denied*" -or $_.Exception.Message -like "*cannot create*") {
        Write-Log "This script requires administrator privileges to install to Program Files" "ERROR"
    }
}

# Download and install Looking Glass
try {
    Write-Log "Downloading Looking Glass host..." "INFO"
    
    # Download to temp location
    $lgTempPath = Join-Path $env:TEMP "looking-glass-host.zip"
    Invoke-WebRequest -Uri "https://looking-glass.io/artifact/stable/host" -OutFile $lgTempPath -UseBasicParsing
    
    # Verify download
    if (-not (Test-Path $lgTempPath)) {
        throw "Download failed - file not found"
    }
    
    Write-Log "Download complete. Extracting to Downloads..." "INFO"
    
    # Extract to Downloads
    $lgExtractPath = Join-Path $DownloadsPath "LookingGlass"
    
    # Remove old extraction if exists
    if (Test-Path $lgExtractPath) {
        Remove-Item $lgExtractPath -Recurse -Force
    }
    
    Expand-Archive -Path $lgTempPath -DestinationPath $lgExtractPath -Force
    
    # Clean up temp zip
    Remove-Item $lgTempPath -Force -ErrorAction SilentlyContinue
    
    Write-Log "Looking Glass extracted to $lgExtractPath" "SUCCESS"
    
    # Find and run the setup executable
    $setupExe = Get-ChildItem -Path $lgExtractPath -Filter "looking-glass-host-setup.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    
    if ($setupExe) {
        Write-Log "Found installer at: $($setupExe.FullName)" "INFO"
        Write-Log "Launching Looking Glass Host Setup..." "INFO"
        Start-Process -FilePath $setupExe.FullName -Wait
        Write-Log "Looking Glass Host Setup completed" "SUCCESS"
    } else {
        Write-Log "looking-glass-host-setup.exe not found in extraction" "WARNING"
        Write-Log "Available files:" "INFO"
        Get-ChildItem -Path $lgExtractPath -Recurse | ForEach-Object {
            Write-Log "  $($_.FullName)" "INFO"
        }
    }
    
} catch {
    Write-Log "Failed to download/install Looking Glass: $($_.Exception.Message)" "ERROR"
}

# Download and run NVCleaninstall
try {
    Write-Log "Downloading NVCleaninstall..." "INFO"
    
    # Download directly to Downloads folder
    $nvCleanPath = Join-Path $DownloadsPath "NVCleanstall.exe"
    
    Write-Log "Downloading from SourceForge..." "INFO"
    Invoke-WebRequest -Uri "https://sourceforge.net/projects/nvcleanstall/files/latest/download" -OutFile $nvCleanPath -UseBasicParsing
    
    # Verify download
    if (-not (Test-Path $nvCleanPath)) {
        throw "Download failed - file not found"
    }
    
    Write-Log "NVCleaninstall downloaded to $nvCleanPath" "SUCCESS"
    
    # Run the executable
    Write-Log "Launching NVCleaninstall..." "INFO"
    Start-Process -FilePath $nvCleanPath
    Write-Log "NVCleaninstall launched successfully" "SUCCESS"
    
} catch {
    Write-Log "Failed to download/run NVCleaninstall: $($_.Exception.Message)" "ERROR"
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

######## Assorted tweaks

<# 
# Install PowerToys
try {
    Write-Log "Installing PowerToys..." "INFO"
    winget install Microsoft.PowerToys --accept-source-agreements --accept-package-agreements
    Write-Log "PowerToys installed" "SUCCESS"
} catch {
    Write-Log "Failed to install PowerToys: $_" "ERROR"
}
#>

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

# Show hidden files
try {
    Write-Log "Configuring Explorer to show hidden files..." "INFO"
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value 1
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowSuperHidden" -Value 1
    Write-Log "Hidden files now visible" "SUCCESS"
} catch {
    Write-Log "Failed to show hidden files: $_" "ERROR"
}

# Add folders to Quick Access
try {
    Write-Log "Adding folders to Quick Access..." "INFO"
    
    $shell = New-Object -ComObject Shell.Application
    $pinnedCount = 0
    
    foreach ($path in $quickAccessPaths) {
        try {
            if (Test-Path $path) {
                $folder = $shell.Namespace($path)
                $folder.Self.InvokeVerb("pintohome")
                Write-Log "Pinned to Quick Access: $path" "SUCCESS"
                $pinnedCount++
            } else {
                Write-Log "Path not found, skipping: $path" "WARNING"
            }
        } catch {
            Write-Log "Failed to pin $path : $_" "ERROR"
        }
    }
    
    Write-Log "$pinnedCount folder(s) added to Quick Access" "SUCCESS"
} catch {
    Write-Log "Failed to add folders to Quick Access: $_" "ERROR"
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

Write-Log "`n=== Interactive Section ===" "INFO"

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

Write-Log "`n=== Setup Complete ===" "SUCCESS"
Write-Log "Automation directory: $AutomationPath" "INFO"
Write-Log "Downloads directory: $DownloadsPath" "INFO"
Write-Log "Log file: $LogPath" "INFO"
Write-Log "`nPlease review the log file for any warnings or errors." "INFO"
Write-Log "Some changes may require a system restart to take effect." "WARNING"

<# 
# Offer to run Chris Titus Tech Windows Utility
$useWinUtil = Read-Host "`nWould you like to run Chris Titus Tech's Windows Utility? (Y/N)"
if ($useWinUtil -eq 'Y' -or $useWinUtil -eq 'y') {
try {
    Write-Log "Launching Chris Titus Tech Windows Utility..." "INFO"
    iwr -useb https://christitus.com/win | iex
    Write-Log "Windows Utility executed" "SUCCESS"
} catch {
    Write-Log "Failed to run Windows Utility: $_" "ERROR"
}
#>

# Offer to open log file
$openLog = Read-Host "`nWould you like to open the log file? (Y/N)"
if ($openLog -eq 'Y' -or $openLog -eq 'y') {
    notepad $LogPath
}
