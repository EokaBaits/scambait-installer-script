#Requires -RunAsAdministrator
#Requires -Version 5.1
<#
.SYNOPSIS
    One-file scambait setup for a Windows 10 VM on Proxmox VE.

.DESCRIPTION
    Best workflow: put this script + an assets\ folder in a GitHub repo, then on the VM:
      git clone <your-repo>
      cd <repo>
      .\Install-Scambait.ps1

    Or download only this script and set Assets.GitHub below so wallpapers/video
    are pulled from raw.githubusercontent.com automatically.

    Tools (Moo.*, XAMPP, DSJAS, winget apps) also download when online.

    Still required on the Proxmox HOST (not this guest script):
      host/proxmox-smbios.conf  -> apply smbios1 + kvm=off for this VMID

.EXAMPLE
    git clone https://github.com/YOU/scambait-installer.git
    cd scambait-installer
    Set-ExecutionPolicy Bypass -Scope Process -Force
    .\Install-Scambait.ps1
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$SkipDownloads
)

$ErrorActionPreference = 'Continue'
$script:Root = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $script:Root) { $script:Root = (Get-Location).Path }
$script:SkipDownloads = $SkipDownloads
$script:WorkDir = Join-Path $env:TEMP 'ScambaitInstall'
$script:LogFile = Join-Path $script:WorkDir 'install.log'

# =============================================================================
# CONFIG - edit this section only (persona / toggles)
# =============================================================================
$script:Config = @{
    Persona = @{
        FirstName      = 'Walter'
        LastName       = 'Greene'
        Nickname       = 'Wally'
        FullName       = 'Walter Greene'
        Age            = 62
        Occupation     = 'Retired Construction Foreman'
        Email          = 'waltergreene60636@gmail.com'
        EmailPassword  = 'NeedToCook'
        PcPassword     = 'NeedToCook'
        ComputerName   = 'DESKTOP-WG60636'
        Phone          = '312-680-3116'
        Street         = '5702 S Seeley Ave'
        City           = 'Chicago'
        State          = 'IL'
        StateFull      = 'Illinois'
        Zip            = '60636'
        Timezone       = 'Central Standard Time'
        BankDomain     = 'midwestcommunitybank.com'
        BankDbName     = 'bank'
        BankDbUser     = 'waltergreene60636'
        BankDbPassword = 'WeNeedToCook'
        BankOnlineUser = 'waltergreene60636'
        BankOnlinePass = 'WeNeedToCook'
        BankAdminUser  = 'Davey'
        BankAdminEmail = 'waltergreene60636@gmail.com'
        BankAdminPass  = 'HowYouDoing'
        BankName       = 'Midwest Community Bank'
    }

    # Local layout when you git clone the whole repo (recommended):
    #   assets/wallpapers/*.jpg
    #   assets/camera/webcam_loop.mp4
    #   assets/personal-files/**   (optional extras)
    Paths = @{
        AssetsRoot    = 'assets'
        Wallpapers    = 'assets\wallpapers'
        CameraVideo   = 'assets\camera\webcam_loop.mp4'
        PersonalFiles = 'assets\personal-files'
        Tools         = 'tools'
        Micerosoft    = 'assets\micerosoft'
        LogFile       = 'install.log'
    }

    # If assets\ is missing (script-only copy), download these from your GitHub repo.
    # Set Owner/Repo to yours. Leave Owner blank to skip remote asset sync.
    # Keep images small; videos over ~50MB: use Git LFS or a Release asset URL instead.
    Assets = @{
        GitHubOwner  = ''          # e.g. 'mccus'
        GitHubRepo   = ''          # e.g. 'scambait-installer'
        GitHubBranch = 'main'
        # Relative paths inside the repo to fetch via raw.githubusercontent.com
        Files = @(
            'assets/camera/webcam_loop.mp4'
            'assets/wallpapers/livingroom.jpg'
            'assets/wallpapers/garden.jpg'
            'assets/wallpapers/family.jpg'
        )
    }

    WingetPackages = @(
        @{ Id = 'Google.Chrome'; Name = 'Google Chrome' }
        @{ Id = 'Mozilla.Firefox'; Name = 'Mozilla Firefox' }
        @{ Id = 'Adobe.Acrobat.Reader.64-bit'; Name = 'Adobe Acrobat Reader' }
        @{ Id = 'VideoLAN.VLC'; Name = 'VLC Media Player' }
        @{ Id = '7zip.7zip'; Name = '7-Zip' }
        @{ Id = 'Notepad++.Notepad++'; Name = 'Notepad++' }
        @{ Id = 'Zoom.Zoom'; Name = 'Zoom' }
        @{ Id = 'Discord.Discord'; Name = 'Discord' }
        @{ Id = 'Spotify.Spotify'; Name = 'Spotify' }
        @{ Id = 'WinRAR.WinRAR'; Name = 'WinRAR' }
        @{ Id = 'Oracle.JavaRuntimeEnvironment'; Name = 'Java Runtime' }
        @{ Id = 'CPUID.CPU-Z'; Name = 'CPU-Z' }
        @{ Id = 'Piriform.CCleaner'; Name = 'CCleaner' }
    )

    SkipWingetIds = @()

    FakePrinter = @{
        Name   = 'HP LaserJet Pro M404dn'
        Driver = 'Microsoft IPP Class Driver'
        Port   = 'LPT1:'
    }

    DeviceRenames = @(
        @{ Match = 'QEMU';   NewName = 'Intel(R) Chipset Device' }
        @{ Match = 'VirtIO';  NewName = 'Intel(R) Ethernet Connection' }
        @{ Match = 'Red Hat'; NewName = 'Intel(R) Network Adapter' }
        @{ Match = 'Virtio';  NewName = 'Standard SATA AHCI Controller' }
        @{ Match = 'Balloon'; NewName = 'Intel(R) Management Engine' }
        @{ Match = 'Spice';   NewName = 'High Definition Audio Device' }
        @{ Match = 'QXL';     NewName = 'Intel(R) UHD Graphics' }
        @{ Match = 'Virtual'; NewName = 'Generic USB Hub' }
        @{ Match = 'Hyper-V'; NewName = 'Microsoft ACPI-Compliant System' }
        @{ Match = 'VMware';  NewName = 'Realtek PCIe GbE Family Controller' }
        @{ Match = 'VBox';    NewName = 'Realtek Audio' }
        @{ Match = 'Oracle';  NewName = 'Realtek Audio Controller' }
        @{ Match = 'Proxmox'; NewName = 'Intel(R) USB 3.0 eXtensible Host Controller' }
    )

    QemuGuestAgent = @{
        ServiceName      = 'QEMU-GA'
        DisguisedName    = 'IntelMEI'
        DisguisedDisplay = 'Intel(R) Management Engine Interface'
        DisguisedDesc    = 'Provides system management and hardware monitoring services.'
        HideFromServices = $true
    }

    Moo = @{
        FuckScreenConnectApi = 'https://api.github.com/repos/RobotsOnDrugs/Moo.FuckScreenConnect-rs/releases/latest'
        NoBlockInputApi      = 'https://api.github.com/repos/RobotsOnDrugs/Moo.NoBlockInput/releases/latest'
    }

    Xampp = @{
        InstallDir      = 'C:\xampp'
        DownloadUrl     = 'https://sourceforge.net/projects/xampp/files/XAMPP%20Windows/8.2.12/xampp-windows-x64-8.2.12-0-VS16-installer.exe/download'
        InstallerName   = 'xampp-installer.exe'
        DsjasReleaseApi = 'https://api.github.com/repos/DSJAS/DSJAS/releases/latest'
    }

    Features = @{
        RenameDevices            = $true
        DisguiseQemuAgent        = $true
        DisableWindowsUpdate     = $true
        DisableDefender          = $true
        DisableTelemetry         = $true
        AddFakePrinter           = $true
        SetupCameraLoop          = $true
        InstallPrograms          = $true
        SeedChromeHistory        = $true
        GeneratePersonalFiles    = $true
        CopyWallpapers           = $true
        SyncGitHubAssets         = $true
        InstallFuckScreenConnect = $true
        InstallNoBlockInput      = $true
        InstallMicerosoftPopup   = $true
        InstallXamppDsjas        = $true
        MaskVmArtifacts          = $true
        SetComputerName          = $true
    }
}

# =============================================================================
# RUNTIME HELPERS
# =============================================================================
function Write-Log {
    param([string]$Message, [ValidateSet('INFO','WARN','ERROR','OK')][string]$Level = 'INFO')
    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[$ts][$Level] $Message"
    $color = @{ INFO = 'Cyan'; WARN = 'Yellow'; ERROR = 'Red'; OK = 'Green' }[$Level]
    Write-Host $line -ForegroundColor $color
    if ($script:LogFile) {
        $dir = Split-Path $script:LogFile -Parent
        if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        Add-Content -Path $script:LogFile -Value $line -Encoding UTF8
    }
}

function Test-Feature {
    param([string]$Name)
    return [bool]$script:Config.Features[$Name]
}

function Invoke-Step {
    param([string]$Name, [string]$Feature, [scriptblock]$Action)
    if (-not [string]::IsNullOrWhiteSpace($Feature) -and -not (Test-Feature $Feature)) {
        Write-Log "Skipped (disabled in config): $Name" 'WARN'
        return
    }
    Write-Log "=== $Name ===" 'INFO'
    try {
        if ($PSCmdlet.ShouldProcess($Name)) {
            & $Action
            Write-Log "Completed: $Name" 'OK'
        }
    }
    catch {
        Write-Log "Failed: $Name - $($_.Exception.Message)" 'ERROR'
    }
}

function Get-AssetPath {
    param([string]$Relative)
    if ([string]::IsNullOrWhiteSpace($Relative)) { return $script:WorkDir }
    if ([IO.Path]::IsPathRooted($Relative)) { return $Relative }
    $beside = Join-Path $script:Root $Relative
    if (Test-Path $beside) { return $beside }
    return (Join-Path $script:WorkDir $Relative)
}

function Sync-ScambaitGitHubAssets {
    Write-Log 'Syncing media assets...' 'INFO'
    $a = $script:Config.Assets
    if (-not $a) {
        Write-Log 'No Assets config block - using local files only' 'INFO'
        return
    }

    $localWall = Join-Path $script:Root $script:Config.Paths.Wallpapers
    $localCam  = Join-Path $script:Root $script:Config.Paths.CameraVideo
    $hasLocal = (Test-Path $localCam) -or (
        (Test-Path $localWall) -and
        (Get-ChildItem $localWall -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -match '\.(jpg|jpeg|png|bmp|webp)$' })
    )

    if ($hasLocal) {
        Write-Log "Using local assets under $script:Root\assets (git clone layout)" 'OK'
        return
    }

    if ($script:SkipDownloads) {
        Write-Log 'SkipDownloads set and no local assets found' 'WARN'
        return
    }

    if ([string]::IsNullOrWhiteSpace($a.GitHubOwner) -or [string]::IsNullOrWhiteSpace($a.GitHubRepo)) {
        Write-Log 'No local assets\ folder and Assets.GitHubOwner/Repo not set.' 'WARN'
        Write-Log 'Either git clone the full repo, or set Assets.GitHubOwner + GitHubRepo in the config block.' 'WARN'
        return
    }

    $branch = if ($a.GitHubBranch) { $a.GitHubBranch } else { 'main' }
    $base = "https://raw.githubusercontent.com/$($a.GitHubOwner)/$($a.GitHubRepo)/$branch"
    Write-Log "Downloading assets from $base ..." 'INFO'

    foreach ($rel in @($a.Files)) {
        if ([string]::IsNullOrWhiteSpace($rel)) { continue }
        $relWin = $rel -replace '/', '\'
        $out = Join-Path $script:Root $relWin
        Ensure-Dir (Split-Path $out -Parent)
        $url = "$base/$($rel -replace '\\','/')"
        try {
            Download-File -Url $url -OutFile $out
            Write-Log "Asset OK: $relWin" 'OK'
        }
        catch {
            Write-Log "Asset missing/failed ($rel): $($_.Exception.Message)" 'WARN'
        }
    }
}

