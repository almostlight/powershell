# Path to the executable - adjust if needed
$exePath = "C:\Program Files\Looking Glass (host)\looking-glass-host.exe"
$processName = "looking-glass-host"
$vddControlPath = "C:\Program Files\VDD_Control\VDD Control.exe"
$vddControlProcessName = "VDD Control"
$DELAY = 1  # Delay in seconds after VDD Control starts before starting Looking Glass
$logPath = "C:\ProgramData\Looking Glass (host)\looking-glass-host.txt"

# Function to write timestamped log messages
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARNING" { "Yellow" }
        "SUCCESS" { "Green" }
        default { "Cyan" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

# Function to restart the processes
function Restart-LookingGlass {
    Write-Log "Starting Looking Glass restart sequence..." "INFO"
    Write-Log "========================================" "INFO"
    
    # Stop Looking Glass if it's running
    Write-Log "Checking for running Looking Glass process ($processName)..." "INFO"
    $proc = Get-Process -Name $processName -ErrorAction SilentlyContinue
    if ($proc) {
        Write-Log "Found Looking Glass process (PID: $($proc.Id)). Stopping..." "WARNING"
        $proc | Stop-Process -Force
        Start-Sleep -Milliseconds 500
        Write-Log "Looking Glass process stopped successfully." "SUCCESS"
    } else {
        Write-Log "Looking Glass process not running." "INFO"
    }
    
    # Start VDD Control if not running
    Write-Log "Checking for VDD Control process ($vddControlProcessName)..." "INFO"
    $vddProc = Get-Process -Name $vddControlProcessName -ErrorAction SilentlyContinue
    if (!$vddProc) {
        Write-Log "VDD Control not running. Starting..." "INFO"
        if (Test-Path $vddControlPath) {
            Write-Log "VDD Control executable found at: $vddControlPath" "INFO"
            Start-Process $vddControlPath -WindowStyle Hidden
            Start-Sleep -Milliseconds 500
            
            # Verify VDD Control started
            $vddProc = Get-Process -Name $vddControlProcessName -ErrorAction SilentlyContinue
            if ($vddProc) {
                Write-Log "VDD Control started successfully (PID: $($vddProc.Id))." "SUCCESS"
            } else {
                Write-Log "Warning: Could not verify VDD Control process started." "WARNING"
            }
        } else {
            Write-Log "VDD Control executable not found at: $vddControlPath" "ERROR"
        }
    } else {
        Write-Log "VDD Control already running (PID: $($vddProc.Id))." "INFO"
    }
    
    # Start Looking Glass after delay
    Write-Log "Waiting $DELAY seconds before starting Looking Glass..." "INFO"
    if (Test-Path $exePath) {
        Start-Sleep -Seconds $DELAY
        Write-Log "Starting Looking Glass from: $exePath" "INFO"
        Start-Process $exePath -WindowStyle Hidden
        Start-Sleep -Milliseconds 500
        
        # Verify Looking Glass started
        $lgProc = Get-Process -Name $processName -ErrorAction SilentlyContinue
        if ($lgProc) {
            Write-Log "Looking Glass started successfully (PID: $($lgProc.Id))." "SUCCESS"
        } else {
            Write-Log "Warning: Could not verify Looking Glass process started." "WARNING"
        }
    } else {
        Write-Log "Looking Glass executable not found at: $exePath" "ERROR"
    }
    
    # Stop VDD Control
    Write-Log "Stopping VDD Control..." "INFO"
    $vddProc = Get-Process -Name $vddControlProcessName -ErrorAction SilentlyContinue
    if ($vddProc) {
        Write-Log "Found VDD Control process (PID: $($vddProc.Id)). Stopping..." "INFO"
        $vddProc | Stop-Process -Force
        Start-Sleep -Milliseconds 500
        Write-Log "VDD Control stopped successfully." "SUCCESS"
    } else {
        Write-Log "VDD Control process not found." "INFO"
    }
    
    Write-Log "========================================" "INFO"
    Write-Log "Restart sequence completed." "SUCCESS"
}

# Check if script is running as Administrator
Write-Log "Checking administrator privileges..." "INFO"
$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currentUser)

if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Log "Script not running as Administrator. Restarting with elevated privileges..." "WARNING"
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`"" -Verb RunAs -WindowStyle Hidden
    exit
}

Write-Log "Running with Administrator privileges." "SUCCESS"

# Restart the processes
Restart-LookingGlass

# Print log file
Write-Log "" "INFO"
Write-Log "Reading Looking Glass log file..." "INFO"
Write-Log "========================================" "INFO"

Start-Sleep -Seconds 2

if (Test-Path $logPath) {
    Write-Log "Log file found at: $logPath" "SUCCESS"
    Write-Host ""
    Write-Host "--- Looking Glass Log Contents ---" -ForegroundColor Magenta
    Get-Content $logPath | Select-String -Pattern "GPU|DISPLAY|CAPTURE|OUTPUT" -CaseSensitive:$false
    Write-Host "--- End of Log ---" -ForegroundColor Magenta
} else {
    Write-Log "Log file not found at: $logPath" "WARNING"
}

Write-Log "" "INFO"
Write-Log "Script execution completed. Closing."

exit

###