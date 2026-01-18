# Windows KVM Setup Script

[windows-setup.ps1](Windows/windows-setup.ps1) is a PowerShell script for automating Windows system setup, software installation, and configuration. It's intended for fresh Windows 11 installations in virtual machines with Nvidia GPU passthrough and meant to simplify the process of setting up GPU drivers, virtual display drivers, and Looking Glass for native-like graphics performance. It includes tons of other tweaks as well. 
[npp_powershell_installer.ps1](Windows/npp_powershell_installer.ps1) is a helper script to set up PowerShell syntax support in Notepad++. It is downloaded and called by [windows-setup.ps1](Windows/windows-setup.ps1).

##  Quick Start

**Tip**: Create a system restore point before running:
```powershell
Checkpoint-Computer -Description "Before Automation Script" -RestorePointType "MODIFY_SETTINGS"
```

### One-Line Installation

```powershell
irm https://raw.githubusercontent.com/almostlight/Win11-Virt/main/windows-setup.ps1 | iex
```

### Manual Installation

1. Download the script:
```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/almostlight/Win11-Virt/main/windows-setup.ps1" -OutFile "windows-setup.ps1"
```

2. Review the script:
```powershell
notepad windows-setup.ps1
```

3. Run the script as Administrator:
```powershell
.\windows-setup.ps1
```

##  What It Does

### Infrastructure Setup
-  Automatic administrator privilege checking and elevation
-  Creates automation directory at `C:\Users\Public\Automation`
-  Logging to `C:\Users\Public\Automation\setup.log`

### Package Managers & Core Tools
- **Chocolatey** - Windows package manager
- **Winget** - Microsoft's official package manager
- **Git** - Version control system
- **PowerShell 7** - Latest PowerShell version
- **7-Zip** - File compression utility

### System Software
- **OpenSSH Server** - Remote SSH access (with firewall rules)
- **PowerToys** - Microsoft productivity utilities
- **NSSM** - Non-Sucking Service Manager
- **Ungoogled Chromium** - Privacy-focused browser

### Monitoring & Utilities
- **HWiNFO64** - Hardware monitoring and diagnostics
- **Display Driver Uninstaller (DDU)** - Clean GPU driver removal
- **Autologon** - Automatic login configuration (64-bit and 32-bit)

### Virtualization & Remote Gaming
- **Looking Glass** - Low-latency KVM frame relay
- **Virtual Display Driver** - Virtual monitor creation
- **virtio-win-guest-tools** - VirtIO drivers for Windows guests
- **WinFSP** - Windows File System Proxy

### System Configuration
-  **Enable RDP** - Remote Desktop Protocol
-  **Enable Administrator account** - Built-in admin account
-  **Enable sudo** - PowerShell sudo functionality
-  **Show hidden files** - Explorer configuration
-  **Classic context menu** - Restore Windows 10 style menu (Win 11)
-  **Disable web search in Start** - Remove Bing from Start menu
-  **Windows Defender exclusions** - Exclude automation directory
-  **Autologon configuration** - Registry keys for automatic login
-  **Quick Access shortcuts** - Add Startup folder

##  Security Considerations

### Before Running
1. **Review the script** - Always examine scripts before running them

### What Gets Modified
- **Registry changes** - Explorer settings, autologon, context menu
- **Firewall rules** - OpenSSH, RDP
- **Windows Defender** - Exclusion for `C:\Users\Public\Automation`
- **System accounts** - Enables Administrator account
- **Installed software** - Multiple applications and utilities

### Exclusions
The script adds `C:\Users\Public\Automation` to Windows Defender exclusions. This is necessary for automation scripts but means:
- Files in this directory won't be scanned automatically
- Only place trusted scripts here
- Manually scan if suspicious

##  Logging

All actions are logged to `C:\Users\Public\Automation\setup.log` with:
- Timestamps for each action
- Success/Error/Warning classifications
- Detailed error messages for troubleshooting

View the log:
```powershell
notepad C:\Users\Public\Automation\setup.log
```

##  What Requires Manual Action

Some items require manual configuration after the script runs:

- **Autologon** - enter your credentials
- **System Restart** - Some changes may require a reboot to take effect

## ️ Troubleshooting

### Script won't run
```powershell
# Set execution policy
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
```

### Installation failures
- Check the log file at `C:\Users\Public\Automation\setup.log`
- Ensure stable internet connection
- Verify administrator privileges
- Temporarily disable antivirus

### Chocolatey errors
```powershell
# Reinstall Chocolatey
Remove-Item C:\ProgramData\chocolatey -Recurse -Force
# Re-run the script
```

##  Additional Resources

- [PowerShell Documentation](https://docs.microsoft.com/powershell/)
- [Chocolatey Packages](https://community.chocolatey.org/packages)
- [Winget Packages](https://winget.run/)
- [Chris Titus Tech Utility](https://christitus.com/windows-tool/)

## Contributing

To improve this script:
1. Fork the repository
2. Make your changes
3. Test thoroughly on a clean Windows installation
4. Submit a pull request

##  Support

- **Issues**: [GitHub Issues](https://github.com/almostlight/powershell/issues)
- **Discussions**: [GitHub Discussions](https://github.com/almostlight/powershell/discussions)
- **Log File**: Always check `C:\Users\Public\Automation\setup.log` first

##  License

These scripts are provided as-is. Use at your own risk.

---

##  TODO
- Add Linux gues auto-deployment script
- Check for existing Looking Glass and VDD installations on host side
- Edit software list
- Add Github login