#region Common
# Get-AssetPath defined in header

function Ensure-Dir {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Set-RegistryValue {
    param(
        [string]$Path,
        [string]$Name,
        [object]$Value,
        [Microsoft.Win32.RegistryValueKind]$Type = [Microsoft.Win32.RegistryValueKind]::DWord
    )
    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }
    New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
}

function Stop-ServiceSafe {
    param([string]$Name)
    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if ($svc) {
        if ($svc.Status -ne 'Stopped') {
            Stop-Service -Name $Name -Force -ErrorAction SilentlyContinue
        }
        Set-Service -Name $Name -StartupType Disabled -ErrorAction SilentlyContinue
        Write-Log "Service stopped/disabled: $Name" 'OK'
    }
}

function Download-File {
    param(
        [string]$Url,
        [string]$OutFile,
        [string]$UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) ScambaitInstaller/1.0'
    )
    Ensure-Dir (Split-Path $OutFile -Parent)
    Write-Log "Downloading: $Url" 'INFO'
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $oldProgress = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
    try {
        Invoke-WebRequest -Uri $Url -OutFile $OutFile -UserAgent $UserAgent -UseBasicParsing
    }
    finally {
        $ProgressPreference = $oldProgress
    }
    if (-not (Test-Path $OutFile)) { throw "Download failed: $Url" }
}

function Expand-ZipSafe {
    param([string]$Zip, [string]$Dest)
    Ensure-Dir $Dest
    Expand-Archive -Path $Zip -DestinationPath $Dest -Force
}

function Get-GithubLatestAsset {
    param(
        [string]$ApiUrl,
        [string]$NameMatch = '\.zip$'
    )
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $headers = @{ 'User-Agent' = 'ScambaitInstaller'; 'Accept' = 'application/vnd.github+json' }
    $release = Invoke-RestMethod -Uri $ApiUrl -Headers $headers
    $asset = $release.assets | Where-Object { $_.name -match $NameMatch } | Select-Object -First 1
    if (-not $asset) { throw "No matching asset on $ApiUrl" }
    return @{
        Name        = $asset.name
        Url         = $asset.browser_download_url
        Tag         = $release.tag_name
        Body        = $release.body
        ZipballUrl  = $release.zipball_url
    }
}

function Get-DefaultGatewayIPv4 {
    $cfg = Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq 'Up' } | Select-Object -First 1
    if ($cfg) { return $cfg.IPv4DefaultGateway.NextHop }
    $route = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($route) { return $route.NextHop }
    return '10.0.2.2'
}

function Add-HostsEntry {
    param([string]$Ip, [string]$Hostname)
    $hosts = "$env:SystemRoot\System32\drivers\etc\hosts"
    $content = Get-Content $hosts -ErrorAction SilentlyContinue
    $pattern = "^\s*$([regex]::Escape($Ip))\s+$([regex]::Escape($Hostname))\s*$"
    if ($content | Where-Object { $_ -match $pattern }) {
        Write-Log "Hosts already has $Hostname -> $Ip" 'INFO'
        return
    }
    Add-Content -Path $hosts -Value "`r`n$Ip`t$Hostname" -Encoding ASCII
    Write-Log "Hosts: $Hostname -> $Ip" 'OK'
}
#endregion


#region Disable-Defender
function Disable-ScambaitDefender {
    Write-Log 'Disabling Windows Defender (persistent)...' 'INFO'

    # Tamper Protection blocks many of these; try anyway and also use Defender preferences where available
    try {
        Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue
        Set-MpPreference -DisableBehaviorMonitoring $true -ErrorAction SilentlyContinue
        Set-MpPreference -DisableBlockAtFirstSeen $true -ErrorAction SilentlyContinue
        Set-MpPreference -DisableIOAVProtection $true -ErrorAction SilentlyContinue
        Set-MpPreference -DisablePrivacyMode $true -ErrorAction SilentlyContinue
        Set-MpPreference -SignatureDisableUpdateOnStartupWithoutEngine $true -ErrorAction SilentlyContinue
        Set-MpPreference -DisableArchiveScanning $true -ErrorAction SilentlyContinue
        Set-MpPreference -DisableIntrusionPreventionSystem $true -ErrorAction SilentlyContinue
        Set-MpPreference -DisableScriptScanning $true -ErrorAction SilentlyContinue
        Set-MpPreference -SubmitSamplesConsent 2 -ErrorAction SilentlyContinue
        Set-MpPreference -MAPSReporting 0 -ErrorAction SilentlyContinue
        Set-MpPreference -HighThreatDefaultAction 6 -ErrorAction SilentlyContinue
        Set-MpPreference -ModerateThreatDefaultAction 6 -ErrorAction SilentlyContinue
        Set-MpPreference -LowThreatDefaultAction 6 -ErrorAction SilentlyContinue
        Set-MpPreference -SevereThreatDefaultAction 6 -ErrorAction SilentlyContinue
    }
    catch {
        Write-Log "Set-MpPreference partially failed (Tamper Protection?): $($_.Exception.Message)" 'WARN'
    }

    $pol = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender'
    Set-RegistryValue -Path $pol -Name 'DisableAntiSpyware' -Value 1
    Set-RegistryValue -Path $pol -Name 'DisableAntiVirus' -Value 1
    Set-RegistryValue -Path "$pol\Real-Time Protection" -Name 'DisableRealtimeMonitoring' -Value 1
    Set-RegistryValue -Path "$pol\Real-Time Protection" -Name 'DisableBehaviorMonitoring' -Value 1
    Set-RegistryValue -Path "$pol\Real-Time Protection" -Name 'DisableOnAccessProtection' -Value 1
    Set-RegistryValue -Path "$pol\Real-Time Protection" -Name 'DisableScanOnRealtimeEnable' -Value 1
    Set-RegistryValue -Path "$pol\Spynet" -Name 'SpynetReporting' -Value 0
    Set-RegistryValue -Path "$pol\Spynet" -Name 'SubmitSamplesConsent' -Value 2
    Set-RegistryValue -Path "$pol\Signature Updates" -Name 'ForceUpdateFromMU' -Value 0
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Notifications' -Name 'DisableNotifications' -Value 1

    # Soft-disable services (hard delete often breaks Windows)
    foreach ($svc in @(
        'WinDefend', 'WdNisSvc', 'Sense', 'SecurityHealthService', 'wscsvc'
    )) {
        Stop-ServiceSafe $svc
        try {
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$svc" -Name Start -Value 4 -Force -ErrorAction SilentlyContinue
        }
        catch {}
    }

    # Scheduled scans
    Get-ScheduledTask -TaskPath '\Microsoft\Windows\Windows Defender\' -ErrorAction SilentlyContinue |
        ForEach-Object { Disable-ScheduledTask -TaskName $_.TaskName -TaskPath $_.TaskPath -ErrorAction SilentlyContinue }

    Write-Log 'Defender policy keys written. If Tamper Protection is on, turn it off in Windows Security once, then re-run this step.' 'WARN'
}
#endregion


#region Disable-WindowsUpdate
function Disable-ScambaitWindowsUpdate {
    Write-Log 'Disabling Windows Update...' 'INFO'

    Stop-ServiceSafe 'wuauserv'
    Stop-ServiceSafe 'UsoSvc'
    Stop-ServiceSafe 'WaaSMedicSvc'
    Stop-ServiceSafe 'bits'
    Stop-ServiceSafe 'DoSvc'

    foreach ($svc in @('wuauserv', 'UsoSvc', 'WaaSMedicSvc', 'DoSvc')) {
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$svc" -Name Start -Value 4 -Force -ErrorAction SilentlyContinue
    }

    $au = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
    Set-RegistryValue -Path $au -Name 'NoAutoUpdate' -Value 1
    Set-RegistryValue -Path $au -Name 'AUOptions' -Value 1
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' -Name 'DoNotConnectToWindowsUpdateInternetLocations' -Value 1
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update' -Name 'AUOptions' -Value 1

    # Block update endpoints via hosts (belt and suspenders)
    $blockHosts = @(
        'windowsupdate.microsoft.com'
        'update.microsoft.com'
        'download.windowsupdate.com'
        'wustat.windows.com'
        'ntservicepack.microsoft.com'
    )
    foreach ($h in $blockHosts) {
        Add-HostsEntry -Ip '127.0.0.1' -Hostname $h
    }

    Get-ScheduledTask | Where-Object {
        $_.TaskName -match 'Update|WindowsUpdate|Scheduled Start|USO' -and
        $_.TaskPath -match 'WindowsUpdate|UpdateOrchestrator'
    } | ForEach-Object {
        Disable-ScheduledTask -TaskName $_.TaskName -TaskPath $_.TaskPath -ErrorAction SilentlyContinue
    }

    Write-Log 'Windows Update disabled' 'OK'
}
#endregion


#region Disable-Telemetry
function Disable-ScambaitTelemetry {
    Write-Log 'Disabling Windows 10 telemetry / privacy noise...' 'INFO'

    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Name 'AllowTelemetry' -Value 0
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection' -Name 'AllowTelemetry' -Value 0
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat' -Name 'AITEnable' -Value 0
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat' -Name 'DisableInventory' -Value 1
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat' -Name 'DisableUAR' -Value 1
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\TabletPC' -Name 'PreventHandwritingDataSharing' -Value 1
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors' -Name 'DisableLocation' -Value 1
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors' -Name 'DisableSensors' -Value 1
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Name 'AllowCortana' -Value 0
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds' -Name 'EnableFeeds' -Value 0
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo' -Name 'Enabled' -Value 0
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Input\TIPC' -Name 'Enabled' -Value 0
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy' -Name 'TailoredExperiencesWithDiagnosticDataEnabled' -Value 0
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Name 'PublishUserActivities' -Value 0
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Name 'UploadUserActivities' -Value 0
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows' -Name 'CEIPEnable' -Value 0
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Name 'DisableWindowsConsumerFeatures' -Value 1
    Set-RegistryValue -Path 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Name 'DisableTailoredExperiencesWithDiagnosticData' -Value 1
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo' -Name 'DisabledByGroupPolicy' -Value 1

    foreach ($svc in @('DiagTrack', 'dmwappushservice', 'WerSvc', 'PcaSvc')) {
        Stop-ServiceSafe $svc
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$svc" -Name Start -Value 4 -Force -ErrorAction SilentlyContinue
    }

    # Compatibility telemetry tasks
    @(
        @{ Path = '\Microsoft\Windows\Application Experience\'; Name = 'Microsoft Compatibility Appraiser' }
        @{ Path = '\Microsoft\Windows\Application Experience\'; Name = 'ProgramDataUpdater' }
        @{ Path = '\Microsoft\Windows\Customer Experience Improvement Program\'; Name = 'Consolidator' }
        @{ Path = '\Microsoft\Windows\Customer Experience Improvement Program\'; Name = 'UsbCeip' }
        @{ Path = '\Microsoft\Windows\DiskDiagnostic\'; Name = 'Microsoft-Windows-DiskDiagnosticDataCollector' }
    ) | ForEach-Object {
        Disable-ScheduledTask -TaskPath $_.Path -TaskName $_.Name -ErrorAction SilentlyContinue
    }

    Write-Log 'Telemetry disabled' 'OK'
}
#endregion


#region Mask-VmArtifacts
function Mask-ScambaitVmArtifacts {
    Write-Log 'Applying guest-side VM masking (registry / ACPI-visible strings where possible)...' 'INFO'
    Write-Log 'True BIOS/OEM strings for msinfo32 require host SMBIOS - see host\proxmox-smbios.conf' 'WARN'

    # Hide Hypervisor-present bit from some naive checks (does not fool everything)
    Set-RegistryValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment' -Name 'PROCESSOR_IDENTIFIER' -Value 'Intel64 Family 6 Model 158 Stepping 10, GenuineIntel' -Type ([Microsoft.Win32.RegistryValueKind]::String)

    # OEM info shown in System Properties
    $oem = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation'
    Set-RegistryValue -Path $oem -Name 'Manufacturer' -Value 'Dell Inc.' -Type ([Microsoft.Win32.RegistryValueKind]::String)
    Set-RegistryValue -Path $oem -Name 'Model' -Value 'OptiPlex 7070' -Type ([Microsoft.Win32.RegistryValueKind]::String)
    Set-RegistryValue -Path $oem -Name 'SupportURL' -Value 'https://www.dell.com/support' -Type ([Microsoft.Win32.RegistryValueKind]::String)
    Set-RegistryValue -Path $oem -Name 'SupportPhone' -Value '1-800-999-3355' -Type ([Microsoft.Win32.RegistryValueKind]::String)

    # Computer description
    Set-RegistryValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters' -Name 'srvcomment' -Value "$($script:Config.Persona.FullName) PC" -Type ([Microsoft.Win32.RegistryValueKind]::String)
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName' -Name 'ComputerName' -Value $script:Config.Persona.ComputerName -ErrorAction SilentlyContinue

    # Remove common VM tools shortcuts / leftover folders if present
    $junk = @(
        "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\QEMU*",
        "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\VirtIO*",
        "$env:Public\Desktop\*QEMU*",
        "$env:Public\Desktop\*VirtIO*"
    )
    foreach ($pattern in $junk) {
        Get-Item $pattern -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
    }

    # Prefer SCSI/IDE-looking disk labels in Explorer where possible
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' -Name 'ShowDriveLettersFirst' -Value 0

    # Disable some VM-detection friendly WMI noise by renaming Win32_ComputerSystem model via registry OEM (already set)
    # Block known guest-agent executables from easy discovery by renaming if present
    $gaPaths = @(
        'C:\Program Files\Qemu-ga',
        'C:\Program Files (x86)\Qemu-ga',
        'C:\Program Files\Virtio-Win'
    )
    foreach ($p in $gaPaths) {
        if (Test-Path $p) {
            $dest = $p -replace 'Qemu-ga', 'IntelMEI' -replace 'Virtio-Win', 'IntelChipset'
            if ($dest -ne $p -and -not (Test-Path $dest)) {
                try {
                    Rename-Item -Path $p -NewName (Split-Path $dest -Leaf) -ErrorAction Stop
                    Write-Log "Renamed folder $p -> $dest" 'OK'
                }
                catch {
                    Write-Log "Could not rename $p (in use?): $($_.Exception.Message)" 'WARN'
                }
            }
        }
    }

    Write-Log 'Guest-side masking applied' 'OK'
}
#endregion


#region Rename-Devices
function Rename-ScambaitDevices {
    Write-Log 'Renaming Device Manager friendly names (registry)...' 'INFO'
    Write-Log 'A reboot (or device restart) may be needed for all names to refresh in Device Manager.' 'WARN'

    $renames = $script:Config.DeviceRenames
    $enumRoots = @(
        'HKLM:\SYSTEM\CurrentControlSet\Enum'
    )

    $changed = 0
    foreach ($root in $enumRoots) {
        Get-ChildItem -Path $root -Recurse -ErrorAction SilentlyContinue |
            Where-Object {
                $_.PSChildName -eq 'Device Parameters' -or
                (Get-ItemProperty -Path $_.PSPath -Name 'FriendlyName' -ErrorAction SilentlyContinue)
            } |
            ForEach-Object {
                $key = $_.PSPath
                # FriendlyName lives on the device instance key, not Device Parameters
            }

        # Walk device instance keys more carefully
        Get-ChildItem -Path $root -ErrorAction SilentlyContinue | ForEach-Object {
            Get-ChildItem -Path $_.PSPath -ErrorAction SilentlyContinue | ForEach-Object {
                Get-ChildItem -Path $_.PSPath -ErrorAction SilentlyContinue | ForEach-Object {
                    $inst = $_.PSPath
                    $props = Get-ItemProperty -Path $inst -ErrorAction SilentlyContinue
                    if (-not $props) { return }
                    $current = $props.FriendlyName
                    if (-not $current) { $current = $props.DeviceDesc }
                    if (-not $current) { return }

                    foreach ($rule in $renames) {
                        if ($current -like "*$($rule.Match)*") {
                            # Make name unique-ish per instance to avoid collisions
                            $suffix = ''
                            if ($props.HardwareID) {
                                $hid = @($props.HardwareID)[0]
                                if ($hid -match 'VEN_([0-9A-Fa-f]+)&DEV_([0-9A-Fa-f]+)') {
                                    $suffix = " ($($Matches[2]))"
                                }
                            }
                            $newName = "$($rule.NewName)$suffix"
                            try {
                                Set-ItemProperty -Path $inst -Name 'FriendlyName' -Value $newName -Force
                                Write-Log "Renamed: '$current' -> '$newName'" 'OK'
                                $changed++
                            }
                            catch {
                                Write-Log "Failed rename on $inst : $($_.Exception.Message)" 'WARN'
                            }
                            break
                        }
                    }
                }
            }
        }
    }

    # Also rename network adapters via NetAdapter where names scream VM
    Get-NetAdapter -ErrorAction SilentlyContinue | ForEach-Object {
        $n = $_.Name
        $ifDesc = $_.InterfaceDescription
        foreach ($rule in $renames) {
            if ($n -match $rule.Match -or $ifDesc -match $rule.Match) {
                $new = ($rule.NewName -replace '\(R\)', '').Trim()
                if ($new.Length -gt 40) { $new = $new.Substring(0, 40) }
                try {
                    Rename-NetAdapter -Name $n -NewName $new -ErrorAction Stop
                    Write-Log "Network adapter '$n' -> '$new'" 'OK'
                }
                catch {
                    Write-Log "NetAdapter rename skipped ($n): $($_.Exception.Message)" 'WARN'
                }
                break
            }
        }
    }

    Write-Log "Device rename pass complete ($changed FriendlyName changes)" 'OK'
}
#endregion


#region Disguise-QemuAgent
function Disguise-ScambaitQemuAgent {
    Write-Log 'Disguising QEMU Guest Agent service / binaries...' 'INFO'
    $cfg = $script:Config.QemuGuestAgent

    $svcNames = @($cfg.ServiceName, 'qemu-ga', 'QEMU Guest Agent', 'QEMU-GA')
    $found = $null
    foreach ($n in $svcNames) {
        $s = Get-Service -Name $n -ErrorAction SilentlyContinue
        if ($s) { $found = $s; break }
    }
    # WMI fallback by display name
    if (-not $found) {
        $found = Get-CimInstance Win32_Service -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match 'qemu|guest.?agent' -or $_.DisplayName -match 'QEMU|Guest Agent' } |
            Select-Object -First 1
    }

    if (-not $found) {
        Write-Log 'QEMU Guest Agent service not found (already removed or never installed).' 'WARN'
    }
    else {
        $svcName = if ($found.Name) { $found.Name } else { $found.ServiceName }
        Write-Log "Found guest agent service: $svcName" 'INFO'
        Stop-Service -Name $svcName -Force -ErrorAction SilentlyContinue

        $reg = "HKLM:\SYSTEM\CurrentControlSet\Services\$svcName"
        if (Test-Path $reg) {
            Set-ItemProperty -Path $reg -Name 'DisplayName' -Value $cfg.DisguisedDisplay -Force
            Set-ItemProperty -Path $reg -Name 'Description' -Value $cfg.DisguisedDesc -Force
            if ($cfg.HideFromServices) {
                # Start=4 disabled; keeps scammers from seeing a running "QEMU" service
                Set-ItemProperty -Path $reg -Name 'Start' -Value 4 -Force
            }
            Write-Log "Service display renamed to '$($cfg.DisguisedDisplay)' and disabled" 'OK'
        }

        # Rename ImagePath binary if present
        $img = (Get-ItemProperty -Path $reg -ErrorAction SilentlyContinue).ImagePath
        if ($img) {
            $exe = ($img -replace '^"|"$', '' -split ' ')[0]
            if (Test-Path $exe) {
                $dir = Split-Path $exe -Parent
                $newExe = Join-Path $dir 'IntelMEI.exe'
                try {
                    if (-not (Test-Path $newExe)) {
                        Copy-Item $exe $newExe -Force
                        # Point service at copy (keep original in case of rollback)
                        $newImg = $img -replace [regex]::Escape($exe), $newExe
                        Set-ItemProperty -Path $reg -Name 'ImagePath' -Value $newImg -Force
                        Write-Log "Service binary mirrored as IntelMEI.exe" 'OK'
                    }
                }
                catch {
                    Write-Log "Could not mirror agent binary: $($_.Exception.Message)" 'WARN'
                }
            }
        }
    }

    # Kill leftover processes with qemu in the name
    Get-Process -ErrorAction SilentlyContinue | Where-Object {
        $_.ProcessName -match 'qemu|virtio|spice'
    } | ForEach-Object {
        try {
            Stop-Process -Id $_.Id -Force -ErrorAction Stop
            Write-Log "Stopped process $($_.ProcessName)" 'OK'
        }
        catch {
            Write-Log "Could not stop $($_.ProcessName): $($_.Exception.Message)" 'WARN'
        }
    }

    # Hide qemu-ga from Task Manager details via Image File Execution Options is too aggressive;
    # instead remove Start Menu / uninstall entries that mention QEMU
    $uninstallRoots = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    foreach ($root in $uninstallRoots) {
        Get-ItemProperty $root -ErrorAction SilentlyContinue | Where-Object {
            $_.DisplayName -match 'QEMU|VirtIO Guest|Guest Agent'
        } | ForEach-Object {
            $key = $_.PSPath
            Set-ItemProperty -Path $key -Name 'DisplayName' -Value $cfg.DisguisedDisplay -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $key -Name 'Publisher' -Value 'Intel Corporation' -Force -ErrorAction SilentlyContinue
            Write-Log "Uninstall entry disguised: $($_.DisplayName)" 'OK'
        }
    }

    Write-Log 'QEMU guest agent disguise complete' 'OK'
}
#endregion


#region Add-FakePrinter
function Add-ScambaitFakePrinter {
    Write-Log 'Adding fake printer for printer-support bait...' 'INFO'
    $p = $script:Config.FakePrinter

    $existing = Get-Printer -Name $p.Name -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Log "Printer already exists: $($p.Name)" 'INFO'
        return
    }

    # Ensure a local port exists
    $port = Get-PrinterPort -Name $p.Port -ErrorAction SilentlyContinue
    if (-not $port) {
        try {
            Add-PrinterPort -Name $p.Port -ErrorAction Stop
        }
        catch {
            # LPT1 usually exists; FILE: is a good fallback
            $p.Port = 'FILE:'
            Write-Log "Using FILE: port instead ($($_.Exception.Message))" 'WARN'
        }
    }

    # Prefer a built-in driver that always exists
    $driverCandidates = @(
        $p.Driver
        'Microsoft IPP Class Driver'
        'Microsoft Print To PDF'
        'Generic / Text Only'
    )

    $driver = $null
    foreach ($d in $driverCandidates) {
        if (Get-PrinterDriver -Name $d -ErrorAction SilentlyContinue) {
            $driver = $d
            break
        }
    }

    if (-not $driver) {
        Write-Log 'No suitable printer driver found; installing Generic / Text Only via printui...' 'WARN'
        rundll32 printui.dll,PrintUIEntry /ia /m "Generic / Text Only" /h "x64" /v "Type 3 - User Mode" 2>$null
        Start-Sleep 2
        $driver = 'Generic / Text Only'
    }

    try {
        Add-Printer -Name $p.Name -DriverName $driver -PortName $p.Port -ErrorAction Stop
        Write-Log "Printer added: $($p.Name) ($driver on $($p.Port))" 'OK'
    }
    catch {
        # Last resort: PDF printer renamed
        try {
            Add-Printer -Name $p.Name -DriverName 'Microsoft Print To PDF' -PortName 'PORTPROMPT:' -ErrorAction Stop
            Write-Log "Printer added via Print to PDF driver: $($p.Name)" 'OK'
        }
        catch {
            Write-Log "Failed to add printer: $($_.Exception.Message)" 'ERROR'
        }
    }

    # Create a "broken printer" sticky note vibe - set as default and pause
    try {
        $printer = Get-Printer -Name $p.Name -ErrorAction Stop
        Set-Printer -Name $p.Name -Comment 'Offline - paper jam in tray 2' -ErrorAction SilentlyContinue
        rundll32 printui.dll,PrintUIEntry /y /n $p.Name 2>$null
        # Pause printing to simulate problems
        $printer | Set-Printer -ErrorAction SilentlyContinue
        Get-WmiObject -Class Win32_Printer -Filter "Name='$($p.Name)'" | ForEach-Object {
            $_.Pause() | Out-Null
        }
        Write-Log 'Printer paused with paper-jam comment (good for support scams)' 'OK'
    }
    catch {
        Write-Log "Could not pause printer: $($_.Exception.Message)" 'WARN'
    }
}
#endregion


#region Setup-CameraLoop
function Setup-ScambaitCameraLoop {
    Write-Log 'Setting up webcam loop bait...' 'INFO'

    $videoRel = $script:Config.Paths.CameraVideo
    $video = Get-AssetPath $videoRel
    $destDir = Join-Path $env:USERPROFILE 'Videos\WebcamBait'
    Ensure-Dir $destDir
    $destVideo = Join-Path $destDir 'webcam_loop.mp4'

    if (Test-Path $video) {
        Copy-Item $video $destVideo -Force
        Write-Log "Copied camera loop video to $destVideo" 'OK'
    }
    else {
        Write-Log "Place an old-man webcam loop MP4 at: $video" 'WARN'
        Write-Log 'Creating placeholder readme instead.' 'WARN'
        @"
Place webcam_loop.mp4 here (or in assets\camera\webcam_loop.mp4 before running the installer).

Recommended setup for Camera app bait:
1. Install OBS Studio (winget: OBSProject.OBSStudio) OR ManyCam / SplitCam.
2. Add a Media Source pointing at this MP4, set to loop.
3. Start Virtual Camera in OBS.
4. In Windows Settings > Privacy > Camera, allow desktop apps.
5. In the Camera app, pick the OBS Virtual Camera as the device.

When a scammer opens Camera, they see the looped elderly face instead of you.
"@ | Set-Content (Join-Path $destDir 'README.txt') -Encoding UTF8
    }

    # Try to install OBS for virtual camera if winget available
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Log 'Installing OBS Studio for virtual camera...' 'INFO'
        winget install --id OBSProject.OBSStudio -e --accept-source-agreements --accept-package-agreements --silent 2>&1 | Out-Null
    }

    # Drop helper script (VLC loop fallback; prefer OBS Virtual Camera for Camera app)
    $helper = Join-Path $destDir 'Start-WebcamLoop.ps1'
    $helperLines = @(
        '# Opens bait video looping in VLC (fallback). Prefer OBS Virtual Camera for Camera app.'
        "`$video = '$destVideo'"
        'if (-not (Test-Path $video)) { throw "Missing $video" }'
        "`$vlc1 = Join-Path `$env:ProgramFiles 'VideoLAN\VLC\vlc.exe'"
        "`$vlc2 = Join-Path `${env:ProgramFiles(x86)} 'VideoLAN\VLC\vlc.exe'"
        'if (Test-Path $vlc1) { Start-Process $vlc1 -ArgumentList "--loop","--fullscreen","--no-video-title-show",$video }'
        'elseif (Test-Path $vlc2) { Start-Process $vlc2 -ArgumentList "--loop","--fullscreen","--no-video-title-show",$video }'
        'else { Start-Process $video }'
    )
    Set-Content -Path $helper -Value $helperLines -Encoding UTF8

    # Desktop shortcut
    $shell = New-Object -ComObject WScript.Shell
    $lnk = $shell.CreateShortcut((Join-Path $env:USERPROFILE 'Desktop\Webcam Loop.lnk'))
    $lnk.TargetPath = 'powershell.exe'
    $lnk.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$helper`""
    $lnk.WorkingDirectory = $destDir
    $lnk.IconLocation = 'shell32.dll,127'
    $lnk.Save()

    Write-Log 'Camera loop helpers installed. Add webcam_loop.mp4 and configure OBS Virtual Camera for Camera-app bait.' 'WARN'
}
#endregion


#region Install-Programs
function Install-ScambaitPrograms {
    Write-Log 'Installing common desktop programs via winget...' 'INFO'

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Log 'winget not found. Install App Installer from Microsoft Store, then re-run.' 'ERROR'
        return
    }

    winget source update 2>&1 | Out-Null

    foreach ($pkg in $script:Config.WingetPackages) {
        if ($script:Config.SkipWingetIds -contains $pkg.Id) {
            Write-Log "Skipping $($pkg.Name) ($($pkg.Id))" 'WARN'
            continue
        }
        Write-Log "Installing $($pkg.Name)..." 'INFO'
        $out = winget install --id $pkg.Id -e --accept-source-agreements --accept-package-agreements --silent 2>&1 |
            Out-String
        if ($LASTEXITCODE -eq 0 -or $out -match 'already installed|No available upgrade') {
            Write-Log "OK: $($pkg.Name)" 'OK'
        }
        else {
            Write-Log "winget issue for $($pkg.Name): $out" 'WARN'
        }
    }

    # Pin a few Start Menu feel-good items by creating Desktop shortcuts if missing
    $targets = @(
        @{ Name = 'Google Chrome'; Path = "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe" }
        @{ Name = 'VLC media player'; Path = "${env:ProgramFiles}\VideoLAN\VLC\vlc.exe" }
    )
    $shell = New-Object -ComObject WScript.Shell
    foreach ($t in $targets) {
        if (Test-Path $t.Path) {
            $lnkPath = Join-Path $env:PUBLIC "Desktop\$($t.Name).lnk"
            if (-not (Test-Path $lnkPath)) {
                $lnk = $shell.CreateShortcut($lnkPath)
                $lnk.TargetPath = $t.Path
                $lnk.Save()
            }
        }
    }

    Write-Log 'Program install pass finished' 'OK'
}
#endregion


#region Seed-ChromeHistory
function Seed-ScambaitChromeHistory {
    Write-Log 'Seeding believable Chrome history...' 'INFO'

    # Close Chrome
    Get-Process chrome -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep 2

    $chromeUser = Join-Path $env:LOCALAPPDATA 'Google\Chrome\User Data\Default'
    Ensure-Dir $chromeUser
    $historyDb = Join-Path $chromeUser 'History'

    # Ensure Chrome has been launched once so schema exists; if not, create minimal DB
    $chromeExe = "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe"
    if (-not (Test-Path $historyDb)) {
        if (Test-Path $chromeExe) {
            Write-Log 'Launching Chrome once to create profile...' 'INFO'
            Start-Process $chromeExe -ArgumentList '--no-first-run', '--no-default-browser-check', 'about:blank'
            Start-Sleep 5
            Get-Process chrome -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
            Start-Sleep 2
        }
    }

    $urls = @(
        @{ u = 'https://www.google.com/'; t = 'Google' }
        @{ u = 'https://mail.google.com/'; t = 'Gmail' }
        @{ u = 'https://www.facebook.com/'; t = 'Facebook' }
        @{ u = 'https://www.amazon.com/'; t = 'Amazon.com' }
        @{ u = 'https://www.amazon.com/gp/css/order-history'; t = 'Your Orders' }
        @{ u = 'https://www.ebay.com/'; t = 'eBay' }
        @{ u = 'https://www.youtube.com/'; t = 'YouTube' }
        @{ u = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'; t = 'Rick Astley - Never Gonna Give You Up' } # easter egg
        @{ u = 'https://news.yahoo.com/'; t = 'Yahoo News' }
        @{ u = 'https://www.msn.com/'; t = 'MSN' }
        @{ u = 'https://weather.com/'; t = 'Weather' }
        @{ u = 'https://www.webmd.com/'; t = 'WebMD' }
        @{ u = 'https://www.mayoclinic.org/'; t = 'Mayo Clinic' }
        @{ u = 'https://www.irs.gov/'; t = 'IRS.gov' }
        @{ u = 'https://www.ssa.gov/'; t = 'Social Security' }
        @{ u = 'https://www.aarp.org/'; t = 'AARP' }
        @{ u = 'https://www.walmart.com/'; t = 'Walmart' }
        @{ u = 'https://www.walgreens.com/'; t = 'Walgreens' }
        @{ u = 'https://www.cvs.com/'; t = 'CVS Pharmacy' }
        @{ u = 'https://www.craigslist.org/'; t = 'Craigslist' }
        @{ u = 'https://www.paypal.com/'; t = 'PayPal' }
        @{ u = "https://www.$($script:Config.Persona.BankDomain)/"; t = $script:Config.Persona.BankName }
        @{ u = 'https://www.chase.com/'; t = 'Chase.com' }
        @{ u = 'https://www.bankofamerica.com/'; t = 'Bank of America' }
        @{ u = 'https://www.netflix.com/'; t = 'Netflix' }
        @{ u = 'https://www.hulu.com/'; t = 'Hulu' }
        @{ u = 'https://www.pinterest.com/'; t = 'Pinterest' }
        @{ u = 'https://www.reddit.com/'; t = 'Reddit' }
        @{ u = 'https://en.wikipedia.org/wiki/Main_Page'; t = 'Wikipedia' }
        @{ u = 'https://www.bbc.com/news'; t = 'BBC News' }
        @{ u = 'https://www.cnn.com/'; t = 'CNN' }
        @{ u = 'https://www.foxnews.com/'; t = 'Fox News' }
        @{ u = 'https://www.nytimes.com/'; t = 'The New York Times' }
        @{ u = 'https://www.linkedin.com/'; t = 'LinkedIn' }
        @{ u = 'https://outlook.live.com/'; t = 'Outlook' }
        @{ u = 'https://www.office.com/'; t = 'Microsoft 365' }
        @{ u = 'https://support.microsoft.com/'; t = 'Microsoft Support' }
        @{ u = 'https://www.att.com/'; t = 'AT&T' }
        @{ u = 'https://www.verizon.com/'; t = 'Verizon' }
        @{ u = 'https://www.delta.com/'; t = 'Delta Air Lines' }
        @{ u = 'https://www.expedia.com/'; t = 'Expedia' }
        @{ u = 'https://www.booking.com/'; t = 'Booking.com' }
        @{ u = 'https://www.tripadvisor.com/'; t = 'Tripadvisor' }
        @{ u = 'https://www.homedepot.com/'; t = 'The Home Depot' }
        @{ u = 'https://www.lowes.com/'; t = "Lowe's" }
        @{ u = 'https://www.costco.com/'; t = 'Costco' }
        @{ u = 'https://www.samclub.com/'; t = "Sam's Club" }
        @{ u = 'https://www.ancestry.com/'; t = 'Ancestry' }
        @{ u = 'https://www.findagrave.com/'; t = 'Find a Grave' }
        @{ u = 'https://www.whitepages.com/'; t = 'Whitepages' }
        @{ u = 'https://www.zillow.com/'; t = 'Zillow' }
        @{ u = 'https://www.realtor.com/'; t = 'Realtor.com' }
        @{ u = 'https://www.indeed.com/'; t = 'Indeed' }
        @{ u = 'https://www.craigslist.org/search/sss?query=lawn+mower'; t = 'lawn mower - craigslist' }
        @{ u = 'https://www.chicagotribune.com/'; t = 'Chicago Tribune' }
        @{ u = 'https://www.nbcsports.com/chicago/cubs'; t = 'Cubs - NBC Sports Chicago' }
        @{ u = 'https://www.chicagobears.com/'; t = 'Chicago Bears' }
        @{ u = 'https://www.weather.com/weather/today/l/60636:4:US'; t = 'Weather - Chicago 60636' }
        @{ u = 'https://www.comed.com/'; t = 'ComEd' }
        @{ u = 'https://www.cta.com/'; t = 'CTA' }
        @{ u = 'https://www.google.com/search?q=lake+michigan+fishing+report'; t = 'lake michigan fishing report - Google Search' }
        @{ u = 'https://www.google.com/search?q=how+to+fix+printer+offline'; t = 'how to fix printer offline - Google Search' }
        @{ u = 'https://www.google.com/search?q=social+security+payment+schedule'; t = 'social security payment schedule - Google Search' }
        @{ u = 'https://www.google.com/search?q=is+microsoft+support+phone+number+real'; t = 'is microsoft support phone number real - Google Search' }
        @{ u = 'https://www.google.com/search?q=vfw+hall+near+englewood+chicago'; t = 'vfw hall near englewood chicago - Google Search' }
        @{ u = 'https://www.google.com/search?q=crossword+puzzle+answers+today'; t = 'crossword puzzle answers today - Google Search' }
    )

    # Prefer System.Data.SQLite if present; else use Python; else write a seed SQL + instructions
    $sqliteDll = @(
        (Get-AssetPath 'assets\tools\System.Data.SQLite.dll')
        'C:\Windows\System32\System.Data.SQLite.dll'
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1

    $python = Get-Command python -ErrorAction SilentlyContinue
    if (-not $python) { $python = Get-Command py -ErrorAction SilentlyContinue }

    if ($python) {
        $seedPy = Join-Path $env:TEMP 'seed_chrome_history.py'
        $json = ($urls | ConvertTo-Json -Compress)
        $jsonPath = Join-Path $env:TEMP 'chrome_urls.json'
        # PowerShell ConvertTo-Json on array of hashtables with short keys
        $urls | ConvertTo-Json | Set-Content $jsonPath -Encoding UTF8

        @"
import json, os, sqlite3, time, random
hist = r'''$historyDb'''
urls = json.load(open(r'''$jsonPath''', encoding='utf-8'))
os.makedirs(os.path.dirname(hist), exist_ok=True)
conn = sqlite3.connect(hist)
c = conn.cursor()
c.executescript('''
CREATE TABLE IF NOT EXISTS urls(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  url LONGVARCHAR,
  title LONGVARCHAR,
  visit_count INTEGER DEFAULT 0,
  typed_count INTEGER DEFAULT 0,
  last_visit_time INTEGER NOT NULL,
  hidden INTEGER DEFAULT 0
);
CREATE TABLE IF NOT EXISTS visits(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  url INTEGER NOT NULL,
  visit_time INTEGER NOT NULL,
  from_visit INTEGER,
  transition INTEGER DEFAULT 0,
  segment_id INTEGER,
  visit_duration INTEGER DEFAULT 0,
  incremented_omnibox_typed_score BOOLEAN DEFAULT FALSE
);
''')
# Chrome epoch: microseconds since 1601-01-01
def chrome_time(days_ago, hour=12):
    # approximate: unix + 11644473600 seconds, * 1e6
    import datetime
    dt = datetime.datetime.utcnow() - datetime.timedelta(days=days_ago, hours=random.randint(0,5))
    unix = time.mktime(dt.timetuple())
    return int((unix + 11644473600) * 1000000)

for i, row in enumerate(urls):
    u = row.get('u') or row.get('url')
    t = row.get('t') or row.get('title') or u
    visits = random.randint(1, 18)
    last = chrome_time(random.randint(0, 120))
    c.execute('INSERT INTO urls(url,title,visit_count,typed_count,last_visit_time,hidden) VALUES (?,?,?,?,?,0)',
              (u, t, visits, random.randint(0,3), last))
    uid = c.lastrowid
    for v in range(visits):
        c.execute('INSERT INTO visits(url,visit_time,from_visit,transition,visit_duration) VALUES (?,?,NULL,805306368,?)',
                  (uid, chrome_time(random.randint(0,120)), random.randint(5000,300000)))
conn.commit()
conn.close()
print('seeded', len(urls), 'urls')
"@ | Set-Content $seedPy -Encoding UTF8

        & $python.Source $seedPy
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Chrome history seeded ($($urls.Count) URLs)" 'OK'
        }
        else {
            Write-Log 'Python seed failed; writing fallback bookmark HTML' 'WARN'
            Export-ChromeBookmarkFallback -Urls $urls
        }
    }
    else {
        Write-Log 'Python not found - writing Bookmarks + History seed HTML fallback' 'WARN'
        Export-ChromeBookmarkFallback -Urls $urls
    }

    # Also write a bookmarks file Chrome will pick up if History seed fails
    $bmPath = Join-Path $chromeUser 'Bookmarks'
    if (-not (Test-Path $bmPath)) {
        $children = foreach ($row in $urls | Select-Object -First 25) {
            @{
                type = 'url'
                name = $row.t
                url  = $row.u
                date_added = '13300000000000000'
            }
        }
        $bookmarks = @{
            roots = @{
                bookmark_bar = @{
                    children = @($children)
                    name = 'Bookmarks bar'
                    type = 'folder'
                }
                other = @{ children = @(); name = 'Other bookmarks'; type = 'folder' }
                synced = @{ children = @(); name = 'Mobile bookmarks'; type = 'folder' }
            }
            version = 1
        }
        $bookmarks | ConvertTo-Json -Depth 8 | Set-Content $bmPath -Encoding UTF8
        Write-Log 'Chrome Bookmarks file created' 'OK'
    }
}

function Export-ChromeBookmarkFallback {
    param($Urls)
    $html = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Imported Bookmarks.html'
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('<!DOCTYPE NETSCAPE-Bookmark-file-1>')
    [void]$sb.AppendLine('<DL><p>')
    foreach ($row in $Urls) {
        [void]$sb.AppendLine("<DT><A HREF=`"$($row.u)`">$($row.t)</A>")
    }
    [void]$sb.AppendLine('</DL><p>')
    $sb.ToString() | Set-Content $html -Encoding UTF8
    Write-Log "Bookmark HTML written to $html - import via Chrome > Bookmarks > Import" 'WARN'
}
#endregion


#region Generate-PersonalFiles
function Generate-ScambaitPersonalFiles {
    Write-Log 'Generating personal files library...' 'INFO'
    $p = $script:Config.Persona
    $docs = [Environment]::GetFolderPath('MyDocuments')
    $pics = [Environment]::GetFolderPath('MyPictures')
    $desk = [Environment]::GetFolderPath('Desktop')
    $downloads = (New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path
    if (-not $downloads) { $downloads = Join-Path $env:USERPROFILE 'Downloads' }

    $dirs = @(
        (Join-Path $docs 'Taxes')
        (Join-Path $docs 'Medical')
        (Join-Path $docs 'Recipes')
        (Join-Path $docs 'Letters')
        (Join-Path $docs 'Passwords')
        (Join-Path $docs 'Family')
        (Join-Path $docs 'Banking')
        (Join-Path $pics 'Family Photos')
        (Join-Path $pics 'Vacation 2019')
        (Join-Path $pics 'Vacation 2022')
        (Join-Path $desk 'Important')
        (Join-Path $downloads 'Old Downloads')
    )
    foreach ($d in $dirs) { Ensure-Dir $d }

    # Copy any pre-bundled personal files
    $bundle = Get-AssetPath $script:Config.Paths.PersonalFiles
    if (Test-Path $bundle) {
        Copy-Item -Path (Join-Path $bundle '*') -Destination $docs -Recurse -Force -ErrorAction SilentlyContinue
    }

    $street = if ($p.Street) { $p.Street } else { '123 Main St' }
    $city = if ($p.City) { $p.City } else { 'Springfield' }
    $state = if ($p.State) { $p.State } else { 'IL' }
    $zip = if ($p.Zip) { $p.Zip } else { '62701' }
    $phone = if ($p.Phone) { $p.Phone } else { '555-0100' }
    $nick = if ($p.Nickname) { $p.Nickname } else { $p.FirstName }
    $emailPass = if ($p.EmailPassword) { $p.EmailPassword } else { 'Password123' }
    $bankUser = if ($p.BankOnlineUser) { $p.BankOnlineUser } else { $p.BankDbUser }
    $bankPass = if ($p.BankOnlinePass) { $p.BankOnlinePass } else { $p.BankDbPassword }
    $pcPass = if ($p.PcPassword) { $p.PcPassword } else { $emailPass }

    $files = @{
        (Join-Path $docs 'Taxes\2023_Tax_Notes.txt') = @"
Tax year 2023 notes - $($p.FullName)
Address: $street, $city, $state $zip
SSN last four: 0636
Refund expected: `$1,247.33
Filed with H&R Block on 63rd
Union pension 1099-R in the folder
Appointment: March 12
"@
        (Join-Path $docs 'Taxes\2024_Estimated.txt') = @"
Estimated notes
Union pension is main income
CPA: Bill Morrison 773-555-0142 (Englewood)
Keep receipts for fishing gear? probably not deductible lol
"@
        (Join-Path $docs 'Medical\Medications.txt') = @"
Daily medications - Dr. Patel (Advocate)
1. Lisinopril 10mg - morning
2. Metformin 500mg - with dinner
3. Atorvastatin 20mg - bedtime
Pharmacy: Walgreens on 55th & Ashland - Rx# 6639210
Allergy: penicillin
"@
        (Join-Path $docs 'Medical\Appointment_Card.txt') = @"
Next checkup: Dr. Anita Patel
Tuesday 10:30 AM
Bring insurance card and medication list
Phone if I forget: $phone
"@
        (Join-Path $docs 'Recipes\Meatloaf.txt') = @"
Meatloaf (the way Helen used to make it)
2 lbs ground beef
1 onion
1 cup breadcrumbs
2 eggs
ketchup on top
Bake 350 for 1 hour
Serves 6 - leftovers for the grandkids
"@
        (Join-Path $docs 'Recipes\Chili.txt') = @"
Sunday Chili - Bears game day
beans, tomatoes, beef, chili powder
Crock pot 6 hours
Cornbread on the side
"@
        (Join-Path $docs 'Letters\Letter_to_Tommy.txt') = @"
Tommy,

Tell your sister I got the photos of the kids. Lake was good last weekend - caught a couple perch.
Stop by Seeley when you can, printer is jammed again and I aint fighting with it.

Dad / $nick
"@
        (Join-Path $docs 'Letters\Alderman_Complaint_Draft.txt') = @"
To the ward office,

Street light out near $street for three weeks. Please advise.

$($p.FullName)
$phone
"@
        (Join-Path $docs 'Passwords\accounts_backup.txt') = @"
IMPORTANT - do not share (Tommy helped me write this down)
PC login: $pcPass
Email: $($p.Email) / $emailPass
Facebook: same email / NeedToCook
WiFi home: Netgear78 / Seeley60636
Router admin: admin / admin (change later!!)
Bank online: $bankUser / $bankPass
  website: www.$($p.BankDomain)
Netflix: $($p.Email) / CubsWin2024
# Easter egg for baiters: VFW locker combo is written on the back of the fishing license photo
"@
        (Join-Path $docs 'Banking\Account_Notes.txt') = @"
$($p.BankName)
Online banking: www.$($p.BankDomain)
Username: $bankUser
Checking ****0636
Savings ****1190
Routing: 071000013 (Chase Chicago area - VERIFY with bank)
Call the BRANCH if locked out - do NOT call numbers from popups
Son Tommy helps with the online stuff
"@
        (Join-Path $docs 'Family\Birthday_List.txt') = @"
Tommy (son) - July 19
Denise (daughter) - March 3
Marcus (son) - Sept 8
Emily (granddaughter) - Nov 2
Helen (wife, rest in peace) - June 14
"@
        (Join-Path $docs 'Family\Christmas_List_2024.txt') = @"
Emily - art set
the boys - fishing lure kits
Denise - soft blanket
Myself - new slippers (size 11) and Cubs cap
"@
        (Join-Path $docs 'Family\Address_Card.txt') = @"
$($p.FullName) ("$nick")
$street
$city, $state $zip
Mobile: $phone
Email: $($p.Email)
"@
        (Join-Path $desk 'Important\READ_ME_PASSWORDS.txt') = @"
Passwords are in Documents\Passwords\accounts_backup.txt
Printer jammed again - call Tommy or the kid next door
PC password is on the sticky note under the keyboard (NeedToCook)
"@
        (Join-Path $desk 'TODO.txt') = @"
- Pay ComEd bill
- Call dentist
- Fix printer (paper jam tray 2)
- Pick up bait for Lake Michigan trip
- VFW Thursday
- Backup photos to USB (Denise said to)
"@
        (Join-Path $downloads 'Old Downloads\invoice_scan_notes.txt') = @"
Scanned invoices from 2021 garage sale / old job tools
Kept for taxes
"@
        (Join-Path $docs 'Family\secret_moo_club.txt') = @"
If you found this, moo.
Scambaiter easter egg - not for the scammer's eyes unless they dig.
Wally says hi from Englewood-adjacent.
"@
    }

    foreach ($kv in $files.GetEnumerator()) {
        $dir = Split-Path $kv.Key -Parent
        Ensure-Dir $dir
        Set-Content -Path $kv.Key -Value $kv.Value -Encoding UTF8
    }

    # Simple openable HTML "documents" that look like letters / statements
    $htmlLetter = Join-Path $docs 'Letters\Insurance_Letter.html'
    @"
<html><head><meta charset='utf-8'><title>Insurance Letter</title></head>
<body style='font-family:Georgia;max-width:700px;margin:40px auto;'>
<p>Dear $($p.FullName),</p>
<p>Your homeowners policy for $street, $city, $state $zip renews on October 1. Premium: `$1,086.00 annually.</p>
<p>Please keep this for your records.</p>
<p>Sincerely,<br/>Midwest Mutual Insurance</p>
<!-- easter egg: policy number MOO-60636-WALLY -->
</body></html>
"@ | Set-Content $htmlLetter -Encoding UTF8

    # Generate tiny valid BMP thumbnails as "photos" if no real images bundled
    $photoDir = Join-Path $pics 'Family Photos'
    for ($i = 1; $i -le 12; $i++) {
        $bmp = Join-Path $photoDir ("IMG_2022_{0:D3}.bmp" -f $i)
        if (-not (Test-Path $bmp)) {
            New-MinimalBmp -Path $bmp -Width 320 -Height 240 -Seed $i
        }
    }
    for ($i = 1; $i -le 8; $i++) {
        $bmp = Join-Path (Join-Path $pics 'Vacation 2019') ("vacation_{0:D2}.bmp" -f $i)
        if (-not (Test-Path $bmp)) {
            New-MinimalBmp -Path $bmp -Width 640 -Height 480 -Seed (100 + $i)
        }
    }

    # RTF bio matching identity
    $rtf = Join-Path $docs 'Family\Walter_Bio.rtf'
    $occ = if ($p.Occupation) { $p.Occupation } else { 'Retired' }
    @"
{\rtf1\ansi\deff0
{\fonttbl{\f0 Times New Roman;}}
\f0\fs24 $($p.FullName) ("$nick")\par
$occ\par
$city, $state\par
Widower. Proud grandpa. Cubs and Bears. Fishing on Lake Michigan. VFW on Thursdays.\par
Kids help with the computer stuff.\par
}
"@ | Set-Content $rtf -Encoding ASCII

    Write-Log 'Personal files generated under Documents / Pictures / Desktop' 'OK'
}

function New-MinimalBmp {
    param([string]$Path, [int]$Width, [int]$Height, [int]$Seed)
    # 24-bit BMP, uncompressed
    $rowSize = [Math]::Ceiling(($Width * 3) / 4) * 4
    $pixelSize = $rowSize * $Height
    $fileSize = 54 + $pixelSize
    $ms = New-Object System.IO.MemoryStream
    $bw = New-Object System.IO.BinaryWriter $ms
    # BITMAPFILEHEADER
    $bw.Write([byte][char]'B'); $bw.Write([byte][char]'M')
    $bw.Write([int32]$fileSize)
    $bw.Write([int16]0); $bw.Write([int16]0)
    $bw.Write([int32]54)
    # BITMAPINFOHEADER
    $bw.Write([int32]40)
    $bw.Write([int32]$Width)
    $bw.Write([int32]$Height)
    $bw.Write([int16]1)
    $bw.Write([int16]24)
    $bw.Write([int32]0)
    $bw.Write([int32]$pixelSize)
    $bw.Write([int32]2835); $bw.Write([int32]2835)
    $bw.Write([int32]0); $bw.Write([int32]0)
    $rnd = New-Object Random $Seed
    $pad = $rowSize - ($Width * 3)
    for ($y = 0; $y -lt $Height; $y++) {
        for ($x = 0; $x -lt $Width; $x++) {
            $bw.Write([byte]$rnd.Next(40, 220))
            $bw.Write([byte]$rnd.Next(40, 220))
            $bw.Write([byte]$rnd.Next(40, 220))
        }
        for ($p = 0; $p -lt $pad; $p++) { $bw.Write([byte]0) }
    }
    $bw.Flush()
    [IO.File]::WriteAllBytes($Path, $ms.ToArray())
    $bw.Close(); $ms.Close()
}
#endregion


#region Copy-Wallpapers
function Copy-ScambaitWallpapers {
    Write-Log 'Installing wallpapers...' 'INFO'
    $src = Get-AssetPath $script:Config.Paths.Wallpapers
    $dest = Join-Path ([Environment]::GetFolderPath('MyPictures')) 'Wallpapers'
    Ensure-Dir $dest

    if (Test-Path $src) {
        $files = Get-ChildItem -Path $src -File -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.Extension -match '\.(jpe?g|png|bmp|webp)$' }
        if ($files) {
            Copy-Item $files.FullName -Destination $dest -Force
            Write-Log "Copied $($files.Count) wallpaper(s) to $dest" 'OK'
        }
        else {
            Write-Log "No wallpaper images in $src - generating placeholders" 'WARN'
            for ($i = 1; $i -le 4; $i++) {
                New-MinimalBmp -Path (Join-Path $dest "Wallpaper_$i.bmp") -Width 1920 -Height 1080 -Seed (500 + $i)
            }
        }
    }

    @"
Right-click any image in this folder and choose Set as desktop background.

Suggested: pick something boring and domestic (living room, garden, grandkids collage).
"@ | Set-Content (Join-Path $dest 'How to apply.txt') -Encoding UTF8

    # Optionally set first wallpaper
    $first = Get-ChildItem $dest -File -Include *.bmp,*.jpg,*.jpeg,*.png | Select-Object -First 1
    if ($first) {
        try {
            Add-Type @"
using System.Runtime.InteropServices;
public class Wallpaper {
  [DllImport("user32.dll", SetLastError=true)]
  public static extern bool SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@
            [Wallpaper]::SystemParametersInfo(20, 0, $first.FullName, 3) | Out-Null
            Write-Log "Desktop wallpaper set to $($first.Name)" 'OK'
        }
        catch {
            Write-Log "Could not auto-set wallpaper: $($_.Exception.Message)" 'WARN'
        }
    }
}
#endregion


#region Install-MooTools
function Install-ScambaitFuckScreenConnect {
    Write-Log 'Installing Moo.FuckScreenConnect...' 'INFO'
    $tools = Get-AssetPath $script:Config.Paths.Tools
    Ensure-Dir $tools
    $work = Join-Path $tools 'FuckScreenConnect'
    Ensure-Dir $work

    $localZip = Get-ChildItem $tools -Filter '*FuckScreenConnect*.zip' -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if (-not $localZip -and -not $script:SkipDownloads) {
        try {
            $asset = Get-GithubLatestAsset -ApiUrl $script:Config.Moo.FuckScreenConnectApi -NameMatch '\.zip$'
            $zipPath = Join-Path $tools $asset.Name
            Download-File -Url $asset.Url -OutFile $zipPath
            $localZip = Get-Item $zipPath
            Write-Log "Downloaded FSC $($asset.Tag)" 'OK'
        }
        catch {
            Write-Log "Download failed: $($_.Exception.Message). Place release zip in assets\tools\" 'ERROR'
            return
        }
    }

    if (-not $localZip) {
        Write-Log 'No FuckScreenConnect zip found. Download from https://github.com/RobotsOnDrugs/Moo.FuckScreenConnect-rs/releases' 'ERROR'
        return
    }

    Expand-ZipSafe -Zip $localZip.FullName -Dest $work

    $installPs1 = Get-ChildItem $work -Recurse -Filter 'install.ps1' | Select-Object -First 1
    if ($installPs1) {
        Write-Log "Running $($installPs1.FullName)" 'INFO'
        Push-Location $installPs1.DirectoryName
        try {
            & $installPs1.FullName
        }
        finally {
            Pop-Location
        }
        Write-Log 'FuckScreenConnect install script finished (runs as Windows service)' 'OK'
    }
    else {
        # Manual: find service exe and register
        $exe = Get-ChildItem $work -Recurse -Filter '*.exe' | Where-Object { $_.Name -match 'fsc|service|FuckScreen' } | Select-Object -First 1
        if ($exe) {
            $dest = Join-Path ${env:ProgramFiles} 'FuckScreenConnect'
            Ensure-Dir $dest
            Copy-Item (Join-Path $exe.DirectoryName '*') $dest -Recurse -Force
            Write-Log "Copied binaries to $dest - run the project's install.ps1 manually if service was not registered" 'WARN'
        }
        else {
            Write-Log 'Could not locate install.ps1 or service binary in the release archive' 'ERROR'
        }
    }
}

function Install-ScambaitNoBlockInput {
    Write-Log 'Installing Moo.NoBlockInput...' 'INFO'
    $tools = Get-AssetPath $script:Config.Paths.Tools
    Ensure-Dir $tools
    $work = Join-Path $tools 'NoBlockInput'
    Ensure-Dir $work

    $localZip = Get-ChildItem $tools -Filter '*NoBlockInput*.zip' -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $localZip) {
        $localZip = Get-ChildItem $tools -Filter '*noblock*.zip' -ErrorAction SilentlyContinue | Select-Object -First 1
    }

    if (-not $localZip -and -not $script:SkipDownloads) {
        try {
            $asset = Get-GithubLatestAsset -ApiUrl $script:Config.Moo.NoBlockInputApi -NameMatch '\.zip$'
            $zipPath = Join-Path $tools $asset.Name
            Download-File -Url $asset.Url -OutFile $zipPath
            $localZip = Get-Item $zipPath
            Write-Log "Downloaded NoBlockInput $($asset.Tag)" 'OK'
        }
        catch {
            Write-Log "Download failed: $($_.Exception.Message). Place release zip in assets\tools\" 'ERROR'
            return
        }
    }

    if (-not $localZip) {
        Write-Log 'No NoBlockInput zip found. Download from https://github.com/RobotsOnDrugs/Moo.NoBlockInput/releases' 'ERROR'
        return
    }

    Expand-ZipSafe -Zip $localZip.FullName -Dest $work

    $dest = Join-Path ${env:ProgramFiles} 'NoBlockInput'
    Ensure-Dir $dest
    Copy-Item (Join-Path $work '*') $dest -Recurse -Force

    # Find injector exe (release layouts vary)
    $injector = Get-ChildItem $dest -Recurse -Filter '*.exe' |
        Where-Object { $_.Name -match 'inject|NoBlock|nbi' } |
        Select-Object -First 1

    if (-not $injector) {
        $injector = Get-ChildItem $dest -Recurse -Filter '*.exe' | Select-Object -First 1
    }

    if ($injector) {
        # Startup shortcut so it runs at logon
        $startup = [Environment]::GetFolderPath('Startup')
        $shell = New-Object -ComObject WScript.Shell
        $lnk = $shell.CreateShortcut((Join-Path $startup 'Input Protection.lnk'))
        $lnk.TargetPath = $injector.FullName
        $lnk.WorkingDirectory = $injector.DirectoryName
        $lnk.WindowStyle = 7
        $lnk.Save()

        # Also desktop shortcut with innocuous name
        $dlnk = $shell.CreateShortcut((Join-Path ([Environment]::GetFolderPath('Desktop')) 'Input Protection.lnk'))
        $dlnk.TargetPath = $injector.FullName
        $dlnk.WorkingDirectory = $injector.DirectoryName
        $dlnk.Save()

        Write-Log "NoBlockInput staged at $dest (startup shortcut created). Review wiki config for RDS process names." 'OK'
        Write-Log 'Wiki: https://github.com/RobotsOnDrugs/Moo.NoBlockInput/wiki' 'INFO'
    }
    else {
        Write-Log 'No executable found in NoBlockInput archive' 'ERROR'
    }
}
#endregion


#region Install-Micerosoft
function Install-ScambaitMicerosoft {
    Write-Log 'Installing Micerosoft fake support popup...' 'INFO'

    $dest = Join-Path ${env:ProgramFiles} 'Micerosoft'
    Ensure-Dir $dest

    $src = Get-AssetPath $script:Config.Paths.Micerosoft
    if (Test-Path (Join-Path $src 'popup.html')) {
        Copy-Item (Join-Path $src '*') $dest -Recurse -Force
    }

    $htmlPath = Join-Path $dest 'popup.html'
    if (-not (Test-Path $htmlPath)) {
        @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8"/>
<title>Micerosoft Windows Security</title>
<style>
  html,body{margin:0;height:100%;font-family:Segoe UI,Tahoma,sans-serif;background:#0078d7;color:#fff;overflow:hidden}
  .wrap{display:flex;flex-direction:column;justify-content:center;align-items:center;height:100%;padding:40px;text-align:center}
  .logo{font-size:48px;font-weight:600;letter-spacing:1px;margin-bottom:8px}
  .logo span{opacity:.85}
  h1{font-size:28px;font-weight:400;margin:16px 0}
  p{font-size:18px;max-width:720px;line-height:1.5;opacity:.95}
  .phone{font-size:36px;font-weight:700;margin:24px 0;background:#fff;color:#0078d7;padding:12px 28px;border-radius:4px}
  .blink{animation:blink 1.2s step-start infinite}
  @keyframes blink{50%{opacity:0}}
  .bar{position:fixed;bottom:0;left:0;right:0;background:#005a9e;padding:14px;font-size:14px}
  .warn{color:#ffe066;font-weight:600}
</style>
</head>
<body>
  <div class="wrap">
    <div class="logo">Micerosoft <span>Windows</span></div>
    <h1>CRITICAL SECURITY ALERT</h1>
    <p>Your computer has reported <strong>suspicious activity</strong> and may be infected with dangerous spyware.</p>
    <p class="warn blink">Do not close this window or restart your PC.</p>
    <p>Please call Micerosoft Support immediately:</p>
    <div class="phone">1-800-555-0199</div>
    <p>A certified technician will help you remove the threat.</p>
  </div>
  <div class="bar">Windows Defender Security Center &bull; Error code: 0x800704cf &bull; Case ID: MW-$(Get-Random -Minimum 100000 -Maximum 999999)</div>
  <script>
    // Keep focus annoying for bait demos
    window.addEventListener('blur', () => setTimeout(() => window.focus(), 50));
    document.addEventListener('contextmenu', e => e.preventDefault());
    document.addEventListener('keydown', e => {
      if (e.key === 'F11') return;
      if (e.altKey || e.ctrlKey || e.key === 'F4') e.preventDefault();
    });
  </script>
</body>
</html>
"@ | Set-Content $htmlPath -Encoding UTF8
    }

    # Launcher HTA for more "popup" feel (fullscreen-ish)
    $hta = Join-Path $dest 'alert.hta'
    @"
<html>
<head>
<HTA:APPLICATION ID="MicerosoftAlert"
  APPLICATIONNAME="Windows Security"
  BORDER="none"
  CAPTION="no"
  SHOWINTASKBAR="yes"
  SINGLEINSTANCE="yes"
  WINDOWSTATE="maximize"
  SCROLL="no"
/>
<script language="VBScript">
Sub Window_OnLoad
  self.MoveTo 0,0
  self.ResizeTo screen.availWidth, screen.availHeight
End Sub
</script>
</head>
<body style="margin:0">
<iframe src="popup.html" width="100%" height="100%" frameborder="0"></iframe>
</body>
</html>
"@ | Set-Content $hta -Encoding ASCII

    # Desktop shortcut named Micerosoft (intentional misspelling)
    $shell = New-Object -ComObject WScript.Shell
    $desktop = [Environment]::GetFolderPath('Desktop')
    $lnk = $shell.CreateShortcut((Join-Path $desktop 'Micerosoft.lnk'))
    $lnk.TargetPath = 'mshta.exe'
    $lnk.Arguments = "`"$hta`""
    $lnk.WorkingDirectory = $dest
    $lnk.IconLocation = 'shell32.dll,77'
    $lnk.Description = 'Micerosoft Windows Security'
    $lnk.Save()

    # Public desktop too
    $plnk = $shell.CreateShortcut((Join-Path $env:PUBLIC 'Desktop\Micerosoft.lnk'))
    $plnk.TargetPath = 'mshta.exe'
    $plnk.Arguments = "`"$hta`""
    $plnk.IconLocation = 'shell32.dll,77'
    $plnk.Save()

    Write-Log "Micerosoft popup installed - desktop shortcut 'Micerosoft'" 'OK'
}
#endregion


#region Install-XamppDsjas
function Install-ScambaitXamppDsjas {
    Write-Log 'Installing XAMPP + DSJAS (fake bank) per guide...' 'INFO'
    $x = $script:Config.Xampp
    $persona = $script:Config.Persona
    $tools = Get-AssetPath $script:Config.Paths.Tools
    Ensure-Dir $tools

    # --- XAMPP ---
    if (-not (Test-Path (Join-Path $x.InstallDir 'xampp-control.exe'))) {
        $installer = Join-Path $tools $x.InstallerName
        $local = Get-ChildItem $tools -Filter 'xampp*.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($local) { $installer = $local.FullName }

        if (-not (Test-Path $installer) -and -not $script:SkipDownloads) {
            try {
                Download-File -Url $x.DownloadUrl -OutFile $installer
            }
            catch {
                Write-Log "XAMPP download failed: $($_.Exception.Message)" 'ERROR'
                Write-Log 'Manually download from https://www.apachefriends.org/ and place the installer in assets\tools\' 'WARN'
                return
            }
        }

        if (-not (Test-Path $installer)) {
            Write-Log 'XAMPP installer missing' 'ERROR'
            return
        }

        Write-Log 'Running XAMPP silent-ish install (may show UI on some builds)...' 'INFO'
        # XAMPP NSIS installer: /S silent, dir via /D=
        $p = Start-Process -FilePath $installer -ArgumentList '/S', "/D=$($x.InstallDir)" -Wait -PassThru
        Write-Log "XAMPP installer exit code: $($p.ExitCode)" 'INFO'
        Start-Sleep 3
    }
    else {
        Write-Log "XAMPP already present at $($x.InstallDir)" 'INFO'
    }

    if (-not (Test-Path (Join-Path $x.InstallDir 'xampp-control.exe'))) {
        Write-Log 'XAMPP does not appear installed - aborting DSJAS steps' 'ERROR'
        return
    }

    # Start Apache + MySQL
    $mysql = Join-Path $x.InstallDir 'mysql_start.bat'
    $apache = Join-Path $x.InstallDir 'apache_start.bat'
    if (Test-Path $apache) { Start-Process $apache -WindowStyle Hidden }
    if (Test-Path $mysql) { Start-Process $mysql -WindowStyle Hidden }
    Start-Sleep 5

    # Also try exe directly
    $httpd = Join-Path $x.InstallDir 'apache\bin\httpd.exe'
    $mysqld = Join-Path $x.InstallDir 'mysql\bin\mysqld.exe'
    if ((Test-Path $httpd) -and -not (Get-Process httpd -ErrorAction SilentlyContinue)) {
        Start-Process $httpd -WorkingDirectory (Split-Path $httpd) -WindowStyle Hidden
    }
    if ((Test-Path $mysqld) -and -not (Get-Process mysqld -ErrorAction SilentlyContinue)) {
        Start-Process $mysqld -ArgumentList '--defaults-file=..\..\mysql\bin\my.ini' -WorkingDirectory (Join-Path $x.InstallDir 'mysql\bin') -WindowStyle Hidden -ErrorAction SilentlyContinue
        # Fallback
        Start-Process (Join-Path $x.InstallDir 'mysql\bin\mysqld.exe') -WorkingDirectory (Join-Path $x.InstallDir 'mysql\bin') -WindowStyle Hidden -ErrorAction SilentlyContinue
    }
    Start-Sleep 4

    # Create DB + user via mysql CLI
    $mysqlCli = Join-Path $x.InstallDir 'mysql\bin\mysql.exe'
    if (Test-Path $mysqlCli) {
        $sql = @"
CREATE DATABASE IF NOT EXISTS ``$($persona.BankDbName)`` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$($persona.BankDbUser)'@'localhost' IDENTIFIED BY '$($persona.BankDbPassword)';
GRANT ALL PRIVILEGES ON *.* TO '$($persona.BankDbUser)'@'localhost';
FLUSH PRIVILEGES;
"@
        $sqlFile = Join-Path $env:TEMP 'dsjas_db.sql'
        Set-Content $sqlFile $sql -Encoding ASCII
        & $mysqlCli -u root --password= -e "source $sqlFile" 2>&1 | Out-Null
        # XAMPP root often has empty password
        & $mysqlCli -u root -e "CREATE DATABASE IF NOT EXISTS $($persona.BankDbName);" 2>&1 | Out-Null
        & $mysqlCli -u root -e "CREATE USER IF NOT EXISTS '$($persona.BankDbUser)'@'localhost' IDENTIFIED BY '$($persona.BankDbPassword)';" 2>&1 | Out-Null
        & $mysqlCli -u root -e "GRANT ALL PRIVILEGES ON *.* TO '$($persona.BankDbUser)'@'localhost'; FLUSH PRIVILEGES;" 2>&1 | Out-Null
        Write-Log "MySQL database '$($persona.BankDbName)' and user '$($persona.BankDbUser)' ensured" 'OK'
    }
    else {
        Write-Log 'mysql.exe not found - create DB manually in phpMyAdmin (see guide)' 'WARN'
    }

    # --- DSJAS ---
    $htdocs = Join-Path $x.InstallDir 'htdocs'
    $old = Join-Path $htdocs 'old'
    if (-not (Test-Path (Join-Path $htdocs 'Index.php')) -and -not (Test-Path (Join-Path $htdocs 'index.php')) -and -not (Get-ChildItem $htdocs -Filter 'Config' -ErrorAction SilentlyContinue)) {
        # Detect if DSJAS already deployed by looking for characteristic files
    }

    $dsjasMarker = @(
        (Join-Path $htdocs 'public')
        (Join-Path $htdocs 'DSJAS')
        (Join-Path $htdocs 'setup')
        (Join-Path $htdocs 'Version.json')
        (Join-Path $htdocs 'version.json')
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1

    if (-not $dsjasMarker) {
        Ensure-Dir $old
        Get-ChildItem $htdocs -Force | Where-Object { $_.Name -ne 'old' } | ForEach-Object {
            Move-Item $_.FullName -Destination $old -Force -ErrorAction SilentlyContinue
        }

        $zip = Get-ChildItem $tools -Filter '*DSJAS*.zip' -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $zip -and -not $script:SkipDownloads) {
            try {
                $asset = Get-GithubLatestAsset -ApiUrl $x.DsjasReleaseApi -NameMatch '\.zip$'
                $zipPath = Join-Path $tools $asset.Name
                Download-File -Url $asset.Url -OutFile $zipPath
                $zip = Get-Item $zipPath
                Write-Log "Downloaded DSJAS $($asset.Tag)" 'OK'
            }
            catch {
                Write-Log "DSJAS download failed: $($_.Exception.Message)" 'ERROR'
                Write-Log 'Download from https://github.com/DSJAS/DSJAS/releases into assets\tools\' 'WARN'
                return
            }
        }

        if (-not $zip) {
            Write-Log 'DSJAS zip missing' 'ERROR'
            return
        }

        $extract = Join-Path $tools 'dsjas_extract'
        if (Test-Path $extract) { Remove-Item $extract -Recurse -Force }
        Expand-ZipSafe -Zip $zip.FullName -Dest $extract

        # Zip may contain a single top-level folder
        $payload = $extract
        $top = Get-ChildItem $extract -Directory | Select-Object -First 1
        $topFiles = Get-ChildItem $extract -File | Select-Object -First 1
        if ($top -and -not $topFiles) { $payload = $top.FullName }

        Copy-Item (Join-Path $payload '*') -Destination $htdocs -Recurse -Force
        Write-Log "DSJAS files copied to $htdocs" 'OK'
    }
    else {
        Write-Log 'DSJAS appears already deployed in htdocs' 'INFO'
    }

    # Hosts file for bank domain (guide Part III - gateway IP)
    # If XAMPP runs IN the VM, use 127.0.0.1. If on host, use default gateway.
    $bankIp = '127.0.0.1'
    Write-Log "Mapping bank domain to $bankIp (XAMPP in-guest). If bank is on the host instead, change hosts to gateway IP $(Get-DefaultGatewayIPv4)." 'INFO'
    Add-HostsEntry -Ip $bankIp -Hostname $persona.BankDomain
    Add-HostsEntry -Ip $bankIp -Hostname "www.$($persona.BankDomain)"

    # Chrome insecure-origins hint file
    $flagsHint = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Chrome bank flags.txt'
    @"
To hide the Not Secure warning for your fake bank in Chrome:

1. Open chrome://flags
2. Search: insecure
3. Enable "Insecure origins treated as secure"
4. Add:
   http://$($persona.BankDomain),http://www.$($persona.BankDomain)
5. Relaunch Chrome

Bank URL: http://$($persona.BankDomain)
DB name: $($persona.BankDbName)
DB user: $($persona.BankDbUser)
DB pass: $($persona.BankDbPassword)

Complete DSJAS web setup at http://localhost if not finished:
- Copy setuptoken.txt from htdocs when prompted
- Enter DB credentials above
- Create admin: $($persona.BankAdminUser) / $($persona.BankAdminPass)
- Bank name: $($persona.BankName)
"@ | Set-Content $flagsHint -Encoding UTF8

    # Try to open setup
    Start-Process 'http://localhost/'

    Write-Log 'XAMPP + DSJAS deploy done - finish browser setup wizard if shown' 'OK'
}
#endregion

# =============================================================================
# MAIN
# =============================================================================
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run this script as Administrator.'
}

New-Item -ItemType Directory -Force -Path $script:WorkDir | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $script:WorkDir 'tools') | Out-Null
$script:Config.Paths.Tools = (Join-Path $script:WorkDir 'tools')
$script:Config.Paths.LogFile = $script:LogFile
# Prefer repo assets\ next to this script (git clone). Fallbacks stay relative for Get-AssetPath.
if (-not [IO.Path]::IsPathRooted($script:Config.Paths.CameraVideo)) {
    $script:Config.Paths.CameraVideo = Join-Path $script:Root $script:Config.Paths.CameraVideo
}
if (-not [IO.Path]::IsPathRooted($script:Config.Paths.Wallpapers)) {
    $script:Config.Paths.Wallpapers = Join-Path $script:Root $script:Config.Paths.Wallpapers
}
if (-not [IO.Path]::IsPathRooted($script:Config.Paths.PersonalFiles)) {
    $script:Config.Paths.PersonalFiles = Join-Path $script:Root $script:Config.Paths.PersonalFiles
}

Write-Log 'Scambait installer starting (single-file / Proxmox Windows 10 guest)' 'INFO'
Write-Log "Script: $PSCommandPath" 'INFO'
Write-Log "Work/temp: $script:WorkDir" 'INFO'
Write-Log "Persona: $($script:Config.Persona.FullName) / $($script:Config.Persona.ComputerName)" 'INFO'
Write-Log 'Host prerequisite: apply proxmox-smbios.conf on the Proxmox node for this VMID.' 'WARN'

Invoke-Step 'Sync GitHub / local media assets' 'SyncGitHubAssets' { Sync-ScambaitGitHubAssets }
Invoke-Step 'Disable Windows Defender' 'DisableDefender' { Disable-ScambaitDefender }
Invoke-Step 'Disable Windows Update' 'DisableWindowsUpdate' { Disable-ScambaitWindowsUpdate }
Invoke-Step 'Disable Telemetry' 'DisableTelemetry' { Disable-ScambaitTelemetry }
Invoke-Step 'Mask VM artifacts (guest-side)' 'MaskVmArtifacts' { Mask-ScambaitVmArtifacts }
Invoke-Step 'Set computer name' 'SetComputerName' {
    $name = $script:Config.Persona.ComputerName
    if ((hostname) -ne $name) {
        Rename-Computer -NewName $name -Force -ErrorAction SilentlyContinue
        Write-Log "Computer rename scheduled to '$name' (reboot required)" 'WARN'
    }
}
Invoke-Step 'Rename Device Manager entries' 'RenameDevices' { Rename-ScambaitDevices }
Invoke-Step 'Disguise QEMU Guest Agent' 'DisguiseQemuAgent' { Disguise-ScambaitQemuAgent }
Invoke-Step 'Add fake printer' 'AddFakePrinter' { Add-ScambaitFakePrinter }
Invoke-Step 'Install common programs' 'InstallPrograms' { Install-ScambaitPrograms }
Invoke-Step 'Generate personal files' 'GeneratePersonalFiles' { Generate-ScambaitPersonalFiles }
Invoke-Step 'Copy wallpapers' 'CopyWallpapers' { Copy-ScambaitWallpapers }
Invoke-Step 'Seed Chrome history' 'SeedChromeHistory' { Seed-ScambaitChromeHistory }
Invoke-Step 'Setup camera loop' 'SetupCameraLoop' { Setup-ScambaitCameraLoop }
Invoke-Step 'Install Moo.FuckScreenConnect' 'InstallFuckScreenConnect' { Install-ScambaitFuckScreenConnect }
Invoke-Step 'Install Moo.NoBlockInput' 'InstallNoBlockInput' { Install-ScambaitNoBlockInput }
Invoke-Step 'Install Micerosoft fake popup' 'InstallMicerosoftPopup' { Install-ScambaitMicerosoft }
Invoke-Step 'Install XAMPP + DSJAS' 'InstallXamppDsjas' { Install-ScambaitXamppDsjas }

Invoke-Step 'Write Proxmox host instructions to Desktop' $null {
    $desk = [Environment]::GetFolderPath('Desktop')
    $txt = Join-Path $desk 'READ_ME_PROXMOX_HOST.txt'
    @"
Apply this ON THE PROXMOX HOST (not inside Windows), then full shutdown + start the VM.

Replace 100 with your VMID:

qm set 100 -smbios1 "uuid=`$(cat /proc/sys/kernel/random/uuid),manufacturer=`$(echo -n 'Dell Inc.' | base64 -w0),product=`$(echo -n 'OptiPlex 7070' | base64 -w0),version=`$(echo -n '1.0.0' | base64 -w0),serial=`$(echo -n '5QK2R93' | base64 -w0),sku=`$(echo -n '07A1' | base64 -w0),family=`$(echo -n 'OptiPlex' | base64 -w0),base64=1"
qm set 100 -args "-cpu host,-hypervisor,kvm=off"
qm set 100 -agent 0
qm shutdown 100 && qm start 100

Or paste into /etc/pve/qemu-server/VMID.conf:
smbios1: uuid=11111111-2222-3333-4444-555555555555,manufacturer=RGVsbCBJbmMu,product=T3B0aVBsZXggNzA3MA==,version=MS4wLjA=,serial=NVFLMlI5Mw==,sku=MDdBMQ==,family=T3B0aVBsZXg=,base64=1
args: -cpu host,-hypervisor,kvm=off
agent: 0
"@ | Set-Content $txt -Encoding UTF8
    Write-Log "Wrote $txt" 'OK'
}

Write-Log 'Installer finished.' 'OK'
Write-Log 'REQUIRED on Proxmox HOST: set smbios1 + args -cpu host,-hypervisor,kvm=off for this VM (see proxmox-smbios.conf).' 'WARN'
Write-Log 'Reboot the VM, then finish DSJAS setup in the browser if prompted.' 'WARN'
Write-Log "Log: $script:LogFile" 'INFO'