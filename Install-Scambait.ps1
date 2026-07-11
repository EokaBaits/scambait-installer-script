#Requires -RunAsAdministrator
#Requires -Version 5.1
# One-file scambait setup for a Windows 10 VM on Proxmox VE.
# Edit the $Config block below, then run as Administrator:
#   Set-ExecutionPolicy Bypass -Scope Process -Force
#   .\Install-Scambait.ps1
# Optional: -SkipDownloads  -Force (re-run steps even if already completed)
# Host SMBIOS masking still must be applied on the Proxmox node (see Desktop readme).

param(
    [switch]$SkipDownloads,
    [switch]$Force
)

$ErrorActionPreference = 'Continue'
$script:Root = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $script:Root) { $script:Root = (Get-Location).Path }
$script:SkipDownloads = $SkipDownloads
$script:Force = $Force
$script:WorkDir = Join-Path $env:TEMP 'ScambaitInstall'
$script:LogFile = Join-Path $script:WorkDir 'install.log'
$script:StateDir = Join-Path $env:ProgramData 'Scambait'
$script:StatePath = Join-Path $script:StateDir 'state.json'

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

    # Discreet webcam bait: hidden feeder + virtual cam named like a real laptop camera.
    # Do NOT use OBS Studio (obvious in Task Manager / Start Menu).
    Camera = @{
        DeviceName   = 'HP HD Camera'
        InstallDir   = 'C:\Program Files\HP\HP Image Foundation'
        VideoFile    = 'assets\camera\webcam_loop.mp4'
        TaskName     = 'HP Image Foundation'
        # Unity Capture has no GitHub Releases - use master zip (Install\Install.bat)
        UnityCaptureZip = 'https://github.com/schellingb/UnityCapture/archive/refs/heads/master.zip'
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

    # Programs a 62-year-old Chicago retiree (or his kids) would plausibly install
    # Optional DownloadUrl = direct installer when winget has no package (e.g. Skype)
    WingetPackages = @(
        @{ Id = 'Google.Chrome'; Name = 'Google Chrome' }
        @{ Id = 'Adobe.Acrobat.Reader.64-bit'; Name = 'Adobe Acrobat Reader' }
        @{ Id = 'VideoLAN.VLC'; Name = 'VLC Media Player' }
        @{ Id = 'RARLab.WinRAR'; Name = 'WinRAR' }
        @{ Id = 'Zoom.Zoom'; Name = 'Zoom' }
        @{ Id = 'Microsoft.Skype'; Name = 'Skype' }
        @{ Id = 'Piriform.CCleaner'; Name = 'CCleaner'; DownloadUrl = 'https://download.ccleaner.com/ccsetup.exe'; InstallerName = 'ccsetup.exe'; SilentArgs = '/S' }
        @{ Id = 'Malwarebytes.Malwarebytes'; Name = 'Malwarebytes' }
        @{ Id = 'TheDocumentFoundation.LibreOffice'; Name = 'LibreOffice' }
        @{ Id = 'Dropbox.Dropbox'; Name = 'Dropbox' }
        @{ Id = 'Google.GoogleDrive'; Name = 'Google Drive' }
        @{ Id = 'Amazon.Kindle'; Name = 'Kindle' }
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
        # SourceForge often 403s bare links; prefer viasf=1 mirrors + portable 7z fallback
        DownloadUrls    = @(
            'https://master.dl.sourceforge.net/project/xampp/XAMPP%20Windows/8.2.12/xampp-windows-x64-8.2.12-0-VS16-installer.exe?viasf=1'
            'https://downloads.sourceforge.net/project/xampp/XAMPP%20Windows/8.2.12/xampp-windows-x64-8.2.12-0-VS16-installer.exe?viasf=1'
            'https://sourceforge.net/projects/xampp/files/XAMPP%20Windows/8.2.12/xampp-windows-x64-8.2.12-0-VS16-installer.exe/download'
        )
        PortableUrl     = 'https://master.dl.sourceforge.net/project/xampp/XAMPP%20Windows/8.2.12/xampp-windows-x64-8.2.12-0-VS16.7z?viasf=1'
        InstallerName   = 'xampp-installer.exe'
        MinBytes        = 100000000
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
        SeedDownloads            = $true
        GeneratePersonalFiles    = $true
        CopyWallpapers           = $true
        SyncGitHubAssets         = $true
        InstallFuckScreenConnect = $true
        InstallNoBlockInput      = $true
        InstallMicerosoftPopup   = $true
        InstallXamppDsjas        = $true
        MaskVmArtifacts          = $true
        SetComputerName          = $true
        SetTimezone              = $true
        SetChromeDefaults        = $true
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

function Get-ScambaitState {
    if (-not (Test-Path $script:StatePath)) {
        return @{ Completed = @{} }
    }
    try {
        $obj = Get-Content $script:StatePath -Raw -Encoding UTF8 | ConvertFrom-Json
        $map = @{}
        if ($obj.Completed) {
            $obj.Completed.PSObject.Properties | ForEach-Object { $map[$_.Name] = $_.Value }
        }
        return @{ Completed = $map }
    }
    catch {
        return @{ Completed = @{} }
    }
}

function Test-ScambaitStepDone {
    param([string]$Key)
    if ([string]::IsNullOrWhiteSpace($Key)) { return $false }
    if ($script:Force) { return $false }
    $state = Get-ScambaitState
    return [bool]$state.Completed[$Key]
}

function Set-ScambaitStepDone {
    param([string]$Key)
    if ([string]::IsNullOrWhiteSpace($Key)) { return }
    if (-not (Test-Path $script:StateDir)) {
        New-Item -ItemType Directory -Path $script:StateDir -Force | Out-Null
    }
    $state = Get-ScambaitState
    $state.Completed[$Key] = (Get-Date).ToString('o')
    $jsonObj = [ordered]@{ Completed = [ordered]@{} }
    foreach ($k in ($state.Completed.Keys | Sort-Object)) {
        $jsonObj.Completed[$k] = $state.Completed[$k]
    }
    ($jsonObj | ConvertTo-Json -Depth 5) | Set-Content $script:StatePath -Encoding UTF8
}

function Test-WingetPackageInstalled {
    param([string]$Id)
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { return $false }
    $old = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
    try {
        $out = winget list --id $Id -e --accept-source-agreements 2>&1 | Out-String
        if ($out -match [regex]::Escape($Id)) { return $true }
        # Fallback: common install paths
        switch -Regex ($Id) {
            'Google\.Chrome' { return Test-Path "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe" }
            'VideoLAN\.VLC' { return (Test-Path "${env:ProgramFiles}\VideoLAN\VLC\vlc.exe") -or (Test-Path "${env:ProgramFiles(x86)}\VideoLAN\VLC\vlc.exe") }
            'Adobe\.Acrobat' { return (Test-Path "${env:ProgramFiles}\Adobe\Acrobat DC\Acrobat\Acrobat.exe") -or (Test-Path "${env:ProgramFiles(x86)}\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe") }
            'Zoom\.Zoom' { return Test-Path "${env:ProgramFiles}\Zoom\bin\Zoom.exe" }
            'Skype|Microsoft\.Skype' { return (Test-Path "${env:ProgramFiles}\Microsoft\Skype for Desktop\Skype.exe") -or (Test-Path "${env:LOCALAPPDATA}\Microsoft\Skype for Desktop\Skype.exe") -or (Test-Path "${env:ProgramFiles(x86)}\Microsoft\Skype for Desktop\Skype.exe") }
            'RARLab\.WinRAR|WinRAR' { return (Test-Path "${env:ProgramFiles}\WinRAR\WinRAR.exe") -or (Test-Path "${env:ProgramFiles(x86)}\WinRAR\WinRAR.exe") }
            'Piriform\.CCleaner' { return Test-Path "${env:ProgramFiles}\CCleaner\CCleaner.exe" }
            'Malwarebytes' { return Test-Path "${env:ProgramFiles}\Malwarebytes\Anti-Malware\MBAMService.exe" }
            'LibreOffice' { return Test-Path "${env:ProgramFiles}\LibreOffice\program\soffice.exe" }
            'Dropbox' { return Test-Path "${env:ProgramFiles}\Dropbox\Client\Dropbox.exe" }
            'Google\.GoogleDrive|GoogleDrive' { return (Test-Path "${env:ProgramFiles}\Google\Drive File Stream\googledrivesync.exe") -or (Test-Path "${env:ProgramFiles}\Google\Drive\googledrivesync.exe") }
            'Amazon\.Kindle' { return Test-Path "${env:LOCALAPPDATA}\Amazon\Kindle\application\Kindle.exe" }
            default { return $false }
        }
    }
    finally {
        $ProgressPreference = $old
    }
}

function Invoke-Step {
    param(
        [string]$Name,
        [string]$Feature,
        [scriptblock]$Action,
        [string]$OnceKey,
        [scriptblock]$IsInstalled
    )
    if (-not [string]::IsNullOrWhiteSpace($Feature) -and -not (Test-Feature $Feature)) {
        Write-Log "Skipped (disabled in config): $Name" 'WARN'
        return
    }
    if (-not $script:Force) {
        if ($OnceKey -and (Test-ScambaitStepDone $OnceKey)) {
            Write-Log "Skipped (already completed): $Name" 'OK'
            return
        }
        if ($IsInstalled) {
            try {
                if (& $IsInstalled) {
                    Write-Log "Skipped (already installed/present): $Name" 'OK'
                    if ($OnceKey) { Set-ScambaitStepDone $OnceKey }
                    return
                }
            }
            catch {}
        }
    }
    Write-Log "=== $Name ===" 'INFO'
    try {
        & $Action
        if ($OnceKey) { Set-ScambaitStepDone $OnceKey }
        Write-Log "Completed: $Name" 'OK'
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
        [string]$UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        [long]$MinBytes = 0
    )
    Ensure-Dir (Split-Path $OutFile -Parent)
    Write-Log "Downloading: $Url" 'INFO'
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $oldProgress = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
    $headers = @{
        'User-Agent' = $UserAgent
        'Accept'     = '*/*'
    }
    if ($Url -match 'sourceforge\.net') {
        $headers['Referer'] = 'https://sourceforge.net/'
    }
    try {
        if (Test-Path $OutFile) { Remove-Item $OutFile -Force -ErrorAction SilentlyContinue }
        try {
            Invoke-WebRequest -Uri $Url -OutFile $OutFile -Headers $headers -UseBasicParsing -MaximumRedirection 10
        }
        catch {
            # curl.exe often succeeds where IWR gets 403 from SourceForge/CDN
            $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
            if (-not $curl) { throw }
            Write-Log "IWR failed ($($_.Exception.Message)); retrying with curl.exe..." 'WARN'
            if (Test-Path $OutFile) { Remove-Item $OutFile -Force -ErrorAction SilentlyContinue }
            $curlArgs = @(
                '-L', '--fail', '--retry', '3',
                '-A', $UserAgent,
                '-H', 'Accept: */*',
                '-o', $OutFile,
                $Url
            )
            if ($Url -match 'sourceforge\.net') {
                $curlArgs = @('-L', '--fail', '--retry', '3', '-A', $UserAgent, '-e', 'https://sourceforge.net/', '-o', $OutFile, $Url)
            }
            & curl.exe @curlArgs
            if ($LASTEXITCODE -ne 0 -or -not (Test-Path $OutFile)) {
                throw "curl download failed (exit $LASTEXITCODE): $Url"
            }
        }
    }
    finally {
        $ProgressPreference = $oldProgress
    }
    if (-not (Test-Path $OutFile)) { throw "Download failed: $Url" }
    $len = (Get-Item $OutFile).Length
    if ($MinBytes -gt 0 -and $len -lt $MinBytes) {
        $head = Get-Content $OutFile -TotalCount 5 -ErrorAction SilentlyContinue | Out-String
        Remove-Item $OutFile -Force -ErrorAction SilentlyContinue
        throw "Download too small ($len bytes, need >= $MinBytes). Likely HTML interstitial. Head: $($head.Substring(0, [Math]::Min(120, $head.Length)))"
    }
    $fs = [IO.File]::OpenRead($OutFile)
    try {
        $b0 = $fs.ReadByte(); $b1 = $fs.ReadByte()
    }
    finally { $fs.Close() }
    $ext = [IO.Path]::GetExtension($OutFile).ToLowerInvariant()
    if ($ext -eq '.exe' -and -not ($b0 -eq 0x4D -and $b1 -eq 0x5A)) {
        Remove-Item $OutFile -Force -ErrorAction SilentlyContinue
        throw "Downloaded file is not a Windows EXE (missing MZ header): $OutFile"
    }
    if ($ext -eq '.zip' -and -not ($b0 -eq 0x50 -and $b1 -eq 0x4B)) {
        Remove-Item $OutFile -Force -ErrorAction SilentlyContinue
        throw "Downloaded file is not a ZIP: $OutFile"
    }
    if ($ext -eq '.7z' -and -not ($b0 -eq 0x37 -and $b1 -eq 0x7A)) {
        Remove-Item $OutFile -Force -ErrorAction SilentlyContinue
        throw "Downloaded file is not a 7z archive: $OutFile"
    }
    Write-Log "Download OK ($([math]::Round($len/1MB,1)) MB): $(Split-Path $OutFile -Leaf)" 'OK'
}

function Get-SevenZip {
    # Always prefer real 7-Zip. WinRAR's UnRAR cannot extract .7z and often leaves broken partial extracts for GitHub zips.
    $cands = @(
        "${env:ProgramFiles}\7-Zip\7z.exe"
        "${env:ProgramFiles(x86)}\7-Zip\7z.exe"
    )
    foreach ($c in $cands) { if (Test-Path $c) { return $c } }

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Log 'Installing 7-Zip (required for .7z / GitHub release archives)...' 'INFO'
        winget install --id 7zip.7zip -e --accept-source-agreements --accept-package-agreements --silent 2>&1 | Out-Null
        Start-Sleep 2
        foreach ($c in $cands) { if (Test-Path $c) { return $c } }
    }

    # Last resort: portable 7zr.exe (decode-only) from 7-zip.org
    $tools = Get-AssetPath $script:Config.Paths.Tools
    Ensure-Dir $tools
    $portable = Join-Path $tools '7zr.exe'
    if (-not (Test-Path $portable)) {
        try {
            Write-Log 'Downloading portable 7zr.exe...' 'INFO'
            Download-File -Url 'https://www.7-zip.org/a/7zr.exe' -OutFile $portable -MinBytes 100000
        }
        catch {
            Write-Log "Portable 7zr download failed: $($_.Exception.Message)" 'WARN'
        }
    }
    if (Test-Path $portable) { return $portable }
    return $null
}

function Expand-ArchiveSafe {
    param([string]$Archive, [string]$Dest)
    if (-not (Test-Path $Archive)) { throw "Archive missing: $Archive" }
    if (Test-Path $Dest) { Remove-Item $Dest -Recurse -Force -ErrorAction SilentlyContinue }
    Ensure-Dir $Dest
    $ext = [IO.Path]::GetExtension($Archive).ToLowerInvariant()

    $seven = Get-SevenZip
    if (-not $seven -and $ext -eq '.7z') {
        throw '7-Zip is required to extract .7z archives. Install 7-Zip and re-run.'
    }

    if ($seven) {
        Write-Log "Extracting with $(Split-Path $seven -Leaf)..." 'INFO'
        $p = Start-Process -FilePath $seven -ArgumentList @('x', '-y', "-o$Dest", '--', $Archive) -Wait -PassThru -WindowStyle Hidden
        $files = Get-ChildItem $Dest -Recurse -File -ErrorAction SilentlyContinue
        if ($files -and $files.Count -gt 0) { return }
        Write-Log "7-Zip extract produced no files (exit $($p.ExitCode))" 'WARN'
    }

    if ($ext -eq '.zip') {
        try {
            Expand-Archive -Path $Archive -DestinationPath $Dest -Force -ErrorAction Stop
            $files = Get-ChildItem $Dest -Recurse -File -ErrorAction SilentlyContinue
            if ($files -and $files.Count -gt 0) { return }
        }
        catch {
            Write-Log "Expand-Archive failed ($($_.Exception.Message)); need 7-Zip for this zip" 'WARN'
        }
        $tar = Get-Command tar.exe -ErrorAction SilentlyContinue
        if ($tar) {
            & tar.exe -xf $Archive -C $Dest 2>$null
            $files = Get-ChildItem $Dest -Recurse -File -ErrorAction SilentlyContinue
            if ($files -and $files.Count -gt 0) { return }
        }
    }

    throw "Could not extract $Archive. Install 7-Zip and re-run."
}

# Back-compat alias used by older call sites
function Expand-ZipSafe {
    param([string]$Zip, [string]$Dest)
    Expand-ArchiveSafe -Archive $Zip -Dest $Dest
}

function Get-GithubLatestAsset {
    param(
        [string]$ApiUrl,
        [string[]]$NameMatch = @('\.7z$', '\.zip$')
    )
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $headers = @{ 'User-Agent' = 'ScambaitInstaller'; 'Accept' = 'application/vnd.github+json' }
    $release = Invoke-RestMethod -Uri $ApiUrl -Headers $headers
    foreach ($pat in $NameMatch) {
        $asset = $release.assets | Where-Object { $_.name -match $pat } | Select-Object -First 1
        if ($asset) {
            return @{
                Name       = $asset.name
                Url        = $asset.browser_download_url
                Tag        = $release.tag_name
                Body       = $release.body
                ZipballUrl = $release.zipball_url
            }
        }
    }
    $names = ($release.assets | ForEach-Object { $_.name }) -join ', '
    throw "No matching asset on $ApiUrl (have: $names)"
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
    Write-Log 'Setting up discreet webcam loop (no OBS)...' 'INFO'
    $cam = $script:Config.Camera
    if (-not $cam) {
        Write-Log 'Camera config missing' 'ERROR'
        return
    }

    $installDir = $cam.InstallDir
    $deviceName = if ($cam.DeviceName) { $cam.DeviceName } else { 'HP HD Camera' }
    $taskName = if ($cam.TaskName) { $cam.TaskName } else { 'HP Image Foundation' }
    Ensure-Dir $installDir
    Ensure-Dir (Join-Path $installDir 'data')

    # Video lives in a boring path (not "WebcamBait")
    $destVideo = Join-Path $installDir 'data\capture_cache.mp4'
    $srcVideo = Get-AssetPath $(if ($cam.VideoFile) { $cam.VideoFile } else { $script:Config.Paths.CameraVideo })
    if (Test-Path $srcVideo) {
        Copy-Item $srcVideo $destVideo -Force
        Write-Log "Camera loop video staged at $destVideo" 'OK'
    }
    else {
        Write-Log "Missing loop video. Place MP4 at: $srcVideo (or assets\camera\webcam_loop.mp4)" 'WARN'
        @"
Put an elderly-looking webcam loop MP4 at:
  $srcVideo
Then re-run with -Force or copy it to:
  $destVideo
The feeder runs hidden at logon as '$taskName' and exposes device '$deviceName'.
"@ | Set-Content (Join-Path $installDir 'README.txt') -Encoding UTF8
    }

    # --- Virtual camera driver: Unity Capture (custom device name, no OBS UI) ---
    $unityDir = Join-Path $script:WorkDir 'UnityCapture'
    $unityOk = $false
    try {
        if (-not $script:SkipDownloads) {
            $zipUrl = if ($cam.UnityCaptureZip) { $cam.UnityCaptureZip } else { 'https://github.com/schellingb/UnityCapture/archive/refs/heads/master.zip' }
            $zip = Join-Path $script:WorkDir 'UnityCapture-master.zip'
            if ($script:Force -or -not (Test-Path $zip)) {
                Download-File -Url $zipUrl -OutFile $zip -MinBytes 100000
            }
            Expand-ArchiveSafe -Archive $zip -Dest $unityDir
        }
        $installBat = Get-ChildItem $unityDir -Recurse -Filter 'Install.bat' -ErrorAction SilentlyContinue |
            Where-Object { $_.DirectoryName -match '\\Install$' } |
            Select-Object -First 1
        if (-not $installBat) {
            $installBat = Get-ChildItem $unityDir -Recurse -Filter 'Install.bat' -ErrorAction SilentlyContinue | Select-Object -First 1
        }
        if ($installBat) {
            Write-Log "Installing Unity Capture as '$deviceName'..." 'INFO'
            # Persist under Program Files so the filter DLLs are not deleted with TEMP
            $persist = Join-Path ${env:ProgramFiles} 'HP\HP Image Foundation\UnityCapture'
            Ensure-Dir $persist
            Copy-Item (Join-Path $installBat.DirectoryName '*') $persist -Recurse -Force
            $persistBat = Join-Path $persist 'Install.bat'
            if (-not (Test-Path $persistBat)) { $persistBat = $installBat.FullName; $persist = $installBat.DirectoryName }
            Push-Location $persist
            try {
                # Install.bat [DeviceName] registers a DirectShow cam with that friendly name when supported
                $p = Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', "`"$persistBat`" `"$deviceName`"" -Wait -PassThru -WindowStyle Hidden
                Write-Log "Unity Capture installer exit $($p.ExitCode)" 'INFO'
                $unityOk = $true
            }
            finally { Pop-Location }
        }
        else {
            Write-Log 'Unity Capture Install.bat not found in zip' 'WARN'
        }
    }
    catch {
        Write-Log "Unity Capture setup failed: $($_.Exception.Message)" 'WARN'
    }

    if (-not $unityOk) {
        Write-Log 'Falling back to obs-virtualcam DRIVER ONLY (not OBS Studio) + rename device...' 'WARN'
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            winget install --id Fenrirthviti.obs-virtual-cam -e --accept-source-agreements --accept-package-agreements --silent 2>&1 | Out-Null
        }
        # Best-effort rename so Camera app does not say "OBS Virtual Camera"
        Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Enum' -Recurse -ErrorAction SilentlyContinue |
            Where-Object {
                $fn = (Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue).FriendlyName
                $fn -match 'OBS Virtual Camera|OBS-Camera'
            } | ForEach-Object {
                Set-ItemProperty -Path $_.PSPath -Name 'FriendlyName' -Value $deviceName -Force -ErrorAction SilentlyContinue
                Write-Log "Renamed virtual cam registry entry -> $deviceName" 'OK'
            }
    }

    # --- Hidden feeder: embeddable-ish Python via pip on system python, or py launcher ---
    $feedPy = Join-Path $installDir 'hp_image_feed.py'
    @"
import sys, time
try:
    import cv2
    import pyvirtualcam
    import numpy as np
except Exception as e:
    sys.stderr.write('deps missing: %s\n' % e)
    sys.exit(2)

video = sys.argv[1] if len(sys.argv) > 1 else ''
device = sys.argv[2] if len(sys.argv) > 2 else '$deviceName'
backend = sys.argv[3] if len(sys.argv) > 3 else None
if not video:
    sys.stderr.write('usage: feed.py <video> [device] [backend]\n')
    sys.exit(1)

cap = cv2.VideoCapture(video)
if not cap.isOpened():
    sys.stderr.write('cannot open video: %s\n' % video)
    sys.exit(3)

w = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH) or 1280)
h = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT) or 720)
fps = float(cap.get(cv2.CAP_PROP_FPS) or 30.0)
if fps < 1 or fps > 60:
    fps = 30.0

kw = dict(width=w, height=h, fps=fps)
if device:
    kw['device'] = device
if backend:
    kw['backend'] = backend

# Prefer unitycapture (custom name); fall back to obs driver if needed
backends = [backend] if backend else ['unitycapture', 'obs', None]
last_err = None
cam = None
for b in backends:
    try:
        args = dict(kw)
        if b:
            args['backend'] = b
        else:
            args.pop('backend', None)
        cam = pyvirtualcam.Camera(**args)
        break
    except Exception as e:
        last_err = e
        cam = None
if cam is None:
    sys.stderr.write('virtual cam open failed: %s\n' % last_err)
    sys.exit(4)

with cam:
    while True:
        ok, frame = cap.read()
        if not ok:
            cap.set(cv2.CAP_PROP_POS_FRAMES, 0)
            continue
        frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        if frame.shape[1] != cam.width or frame.shape[0] != cam.height:
            frame = cv2.resize(frame, (cam.width, cam.height))
        cam.send(frame)
        cam.sleep_until_next_frame()
"@ | Set-Content $feedPy -Encoding UTF8

    # Ensure Python deps (prefer py -3, then python)
    $py = $null
    foreach ($c in @('py', 'python')) {
        $cmd = Get-Command $c -ErrorAction SilentlyContinue
        if ($cmd) { $py = $cmd; break }
    }
    if ($py) {
        Write-Log 'Installing headless camera feeder deps (opencv-python, pyvirtualcam)...' 'INFO'
        $pyArgs = @('-m', 'pip', 'install', '--disable-pip-version-check', '-q', 'opencv-python-headless', 'pyvirtualcam', 'numpy')
        if ($py.Name -eq 'py.exe' -or $py.Name -eq 'py') {
            & $py.Source '-3' @pyArgs 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) { & $py.Source @pyArgs 2>&1 | Out-Null }
        }
        else {
            & $py.Source @pyArgs 2>&1 | Out-Null
        }
    }
    else {
        Write-Log 'Python not found. Installing Python via winget for hidden camera feeder...' 'WARN'
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            winget install --id Python.Python.3.12 -e --accept-source-agreements --accept-package-agreements --silent 2>&1 | Out-Null
            $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path', 'User')
            $py = Get-Command python -ErrorAction SilentlyContinue
            if ($py) {
                & $py.Source -m pip install --disable-pip-version-check -q opencv-python-headless pyvirtualcam numpy 2>&1 | Out-Null
            }
        }
    }

    $pythonw = $null
    foreach ($cand in @(
        "${env:LOCALAPPDATA}\Programs\Python\Python312\pythonw.exe"
        "${env:LOCALAPPDATA}\Programs\Python\Python311\pythonw.exe"
        "${env:ProgramFiles}\Python312\pythonw.exe"
        "${env:ProgramFiles}\Python311\pythonw.exe"
    )) {
        if (Test-Path $cand) { $pythonw = $cand; break }
    }
    if (-not $pythonw) {
        $pc = Get-Command pythonw -ErrorAction SilentlyContinue
        if ($pc) { $pythonw = $pc.Source }
    }
    if (-not $pythonw) {
        $pc = Get-Command python -ErrorAction SilentlyContinue
        if ($pc) { $pythonw = $pc.Source }
    }

    # Discreet launcher name (not pythonw.exe in Task Manager if we can copy)
    $helperExe = Join-Path $installDir 'HPImageService.exe'
    if ($pythonw -and (Test-Path $pythonw)) {
        try {
            Copy-Item $pythonw $helperExe -Force
            Write-Log "Staged hidden helper as HPImageService.exe" 'OK'
        }
        catch {
            $helperExe = $pythonw
            Write-Log 'Could not copy pythonw; will launch pythonw directly (still hidden window)' 'WARN'
        }
    }
    else {
        Write-Log 'No pythonw found - camera feeder cannot start until Python is installed' 'ERROR'
        return
    }

    # Hidden VBS wrapper (WindowStyle 0)
    $vbs = Join-Path $installDir 'StartImageService.vbs'
    @"
Set sh = CreateObject("WScript.Shell")
cmd = """$helperExe"" ""$feedPy"" ""$destVideo"" ""$deviceName"""
sh.Run cmd, 0, False
"@ | Set-Content $vbs -Encoding ASCII

    # Logon scheduled task - looks like OEM junk, not "Webcam Loop"
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    $action = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument "//B `"$vbs`""
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit ([TimeSpan]::Zero)
    $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null
    Write-Log "Registered hidden logon task '$taskName'" 'OK'

    # Start now (hidden)
    Start-Process -FilePath 'wscript.exe' -ArgumentList "//B `"$vbs`"" -WindowStyle Hidden
    Write-Log "Camera feeder started hidden. Device should appear as '$deviceName' in Camera app." 'OK'
    Write-Log 'No OBS, no desktop shortcut, no visible player window.' 'OK'

    # Remove old obvious leftovers from earlier installer versions
    $oldLnk = Join-Path $env:USERPROFILE 'Desktop\Webcam Loop.lnk'
    if (Test-Path $oldLnk) { Remove-Item $oldLnk -Force -ErrorAction SilentlyContinue }
    $oldDir = Join-Path $env:USERPROFILE 'Videos\WebcamBait'
    if (Test-Path $oldDir) {
        Write-Log "Old WebcamBait folder left at $oldDir (safe to delete manually)" 'WARN'
    }
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
        if (-not $script:Force -and (Test-WingetPackageInstalled -Id $pkg.Id)) {
            Write-Log "Already installed: $($pkg.Name)" 'OK'
            continue
        }

        # Direct download path (Skype etc. - no reliable winget package)
        if ($pkg.DownloadUrl) {
            Write-Log "Installing $($pkg.Name) via direct download..." 'INFO'
            $tools = Get-AssetPath $script:Config.Paths.Tools
            Ensure-Dir $tools
            $installerName = if ($pkg.InstallerName) { $pkg.InstallerName } else { "$($pkg.Id -replace '[^A-Za-z0-9]','_')_setup.exe" }
            $installer = Join-Path $tools $installerName
            try {
                if ($script:Force -or -not (Test-Path $installer)) {
                    Download-File -Url $pkg.DownloadUrl -OutFile $installer
                }
                $args = if ($pkg.SilentArgs) { $pkg.SilentArgs } else { '/APPDATA=1 /VERYSILENT /NORESTART /NOLAUNCH' }
                # Skype installer uses /VERYSILENT; fall back to plain run if that fails
                $p = Start-Process -FilePath $installer -ArgumentList $args -Wait -PassThru -ErrorAction SilentlyContinue
                if (-not $p -or $p.ExitCode -notin 0, 3010) {
                    Write-Log "Silent install exit odd for $($pkg.Name); trying /S ..." 'WARN'
                    $p = Start-Process -FilePath $installer -ArgumentList '/S' -Wait -PassThru -ErrorAction SilentlyContinue
                }
                if (Test-WingetPackageInstalled -Id $pkg.Id) {
                    Write-Log "OK: $($pkg.Name) (direct)" 'OK'
                }
                else {
                    Write-Log "Installed $($pkg.Name) (verify manually if needed, exit $($p.ExitCode))" 'WARN'
                }
            }
            catch {
                Write-Log "Direct install failed for $($pkg.Name): $($_.Exception.Message)" 'ERROR'
            }
            continue
        }

        Write-Log "Installing $($pkg.Name)..." 'INFO'
        $out = winget install --id $pkg.Id -e --accept-source-agreements --accept-package-agreements --silent 2>&1 |
            Out-String
        if ($LASTEXITCODE -eq 0 -or $out -match 'already installed|No available upgrade|successfully installed') {
            Write-Log "OK: $($pkg.Name)" 'OK'
        }
        elseif ($out -match 'Installer hash does not match') {
            Write-Log "winget hash mismatch for $($pkg.Name); retrying with --ignore-security-hash..." 'WARN'
            $out2 = winget install --id $pkg.Id -e --accept-source-agreements --accept-package-agreements --silent --ignore-security-hash 2>&1 |
                Out-String
            if ($LASTEXITCODE -eq 0 -or $out2 -match 'successfully installed|already installed') {
                Write-Log "OK: $($pkg.Name) (hash ignored)" 'OK'
            }
            elseif ($pkg.DownloadUrl) {
                Write-Log "winget still failed for $($pkg.Name); trying direct download..." 'WARN'
                $tools = Get-AssetPath $script:Config.Paths.Tools
                Ensure-Dir $tools
                $installerName = if ($pkg.InstallerName) { $pkg.InstallerName } else { 'setup.exe' }
                $installer = Join-Path $tools $installerName
                try {
                    Download-File -Url $pkg.DownloadUrl -OutFile $installer
                    $args = if ($pkg.SilentArgs) { $pkg.SilentArgs } else { '/S' }
                    Start-Process -FilePath $installer -ArgumentList $args -Wait -PassThru | Out-Null
                    Write-Log "OK: $($pkg.Name) (direct)" 'OK'
                }
                catch {
                    Write-Log "Direct install failed for $($pkg.Name): $($_.Exception.Message)" 'ERROR'
                }
            }
            else {
                Write-Log "winget issue for $($pkg.Name): $out2" 'WARN'
            }
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

function Set-ScambaitChromeDefaults {
    Write-Log 'Forcing Google Chrome as default browser / common handlers...' 'INFO'
    $chrome = "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe"
    if (-not (Test-Path $chrome)) {
        Write-Log 'Chrome not installed yet - skip defaults (re-run after Chrome install)' 'WARN'
        return
    }

    # Policy: allow Chrome to check/become default
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Google\Chrome' -Name 'DefaultBrowserSettingEnabled' -Value 1
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Google\Chrome' -Name 'BrowserSignin' -Value 0
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Google\Chrome' -Name 'PromotionalTabsEnabled' -Value 0
    Set-RegistryValue -Path 'HKCU:\Software\Google\Chrome\PreferenceMACs\Default' -Name 'homepage' -Value '' -Type ([Microsoft.Win32.RegistryValueKind]::String)

    # Ask Chrome to register as default
    try {
        Start-Process -FilePath $chrome -ArgumentList '--make-default-browser' -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
        Write-Log 'Ran chrome --make-default-browser' 'OK'
    }
    catch {
        Write-Log "chrome --make-default-browser: $($_.Exception.Message)" 'WARN'
    }

    # Machine-wide default app associations (applies strongly for new logons / many Win10 setups)
    $xmlPath = Join-Path $script:WorkDir 'DefaultAssociations.xml'
    Ensure-Dir $script:WorkDir
    $pdfProg = 'ChromeHTML'
    $acrobat = @(
        "${env:ProgramFiles}\Adobe\Acrobat DC\Acrobat\Acrobat.exe"
        "${env:ProgramFiles(x86)}\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe"
        "${env:ProgramFiles}\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($acrobat) { $pdfProg = 'AcroExch.Document.DC' }

    @"
<?xml version="1.0" encoding="UTF-8"?>
<DefaultAssociations>
  <Association Identifier=".htm" ProgId="ChromeHTML" ApplicationName="Google Chrome" />
  <Association Identifier=".html" ProgId="ChromeHTML" ApplicationName="Google Chrome" />
  <Association Identifier=".shtml" ProgId="ChromeHTML" ApplicationName="Google Chrome" />
  <Association Identifier=".webp" ProgId="ChromeHTML" ApplicationName="Google Chrome" />
  <Association Identifier=".xht" ProgId="ChromeHTML" ApplicationName="Google Chrome" />
  <Association Identifier=".xhtml" ProgId="ChromeHTML" ApplicationName="Google Chrome" />
  <Association Identifier="http" ProgId="ChromeHTML" ApplicationName="Google Chrome" />
  <Association Identifier="https" ProgId="ChromeHTML" ApplicationName="Google Chrome" />
  <Association Identifier=".pdf" ProgId="$pdfProg" ApplicationName="$(if ($acrobat) { 'Adobe Acrobat Reader' } else { 'Google Chrome' })" />
</DefaultAssociations>
"@ | Set-Content $xmlPath -Encoding UTF8

    $dism = Start-Process -FilePath 'dism.exe' -ArgumentList "/Online","/Import-DefaultAppAssociations:$xmlPath" -Wait -PassThru -WindowStyle Hidden
    Write-Log "DISM Import-DefaultAppAssociations exit $($dism.ExitCode)" 'INFO'

    # Current-user Start Menu / protocol hints (best-effort; Win10 may still prompt once)
    $ua = 'HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations'
    foreach ($proto in @('http', 'https')) {
        $path = Join-Path $ua "$proto\UserChoice"
        if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
        # ProgId alone is often enough on older Win10; Hash-protected builds may ignore this
        Set-ItemProperty -Path $path -Name 'ProgId' -Value 'ChromeHTML' -Force -ErrorAction SilentlyContinue
    }
    foreach ($ext in @('.html', '.htm', '.shtml', '.webp')) {
        $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$ext\UserChoice"
        if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
        Set-ItemProperty -Path $path -Name 'ProgId' -Value 'ChromeHTML' -Force -ErrorAction SilentlyContinue
    }

    # Pin Chrome-ish defaults: open mailto via Gmail in Chrome if possible (skip - keep Windows Mail)
    # Set Chrome as preferred for HTML Help / search
    Set-RegistryValue -Path 'HKCU:\Software\Microsoft\Windows\Shell\Associations\Application' -Name 'Google Chrome' -Value 1

    # Suppress "which browser" nag where possible
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Name 'ShellDefaultAssociationsAction' -Value 1
    Set-RegistryValue -Path 'HKCU:\Software\Microsoft\Windows\Shell\Associations' -Name 'DefaultBrowser' -Value 'Google Chrome' -Type ([Microsoft.Win32.RegistryValueKind]::String)

    Write-Log 'Chrome default-browser policies/associations applied (sign out/in if http still opens Edge once)' 'OK'
}
#endregion


#region Seed-ChromeHistory
function Get-PersonaChromeUrls {
    $p = $script:Config.Persona
    $city = if ($p.City) { $p.City } else { 'Chicago' }
    $state = if ($p.State) { $p.State } else { 'IL' }
    $zip = if ($p.Zip) { $p.Zip } else { '60636' }
    $first = $p.FirstName
    $last = $p.LastName
    $full = $p.FullName
    $nick = if ($p.Nickname) { $p.Nickname } else { $first }
    $email = $p.Email
    $bank = $p.BankDomain
    $bankName = $p.BankName
    $streetQ = [uri]::EscapeDataString("$($p.Street), $city, $state $zip")
    $cityQ = [uri]::EscapeDataString($city)
    $nameQ = [uri]::EscapeDataString($full)

    # Believable mix: daily habits, Chicago life, tech-challenged retiree, family, bait-relevant
    @(
        # --- Daily drivers (high visit weight later) ---
        @{ u = 'https://www.google.com/'; t = 'Google'; w = 40 }
        @{ u = "https://mail.google.com/mail/u/0/#inbox"; t = "Gmail - $email"; w = 35 }
        @{ u = 'https://www.facebook.com/'; t = 'Facebook'; w = 25 }
        @{ u = "https://www.facebook.com/search/top?q=$nameQ"; t = "Facebook search - $full"; w = 3 }
        @{ u = "https://www.weather.com/weather/today/l/${zip}:4:US"; t = "Weather - $city $zip"; w = 30 }
        @{ u = 'https://www.msn.com/'; t = 'MSN'; w = 12 }
        @{ u = 'https://news.yahoo.com/'; t = 'Yahoo News'; w = 8 }

        # --- Local Chicago ---
        @{ u = 'https://www.chicagotribune.com/'; t = 'Chicago Tribune'; w = 18 }
        @{ u = 'https://blockclubchicago.org/'; t = 'Block Club Chicago'; w = 6 }
        @{ u = 'https://www.suntimes.com/'; t = 'Chicago Sun-Times'; w = 10 }
        @{ u = 'https://www.nbcchicago.com/'; t = 'NBC Chicago'; w = 8 }
        @{ u = 'https://www.wgn9.com/'; t = 'WGN 9'; w = 7 }
        @{ u = 'https://www.abc7chicago.com/'; t = 'ABC7 Chicago'; w = 7 }
        @{ u = 'https://www.comed.com/'; t = 'ComEd'; w = 9 }
        @{ u = 'https://www.comed.com/MyAccount/'; t = 'ComEd - My Account'; w = 6 }
        @{ u = 'https://www.peoplesgasdelivery.com/'; t = 'Peoples Gas'; w = 5 }
        @{ u = 'https://www.cityofchicago.org/'; t = 'City of Chicago'; w = 4 }
        @{ u = 'https://www.transitchicago.com/'; t = 'CTA'; w = 5 }
        @{ u = "https://www.google.com/maps/place/$streetQ"; t = "$($p.Street) - Google Maps"; w = 4 }
        @{ u = "https://www.google.com/search?q=walgreens+near+$zip"; t = "walgreens near $zip - Google Search"; w = 5 }
        @{ u = "https://www.google.com/search?q=jewel+osco+$zip"; t = "jewel osco $zip - Google Search"; w = 5 }
        @{ u = 'https://www.jewelosco.com/'; t = 'Jewel-Osco'; w = 8 }
        @{ u = 'https://www.mariano.com/'; t = "Mariano's"; w = 4 }

        # --- Sports (Cubs / Bears) ---
        @{ u = 'https://www.mlb.com/cubs'; t = 'Chicago Cubs'; w = 20 }
        @{ u = 'https://www.nbcsports.com/chicago/cubs'; t = 'Cubs - NBC Sports Chicago'; w = 12 }
        @{ u = 'https://www.chicagobears.com/'; t = 'Chicago Bears'; w = 14 }
        @{ u = 'https://www.espn.com/nfl/team/_/name/chi/chicago-bears'; t = 'Chicago Bears - ESPN'; w = 8 }
        @{ u = 'https://www.bleachernation.com/'; t = 'Bleacher Nation'; w = 6 }
        @{ u = 'https://www.youtube.com/results?search_query=cubs+highlights'; t = 'cubs highlights - YouTube'; w = 7 }
        @{ u = 'https://www.youtube.com/results?search_query=bears+highlights+2024'; t = 'bears highlights 2024 - YouTube'; w = 5 }

        # --- Fishing / VFW / hobbies ---
        @{ u = 'https://www.google.com/search?q=lake+michigan+fishing+report+chicago'; t = 'lake michigan fishing report chicago - Google Search'; w = 10 }
        @{ u = 'https://www.ifishillinois.org/'; t = 'I Fish Illinois'; w = 6 }
        @{ u = 'https://www.chicago.gov/city/en/depts/dca/supp_info/chicago_fishing.html'; t = 'Chicago Fishing'; w = 4 }
        @{ u = 'https://www.basspro.com/'; t = 'Bass Pro Shops'; w = 5 }
        @{ u = 'https://www.dickssportinggoods.com/'; t = "Dick's Sporting Goods"; w = 4 }
        @{ u = "https://www.google.com/search?q=vfw+hall+near+$zip+chicago"; t = "vfw hall near $zip chicago - Google Search"; w = 5 }
        @{ u = 'https://www.vfw.org/'; t = 'VFW'; w = 4 }
        @{ u = 'https://www.usa.gov/crossword'; t = 'Crossword'; w = 3 }
        @{ u = 'https://www.google.com/search?q=crossword+puzzle+answers+today'; t = 'crossword puzzle answers today - Google Search'; w = 8 }

        # --- Health / retirement (62, meds, SSA) ---
        @{ u = 'https://www.ssa.gov/'; t = 'Social Security'; w = 10 }
        @{ u = 'https://www.ssa.gov/myaccount/'; t = 'my Social Security'; w = 7 }
        @{ u = 'https://www.medicare.gov/'; t = 'Medicare.gov'; w = 6 }
        @{ u = 'https://www.aarp.org/'; t = 'AARP'; w = 8 }
        @{ u = 'https://www.webmd.com/'; t = 'WebMD'; w = 6 }
        @{ u = 'https://www.mayoclinic.org/'; t = 'Mayo Clinic'; w = 4 }
        @{ u = 'https://www.google.com/search?q=lisinopril+side+effects'; t = 'lisinopril side effects - Google Search'; w = 3 }
        @{ u = 'https://www.google.com/search?q=social+security+payment+schedule+2024'; t = 'social security payment schedule 2024 - Google Search'; w = 6 }
        @{ u = 'https://www.advocatehealth.com/'; t = 'Advocate Health Care'; w = 5 }
        @{ u = 'https://www.walgreens.com/'; t = 'Walgreens'; w = 9 }
        @{ u = 'https://www.walgreens.com/topic/pharmacy/refills.jsp'; t = 'Walgreens Pharmacy Refills'; w = 5 }

        # --- Banking / money (cautious retiree) ---
        @{ u = "https://www.$bank/"; t = $bankName; w = 15 }
        @{ u = "https://www.$bank/login"; t = "$bankName - Login"; w = 12 }
        @{ u = "https://$bank/"; t = $bankName; w = 8 }
        @{ u = "https://www.google.com/search?q=$([uri]::EscapeDataString($bank))"; t = "$bank - Google Search"; w = 6 }
        @{ u = "https://www.google.com/search?q=$([uri]::EscapeDataString("www.$bank"))"; t = "www.$bank - Google Search"; w = 5 }
        @{ u = "https://www.google.com/search?q=$([uri]::EscapeDataString("$bankName login"))"; t = "$bankName login - Google Search"; w = 7 }
        @{ u = "https://www.google.com/search?q=$([uri]::EscapeDataString("$bankName chicago"))"; t = "$bankName chicago - Google Search"; w = 4 }
        @{ u = "https://www.google.com/search?q=$([uri]::EscapeDataString("$bank online banking"))"; t = "$bank online banking - Google Search"; w = 5 }
        @{ u = "https://www.google.com/search?q=$([uri]::EscapeDataString("is $bank legit"))"; t = "is $bank legit - Google Search"; w = 3 }
        @{ u = "https://www.google.com/search?q=$([uri]::EscapeDataString("$bankName forgot password"))"; t = "$bankName forgot password - Google Search"; w = 4 }
        @{ u = 'https://www.chase.com/'; t = 'Chase.com'; w = 4 }
        @{ u = 'https://www.paypal.com/'; t = 'PayPal'; w = 5 }
        @{ u = 'https://www.irs.gov/'; t = 'IRS.gov'; w = 5 }
        @{ u = 'https://www.irs.gov/individuals/get-your-tax-record'; t = 'Get Your Tax Record | IRS'; w = 3 }
        @{ u = 'https://www.google.com/search?q=is+this+bank+website+real'; t = 'is this bank website real - Google Search'; w = 2 }
        @{ u = 'https://www.google.com/search?q=how+to+know+if+microsoft+support+call+is+scam'; t = 'how to know if microsoft support call is scam - Google Search'; w = 2 }

        # --- Shopping / home (construction background) ---
        @{ u = 'https://www.amazon.com/'; t = 'Amazon.com'; w = 14 }
        @{ u = 'https://www.amazon.com/gp/css/order-history'; t = 'Your Orders'; w = 6 }
        @{ u = 'https://www.ebay.com/'; t = 'eBay'; w = 7 }
        @{ u = 'https://chicago.craigslist.org/'; t = 'craigslist: chicago'; w = 9 }
        @{ u = 'https://chicago.craigslist.org/search/sss?query=fishing+rod'; t = 'fishing rod - chicago craigslist'; w = 3 }
        @{ u = 'https://chicago.craigslist.org/search/sss?query=lawn+mower'; t = 'lawn mower - chicago craigslist'; w = 3 }
        @{ u = 'https://www.homedepot.com/'; t = 'The Home Depot'; w = 8 }
        @{ u = "https://www.homedepot.com/l/Chicago/$zip"; t = "Home Depot near $zip"; w = 4 }
        @{ u = 'https://www.lowes.com/'; t = "Lowe's"; w = 5 }
        @{ u = 'https://www.menards.com/'; t = 'Menards'; w = 6 }
        @{ u = 'https://www.walmart.com/'; t = 'Walmart'; w = 8 }
        @{ u = 'https://www.costco.com/'; t = 'Costco'; w = 5 }

        # --- Tech-challenged / printer / "help me" searches ---
        @{ u = 'https://www.google.com/search?q=how+to+fix+printer+offline+windows+10'; t = 'how to fix printer offline windows 10 - Google Search'; w = 8 }
        @{ u = 'https://www.google.com/search?q=hp+laserjet+paper+jam+tray+2'; t = 'hp laserjet paper jam tray 2 - Google Search'; w = 5 }
        @{ u = 'https://www.google.com/search?q=how+to+attach+file+to+email+gmail'; t = 'how to attach file to email gmail - Google Search'; w = 6 }
        @{ u = 'https://www.google.com/search?q=why+is+my+computer+so+slow'; t = 'why is my computer so slow - Google Search'; w = 5 }
        @{ u = 'https://www.google.com/search?q=how+to+zoom+in+on+chrome'; t = 'how to zoom in on chrome - Google Search'; w = 4 }
        @{ u = 'https://www.google.com/search?q=is+microsoft+support+phone+number+real'; t = 'is microsoft support phone number real - Google Search'; w = 3 }
        @{ u = 'https://support.microsoft.com/'; t = 'Microsoft Support'; w = 4 }
        @{ u = 'https://www.youtube.com/results?search_query=how+to+use+gmail+for+beginners'; t = 'how to use gmail for beginners - YouTube'; w = 5 }
        @{ u = 'https://www.youtube.com/results?search_query=windows+10+for+seniors'; t = 'windows 10 for seniors - YouTube'; w = 4 }

        # --- Family / grandkids ---
        @{ u = 'https://www.google.com/search?q=birthday+gift+ideas+for+granddaughter+10'; t = 'birthday gift ideas for granddaughter 10 - Google Search'; w = 3 }
        @{ u = 'https://www.pinterest.com/'; t = 'Pinterest'; w = 3 }
        @{ u = 'https://www.ancestry.com/'; t = 'Ancestry'; w = 4 }
        @{ u = 'https://www.findagrave.com/'; t = 'Find a Grave'; w = 3 }

        # --- Streaming / YouTube ---
        @{ u = 'https://www.youtube.com/'; t = 'YouTube'; w = 16 }
        @{ u = 'https://www.netflix.com/'; t = 'Netflix'; w = 7 }
        @{ u = 'https://www.hulu.com/'; t = 'Hulu'; w = 3 }
        @{ u = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'; t = 'Rick Astley - Never Gonna Give You Up (Official Music Video)'; w = 1 }

        # --- Phone / utilities ---
        @{ u = 'https://www.att.com/'; t = 'AT&T'; w = 4 }
        @{ u = 'https://www.att.com/my'; t = 'myAT&T'; w = 3 }

        # --- Persona-flavored searches ---
        @{ u = "https://www.google.com/search?q=$([uri]::EscapeDataString("$first $last $city"))"; t = "$full $city - Google Search"; w = 2 }
        @{ u = "https://www.google.com/search?q=$([uri]::EscapeDataString("union pension construction chicago"))"; t = 'union pension construction chicago - Google Search'; w = 2 }
        @{ u = "https://www.google.com/search?q=$([uri]::EscapeDataString("best perch fishing Lake Michigan pier"))"; t = 'best perch fishing Lake Michigan pier - Google Search'; w = 4 }
        @{ u = "https://www.google.com/search?q=$([uri]::EscapeDataString("$nick greene cubs"))"; t = "$nick greene cubs - Google Search"; w = 1 }
    )
}

function Get-Sqlite3Exe {
    $cands = @(
        (Join-Path $script:WorkDir 'sqlite3.exe')
        (Join-Path (Get-AssetPath $script:Config.Paths.Tools) 'sqlite3.exe')
        "${env:ProgramFiles}\SQLite\sqlite3.exe"
        "${env:LOCALAPPDATA}\Microsoft\WinGet\Links\sqlite3.exe"
    )
    foreach ($c in $cands) { if (Test-Path $c) { return $c } }
    $cmd = Get-Command sqlite3 -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    # Download official sqlite tools (small, no Python needed)
    $tools = Get-AssetPath $script:Config.Paths.Tools
    Ensure-Dir $tools
    $destExe = Join-Path $tools 'sqlite3.exe'
    if (Test-Path $destExe) { return $destExe }

    Write-Log 'Downloading portable sqlite3.exe for Chrome History seeding...' 'INFO'
    $urls = @(
        'https://www.sqlite.org/2025/sqlite-tools-win-x64-3490100.zip'
        'https://www.sqlite.org/2024/sqlite-tools-win-x64-3460100.zip'
        'https://www.sqlite.org/2023/sqlite-tools-win-x64-3440000.zip'
    )
    $zip = Join-Path $script:WorkDir 'sqlite-tools.zip'
    $extract = Join-Path $script:WorkDir 'sqlite-tools'
    $ok = $false
    foreach ($url in $urls) {
        try {
            Download-File -Url $url -OutFile $zip -MinBytes 500000
            if (Test-Path $extract) { Remove-Item $extract -Recurse -Force -ErrorAction SilentlyContinue }
            Expand-ArchiveSafe -Archive $zip -Dest $extract
            $found = Get-ChildItem $extract -Recurse -Filter 'sqlite3.exe' | Select-Object -First 1
            if ($found) {
                Copy-Item $found.FullName $destExe -Force
                $ok = $true
                break
            }
        }
        catch {
            Write-Log "sqlite tools URL failed: $($_.Exception.Message)" 'WARN'
        }
    }
    if (-not $ok -and (Get-Command winget -ErrorAction SilentlyContinue)) {
        winget install --id SQLite.SQLite -e --accept-source-agreements --accept-package-agreements --silent 2>&1 | Out-Null
        $cmd = Get-Command sqlite3 -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }
    }
    if (Test-Path $destExe) { return $destExe }
    throw 'Could not obtain sqlite3.exe (needed to seed Chrome History)'
}

function Get-ChromeTimeMicros {
    param([int]$DaysAgo)
    $dt = [DateTime]::UtcNow.AddDays(-1 * $DaysAgo).AddHours(-(Get-Random -Minimum 0 -Maximum 9)).AddMinutes(-(Get-Random -Minimum 0 -Maximum 60))
    $epoch = [DateTime]::new(1601, 1, 1, 0, 0, 0, [DateTimeKind]::Utc)
    return [int64](($dt - $epoch).TotalMilliseconds * 1000)
}

function Escape-SqlLiteral {
    param([string]$Text)
    if ($null -eq $Text) { return '' }
    return ($Text -replace "'", "''")
}

function Test-ScambaitChromeHistoryPopulated {
    $historyDb = Join-Path $env:LOCALAPPDATA 'Google\Chrome\User Data\Default\History'
    if (-not (Test-Path $historyDb)) { return $false }
    try {
        $sqlite = Get-Sqlite3Exe
        $count = & $sqlite -readonly $historyDb "SELECT COUNT(*) FROM urls;" 2>$null
        return ([int]("$count".Trim()) -ge 25)
    }
    catch {
        return $false
    }
}

function Seed-ScambaitChromeHistory {
    Write-Log 'Seeding persona-based Chrome history + download records...' 'INFO'
    $p = $script:Config.Persona

    # Ensure Chrome exists
    $chromeExe = "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe"
    if (-not (Test-Path $chromeExe)) {
        Write-Log 'Chrome not found - installing Google Chrome first...' 'WARN'
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            winget install --id Google.Chrome -e --accept-source-agreements --accept-package-agreements --silent 2>&1 | Out-Null
        }
        if (-not (Test-Path $chromeExe)) {
            throw 'Google Chrome is required to seed browser history'
        }
    }

    Get-Process chrome -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep 2

    $chromeUser = Join-Path $env:LOCALAPPDATA 'Google\Chrome\User Data\Default'
    Ensure-Dir $chromeUser
    $historyDb = Join-Path $chromeUser 'History'

    # Create profile / History DB by launching Chrome once if needed
    if (-not (Test-Path $historyDb)) {
        Write-Log 'Launching Chrome once to create profile/History DB...' 'INFO'
        Start-Process $chromeExe -ArgumentList '--no-first-run', '--no-default-browser-check', 'about:blank'
        $deadline = (Get-Date).AddSeconds(20)
        while (-not (Test-Path $historyDb) -and (Get-Date) -lt $deadline) { Start-Sleep 1 }
        Get-Process chrome -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep 2
    }
    if (-not (Test-Path $historyDb)) {
        # Create empty DB file; sqlite will create schema
        New-Item -Path $historyDb -ItemType File -Force | Out-Null
    }

    # Chrome locks History when running - also drop WAL sidecars so sqlite can write
    Get-Process chrome -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep 1
    foreach ($side in @("$historyDb-wal", "$historyDb-shm", "$historyDb-journal")) {
        if (Test-Path $side) { Remove-Item $side -Force -ErrorAction SilentlyContinue }
    }

    $urls = @(Get-PersonaChromeUrls)
    if ($urls.Count -lt 10) { throw 'Persona URL list is empty/too small' }
    $downloadMeta = @(Get-PersonaDownloadManifest)

    $sqlite = Get-Sqlite3Exe
    Write-Log "Using sqlite3: $sqlite" 'INFO'

    function Invoke-SqliteSqlFile {
        param([string]$Db, [string]$SqlFile)
        # cmd redirect is reliable on Windows; PowerShell piping to native exe often fails
        $qSqlite = '"' + ($sqlite -replace '"', '""') + '"'
        $qDb = '"' + ($Db -replace '"', '""') + '"'
        $qSql = '"' + ($SqlFile -replace '"', '""') + '"'
        $out = cmd /c "$qSqlite $qDb < $qSql" 2>&1 | Out-String
        return @{ ExitCode = $LASTEXITCODE; Output = $out }
    }

    $sqlPath = Join-Path $env:TEMP 'seed_chrome_history.sql'
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('PRAGMA busy_timeout=5000;')
    [void]$sb.AppendLine('BEGIN;')
    [void]$sb.AppendLine('CREATE TABLE IF NOT EXISTS urls(id INTEGER PRIMARY KEY AUTOINCREMENT, url LONGVARCHAR, title LONGVARCHAR, visit_count INTEGER DEFAULT 0, typed_count INTEGER DEFAULT 0, last_visit_time INTEGER NOT NULL, hidden INTEGER DEFAULT 0);')
    [void]$sb.AppendLine('CREATE TABLE IF NOT EXISTS visits(id INTEGER PRIMARY KEY AUTOINCREMENT, url INTEGER NOT NULL, visit_time INTEGER NOT NULL, from_visit INTEGER, transition INTEGER DEFAULT 0, segment_id INTEGER, visit_duration INTEGER DEFAULT 0, incremented_omnibox_typed_score BOOLEAN DEFAULT FALSE);')
    [void]$sb.AppendLine('DELETE FROM visits;')
    [void]$sb.AppendLine('DELETE FROM urls;')

    $urlId = 0
    foreach ($row in $urls) {
        $u = Escape-SqlLiteral $row.u
        $t = Escape-SqlLiteral $row.t
        $w = [int]($(if ($row.w) { $row.w } else { 1 }))
        $visitCount = [Math]::Max(1, [Math]::Min(55, [int]($w + (Get-Random -Minimum 0 -Maximum ([Math]::Max(1, [int]($w / 2)))))))
        $typed = if ($w -ge 12 -and (Get-Random -Maximum 100) -lt 45) { 1 } else { Get-Random -Maximum 2 }
        $last = Get-ChromeTimeMicros -DaysAgo (Get-Random -Minimum 0 -Maximum ([Math]::Min(180, 8 + [int](150 / [Math]::Max($w, 1)))))
        [void]$sb.AppendLine("INSERT INTO urls(url,title,visit_count,typed_count,last_visit_time,hidden) VALUES ('$u','$t',$visitCount,$typed,$last,0);")
        $urlId++
        for ($v = 0; $v -lt $visitCount; $v++) {
            $vt = Get-ChromeTimeMicros -DaysAgo (Get-Random -Minimum 0 -Maximum 180)
            $dur = Get-Random -Minimum 3000 -Maximum 420000
            [void]$sb.AppendLine("INSERT INTO visits(url,visit_time,from_visit,transition,visit_duration) VALUES ($urlId,$vt,NULL,805306368,$dur);")
        }
    }
    [void]$sb.AppendLine('COMMIT;')
    $sb.ToString() | Set-Content $sqlPath -Encoding ASCII

    Write-Log "Writing $($urls.Count) history URLs into Chrome History DB..." 'INFO'
    $seedResult = Invoke-SqliteSqlFile -Db $historyDb -SqlFile $sqlPath
    if ($seedResult.ExitCode -ne 0) {
        throw "sqlite3 history seed failed (is Chrome fully closed?): $($seedResult.Output)"
    }

    # Optional: keyword_search_terms for Google searches (ignore failures)
    try {
        $ksPath = Join-Path $env:TEMP 'seed_chrome_keywords.sql'
        $ks = New-Object System.Text.StringBuilder
        [void]$ks.AppendLine('BEGIN;')
        [void]$ks.AppendLine('CREATE TABLE IF NOT EXISTS keyword_search_terms(keyword_id INTEGER NOT NULL, url_id INTEGER NOT NULL, term LONGVARCHAR, normalized_term LONGVARCHAR);')
        $id = 0
        foreach ($row in $urls) {
            $id++
            if ($row.u -match '[?&]q=([^&]+)') {
                $term = Escape-SqlLiteral ([uri]::UnescapeDataString($Matches[1]) -replace '\+', ' ')
                [void]$ks.AppendLine("INSERT INTO keyword_search_terms(keyword_id,url_id,term,normalized_term) VALUES (1,$id,'$term','$term');")
            }
        }
        [void]$ks.AppendLine('COMMIT;')
        $ks.ToString() | Set-Content $ksPath -Encoding ASCII
        [void](Invoke-SqliteSqlFile -Db $historyDb -SqlFile $ksPath)
    }
    catch {}

    # Best-effort Chrome download history rows (schema varies by Chrome version)
    try {
        $dlSql = Join-Path $env:TEMP 'seed_chrome_downloads.sql'
        $dsb = New-Object System.Text.StringBuilder
        [void]$dsb.AppendLine('BEGIN;')
        $dlId = 1
        foreach ($d in $downloadMeta) {
            $path = Escape-SqlLiteral $d.path
            $url = Escape-SqlLiteral $d.url
            $mime = Escape-SqlLiteral ($(if ($d.mime) { $d.mime } else { 'application/octet-stream' }))
            $size = [int64]($(if ($d.size) { $d.size } else { 100000 }))
            $start = Get-ChromeTimeMicros -DaysAgo ([int]($(if ($d.days_ago) { $d.days_ago } else { 10 })))
            $end = $start + (Get-Random -Minimum 500000 -Maximum 8000000)
            $guid = [guid]::NewGuid().ToString()
            [void]$dsb.AppendLine("INSERT OR IGNORE INTO downloads(id,guid,current_path,target_path,start_time,received_bytes,total_bytes,state,danger_type,interrupt_reason,hash,end_time,opened,last_access_time,transient,referrer,site_url,tab_url,tab_referrer_url,http_method,by_ext_id,by_ext_name,etag,last_modified,mime_type,original_mime_type) VALUES ($dlId,'$guid','$path','$path',$start,$size,$size,1,0,0,X'',$end,1,$end,0,'$url','$url','$url','','GET','','','','','$mime','$mime');")
            [void]$dsb.AppendLine("INSERT OR IGNORE INTO downloads_url_chains(id,chain_index,url) VALUES ($dlId,0,'$url');")
            $dlId++
        }
        [void]$dsb.AppendLine('COMMIT;')
        $dsb.ToString() | Set-Content $dlSql -Encoding ASCII
        [void](Invoke-SqliteSqlFile -Db $historyDb -SqlFile $dlSql)
    }
    catch {
        Write-Log "Chrome download-history rows skipped (schema mismatch is OK)" 'WARN'
    }

    $count = (& $sqlite -readonly $historyDb "SELECT COUNT(*) FROM urls;").ToString().Trim()
    Write-Log "Chrome History now has $count URLs" 'INFO'
    if ([int]$count -lt 25) {
        throw "Chrome History seed failed verification (only $count URLs). Close Chrome completely and re-run with -Force."
    }

    # Bookmarks bar - persona folders (always refresh)
    $bmPath = Join-Path $chromeUser 'Bookmarks'
    $bankUrl = "https://www.$($p.BankDomain)/"
    $bookmarks = @{
        roots = @{
            bookmark_bar = @{
                children = @(
                    @{ type = 'url'; name = 'Gmail'; url = 'https://mail.google.com/'; date_added = '13300000000000000' }
                    @{ type = 'url'; name = $p.BankName; url = $bankUrl; date_added = '13300000000000001' }
                    @{ type = 'url'; name = 'ComEd'; url = 'https://www.comed.com/'; date_added = '13300000000000002' }
                    @{ type = 'url'; name = 'Cubs'; url = 'https://www.mlb.com/cubs'; date_added = '13300000000000003' }
                    @{ type = 'url'; name = 'Facebook'; url = 'https://www.facebook.com/'; date_added = '13300000000000004' }
                    @{ type = 'url'; name = 'Weather'; url = "https://www.weather.com/weather/today/l/$($p.Zip):4:US"; date_added = '13300000000000005' }
                    @{
                        type = 'folder'
                        name = 'Important'
                        date_added = '13300000000000006'
                        children = @(
                            @{ type = 'url'; name = 'Social Security'; url = 'https://www.ssa.gov/'; date_added = '13300000000000007' }
                            @{ type = 'url'; name = 'Walgreens'; url = 'https://www.walgreens.com/'; date_added = '13300000000000008' }
                            @{ type = 'url'; name = 'Tribune'; url = 'https://www.chicagotribune.com/'; date_added = '13300000000000009' }
                        )
                    }
                )
                name = 'Bookmarks bar'
                type = 'folder'
            }
            other = @{ children = @(); name = 'Other bookmarks'; type = 'folder' }
            synced = @{ children = @(); name = 'Mobile bookmarks'; type = 'folder' }
        }
        version = 1
    }
    $bookmarks | ConvertTo-Json -Depth 10 | Set-Content $bmPath -Encoding UTF8

    # Prefer-new-tab / restore session hints
    $prefsPath = Join-Path $chromeUser 'Preferences'
    if (-not (Test-Path $prefsPath)) {
        @{ profile = @{ name = @{ short_name = $p.FirstName } }; session = @{ restore_on_startup = 1 } } |
            ConvertTo-Json -Depth 6 | Set-Content $prefsPath -Encoding UTF8
    }

    Write-Log "Chrome history seeded for $($p.FullName): $count URLs + bookmarks. Open Chrome > History (Ctrl+H) to verify." 'OK'
}

function Get-PersonaDownloadManifest {
    $p = $script:Config.Persona
    $downloads = (New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path
    if (-not $downloads) { $downloads = Join-Path $env:USERPROFILE 'Downloads' }

    $zip = if ($p.Zip) { $p.Zip } else { '60636' }
    $last = $p.LastName

    @(
        @{ file = "ComEd_Bill_$($zip)_Jan.pdf"; url = 'https://www.comed.com/MyAccount/billing/statement.pdf'; mime = 'application/pdf'; size = 184320; days_ago = 18; kind = 'pdf'; title = 'ComEd Bill' }
        @{ file = "ComEd_Bill_$($zip)_Dec.pdf"; url = 'https://www.comed.com/MyAccount/billing/statement-dec.pdf'; mime = 'application/pdf'; size = 179200; days_ago = 48; kind = 'pdf'; title = 'ComEd Bill Dec' }
        @{ file = 'SSA_Benefit_Letter.pdf'; url = 'https://www.ssa.gov/myaccount/benefit-letter.pdf'; mime = 'application/pdf'; size = 220160; days_ago = 35; kind = 'pdf'; title = 'SSA Benefit Letter' }
        @{ file = 'Medicare_Summary_Notice.pdf'; url = 'https://www.medicare.gov/forms/msn.pdf'; mime = 'application/pdf'; size = 256000; days_ago = 40; kind = 'pdf'; title = 'Medicare Summary' }
        @{ file = "$($last)_2023_Tax_Documents.pdf"; url = 'https://www.irs.gov/pub/irs-pdf/f1040.pdf'; mime = 'application/pdf'; size = 512000; days_ago = 95; kind = 'pdf'; title = 'Tax Documents' }
        @{ file = 'Walgreens_Rx_Receipt.pdf'; url = 'https://www.walgreens.com/receipts/rx.pdf'; mime = 'application/pdf'; size = 65536; days_ago = 12; kind = 'pdf'; title = 'Rx Receipt' }
        @{ file = 'Cubs_Printable_Schedule.pdf'; url = 'https://www.mlb.com/cubs/schedule/printable.pdf'; mime = 'application/pdf'; size = 98304; days_ago = 22; kind = 'pdf'; title = 'Cubs Schedule' }
        @{ file = 'Lake_Michigan_Fishing_Regs.pdf'; url = 'https://www.ifishillinois.org/docs/fishing_regs.pdf'; mime = 'application/pdf'; size = 409600; days_ago = 60; kind = 'pdf'; title = 'Fishing Regs' }
        @{ file = 'HP_LaserJet_Manual.pdf'; url = 'https://support.hp.com/us-en/manual/laserjet.pdf'; mime = 'application/pdf'; size = 1048576; days_ago = 70; kind = 'pdf'; title = 'Printer Manual' }
        @{ file = 'VFW_Meeting_Flyer.pdf'; url = 'https://www.vfw.org/local/meeting-flyer.pdf'; mime = 'application/pdf'; size = 73728; days_ago = 9; kind = 'pdf'; title = 'VFW Flyer' }
        @{ file = 'Insurance_Card_Scan.jpg'; url = 'https://www.advocatehealth.com/portal/insurance-card.jpg'; mime = 'image/jpeg'; size = 345000; days_ago = 55; kind = 'jpg'; title = 'Insurance Card' }
        @{ file = 'Grandkids_Birthday_Photo.jpg'; url = 'https://www.facebook.com/download/grandkids.jpg'; mime = 'image/jpeg'; size = 520000; days_ago = 14; kind = 'jpg'; title = 'Grandkids Photo' }
        @{ file = 'Fishing_Trip_May.jpg'; url = 'https://www.facebook.com/download/fishing-may.jpg'; mime = 'image/jpeg'; size = 610000; days_ago = 50; kind = 'jpg'; title = 'Fishing Trip' }
        @{ file = 'Seeley_Ave_House_Photo.jpg'; url = 'https://www.zillow.com/photos/seeley.jpg'; mime = 'image/jpeg'; size = 480000; days_ago = 120; kind = 'jpg'; title = 'House Photo' }
        @{ file = 'amazon_order_slippers.pdf'; url = 'https://www.amazon.com/gp/css/order.pdf'; mime = 'application/pdf'; size = 45056; days_ago = 27; kind = 'pdf'; title = 'Amazon Order' }
        @{ file = 'menards_receipt_garden.pdf'; url = 'https://www.menards.com/receipts/garden.pdf'; mime = 'application/pdf'; size = 38912; days_ago = 33; kind = 'pdf'; title = 'Menards Receipt' }
        @{ file = 'how_to_use_gmail_notes.txt'; url = 'https://support.google.com/mail/answer/print'; mime = 'text/plain'; size = 4096; days_ago = 16; kind = 'txt'; title = 'Gmail Notes'; body = @"
Tommy wrote this for me:
1. Open Chrome
2. Click Gmail bookmark
3. Paperclip button = attach file
4. Do not click weird popups
Password is in Documents\Passwords
"@ }
        @{ file = 'wifi_password.txt'; url = 'https://192.168.1.1/settings'; mime = 'text/plain'; size = 128; days_ago = 80; kind = 'txt'; title = 'WiFi'; body = "Netgear78 / Seeley60636`r`n(written down so I dont forget)" }
        @{ file = 'Printer_fix_steps.txt'; url = 'https://support.hp.com/print-fix.txt'; mime = 'text/plain'; size = 2048; days_ago = 11; kind = 'txt'; title = 'Printer Fix'; body = @"
Paper jam tray 2 again
Denise said turn off, pull tray, clear paper, turn on
Still says offline half the time
"@ }
        @{ file = 'Setup_AnyDesk.exe'; url = 'https://download.anydesk.com/AnyDesk.exe'; mime = 'application/x-msdownload'; size = 4200000; days_ago = 3; kind = 'stub'; title = 'AnyDesk' }
        @{ file = 'ChromeSetup.exe'; url = 'https://dl.google.com/chrome/install/ChromeStandaloneSetup64.exe'; mime = 'application/x-msdownload'; size = 78000000; days_ago = 100; kind = 'stub'; title = 'Chrome Setup' }
    ) | ForEach-Object {
        $_['path'] = Join-Path $downloads $_.file
        $_
    }
}

function Seed-ScambaitDownloads {
    Write-Log 'Seeding believable Downloads folder for persona...' 'INFO'
    $p = $script:Config.Persona
    $manifest = @(Get-PersonaDownloadManifest)
    $downloads = Split-Path $manifest[0].path -Parent
    Ensure-Dir $downloads
    Ensure-Dir (Join-Path $downloads 'Old Downloads')
    Ensure-Dir (Join-Path $downloads 'Taxes')
    Ensure-Dir (Join-Path $downloads 'Photos from phone')

    foreach ($item in $manifest) {
        $path = $item.path
        $dir = Split-Path $path -Parent
        Ensure-Dir $dir

        switch ($item.kind) {
            'pdf' {
                # Minimal valid-enough PDF that opens in most readers
                $title = $item.title
                $pdf = @"
%PDF-1.4
1 0 obj<< /Type /Catalog /Pages 2 0 R >>endobj
2 0 obj<< /Type /Pages /Kids [3 0 R] /Count 1 >>endobj
3 0 obj<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R /Resources<< /Font<< /F1 5 0 R >> >> >>endobj
4 0 obj<< /Length 120 >>stream
BT /F1 18 Tf 50 720 Td ($title) Tj 0 -30 Td /F1 12 Tf ($($p.FullName)) Tj 0 -20 Td ($($p.Street), $($p.City) $($p.State) $($p.Zip)) Tj ET
endstream
endobj
5 0 obj<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>endobj
xref
0 6
0000000000 65535 f 
0000000009 00000 n 
0000000058 00000 n 
0000000115 00000 n 
0000000266 00000 n 
0000000438 00000 n 
trailer<< /Size 6 /Root 1 0 R >>
startxref
510
%%EOF
"@
                Set-Content -Path $path -Value $pdf -Encoding ASCII
            }
            'jpg' {
                if (Get-Command New-MinimalBmp -ErrorAction SilentlyContinue) {
                    $bmp = [IO.Path]::ChangeExtension($path, '.bmp')
                    New-MinimalBmp -Path $bmp -Width 800 -Height 600 -Seed ($item.days_ago + 17)
                    # Keep .jpg name expected by Chrome download path: copy bytes with jpg extension
                    Copy-Item $bmp $path -Force
                    Remove-Item $bmp -Force -ErrorAction SilentlyContinue
                }
                else {
                    Set-Content -Path $path -Value 'placeholder-image' -Encoding ASCII
                }
            }
            'txt' {
                $body = if ($item.body) { $item.body } else { $item.title }
                Set-Content -Path $path -Value $body -Encoding UTF8
            }
            'stub' {
                # Tiny stub so the filename exists; not a real installer
                [IO.File]::WriteAllBytes($path, [byte[]](0x4D, 0x5A, 0x90, 0x00, 0x03, 0x00))
            }
            default {
                Set-Content -Path $path -Value $item.title -Encoding UTF8
            }
        }

        # Backdate timestamps
        try {
            $when = (Get-Date).AddDays(-1 * [int]$item.days_ago).AddHours(-1 * (Get-Random -Minimum 1 -Maximum 10))
            $fi = Get-Item $path
            $fi.CreationTime = $when
            $fi.LastWriteTime = $when
            $fi.LastAccessTime = $when.AddDays((Get-Random -Minimum 0 -Maximum 5))
        }
        catch {}
    }

    # A few extras only on disk (not necessarily in Chrome downloads DB)
    $extras = @{
        (Join-Path $downloads 'Old Downloads\readme.txt') = "Old stuff Tommy said not to delete`r`n$($p.FullName)"
        (Join-Path $downloads 'Taxes\H&R_Block_appointment.txt') = "March 12 - bring pension 1099-R and property tax bill"
        (Join-Path $downloads 'Photos from phone\put_photos_here.txt') = 'Denise transfers photos from my flip phone somehow'
    }
    foreach ($kv in $extras.GetEnumerator()) {
        Ensure-Dir (Split-Path $kv.Key -Parent)
        Set-Content -Path $kv.Key -Value $kv.Value -Encoding UTF8
    }

    Write-Log "Downloads seeded ($($manifest.Count) files) in $downloads" 'OK'
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

    $svc = Get-Service -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -match 'FuckScreen|FSC' -or $_.DisplayName -match 'FuckScreen|ScreenConnect.?Fuck|FSC'
    } | Select-Object -First 1
    $pf = Join-Path ${env:ProgramFiles} 'FuckScreenConnect'
    if (-not $script:Force -and ($svc -or (Test-Path $pf))) {
        Write-Log 'FuckScreenConnect already present - skipping install' 'OK'
        return
    }

    $tools = Get-AssetPath $script:Config.Paths.Tools
    Ensure-Dir $tools
    $work = Join-Path $tools 'FuckScreenConnect'
    Ensure-Dir $work

    $localZip = Get-ChildItem $tools -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match 'FuckScreenConnect.*\.(7z|zip)$' } |
        Select-Object -First 1

    if (-not $localZip -and -not $script:SkipDownloads) {
        try {
            $asset = Get-GithubLatestAsset -ApiUrl $script:Config.Moo.FuckScreenConnectApi -NameMatch @('\.7z$', '\.zip$')
            $zipPath = Join-Path $tools $asset.Name
            if (-not (Test-Path $zipPath) -or $script:Force) {
                Download-File -Url $asset.Url -OutFile $zipPath -MinBytes 50000
            }
            $localZip = Get-Item $zipPath
            Write-Log "Downloaded FSC $($asset.Tag) ($($asset.Name))" 'OK'
        }
        catch {
            throw "FuckScreenConnect download failed: $($_.Exception.Message). Place release .7z/.zip in assets\tools\"
        }
    }

    if (-not $localZip) {
        throw 'No FuckScreenConnect archive found. Download from https://github.com/RobotsOnDrugs/Moo.FuckScreenConnect-rs/releases'
    }

    if (Test-Path $work) { Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue }
    Ensure-Dir $work
    Expand-ArchiveSafe -Archive $localZip.FullName -Dest $work

    $installPs1 = Get-ChildItem $work -Recurse -Filter 'install.ps1' |
        Where-Object { $_.DirectoryName -notmatch 'install_modules' } |
        Select-Object -First 1
    if ($installPs1) {
        $mods = Join-Path $installPs1.DirectoryName 'install_modules'
        if (-not (Test-Path $mods)) {
            throw "FuckScreenConnect extract incomplete (missing install_modules). Delete tools\FuckScreenConnect* and re-run with 7-Zip installed."
        }
        Write-Log "Running $($installPs1.FullName)" 'INFO'
        # Fresh powershell.exe so #Requires / relative dot-sources in install.ps1 work reliably
        $p = Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $installPs1.FullName
        ) -WorkingDirectory $installPs1.DirectoryName -Wait -PassThru -WindowStyle Hidden
        if ($p.ExitCode -ne 0) {
            throw "FuckScreenConnect install.ps1 exited $($p.ExitCode). Open an admin PowerShell in $($installPs1.DirectoryName) and run .\install.ps1"
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
            throw 'Could not locate install.ps1 or service binary in the FuckScreenConnect archive'
        }
    }
}

function Install-ScambaitNoBlockInput {
    Write-Log 'Installing Moo.NoBlockInput...' 'INFO'
    $dest = Join-Path ${env:ProgramFiles} 'NoBlockInput'
    $startupLnk = Join-Path ([Environment]::GetFolderPath('Startup')) 'Input Protection.lnk'
    if (-not $script:Force -and (Test-Path $dest) -and (Get-ChildItem $dest -Recurse -Filter '*.exe' -ErrorAction SilentlyContinue | Select-Object -First 1)) {
        Write-Log 'NoBlockInput already present - skipping install' 'OK'
        if (-not (Test-Path $startupLnk)) {
            $injector = Get-ChildItem $dest -Recurse -Filter '*.exe' | Select-Object -First 1
            if ($injector) {
                $shell = New-Object -ComObject WScript.Shell
                $lnk = $shell.CreateShortcut($startupLnk)
                $lnk.TargetPath = $injector.FullName
                $lnk.WorkingDirectory = $injector.DirectoryName
                $lnk.WindowStyle = 7
                $lnk.Save()
            }
        }
        return
    }

    $tools = Get-AssetPath $script:Config.Paths.Tools
    Ensure-Dir $tools
    $work = Join-Path $tools 'NoBlockInput'
    Ensure-Dir $work

    $localZip = Get-ChildItem $tools -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match 'NoBlockInput|noblock' -and $_.Extension -match '\.(7z|zip)$' } |
        Select-Object -First 1

    if (-not $localZip -and -not $script:SkipDownloads) {
        try {
            $asset = Get-GithubLatestAsset -ApiUrl $script:Config.Moo.NoBlockInputApi -NameMatch @('\.7z$', '\.zip$')
            $zipPath = Join-Path $tools $asset.Name
            if (-not (Test-Path $zipPath) -or $script:Force) {
                Download-File -Url $asset.Url -OutFile $zipPath -MinBytes 50000
            }
            $localZip = Get-Item $zipPath
            Write-Log "Downloaded NoBlockInput $($asset.Tag) ($($asset.Name))" 'OK'
        }
        catch {
            throw "NoBlockInput download failed: $($_.Exception.Message). Place release .7z in assets\tools\"
        }
    }

    if (-not $localZip) {
        throw 'No NoBlockInput archive found. Releases are .7z only: https://github.com/RobotsOnDrugs/Moo.NoBlockInput/releases'
    }

    if (Test-Path $work) { Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue }
    Ensure-Dir $work
    Expand-ArchiveSafe -Archive $localZip.FullName -Dest $work

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
        throw 'No executable found in NoBlockInput archive'
    }
}
#endregion


#region Install-Micerosoft
function Install-ScambaitMicerosoft {
    Write-Log 'Installing Micerosoft fake support popup...' 'INFO'
    $dest = Join-Path ${env:ProgramFiles} 'Micerosoft'
    $deskLnk = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Micerosoft.lnk'
    if (-not $script:Force -and (Test-Path (Join-Path $dest 'popup.html')) -and (Test-Path $deskLnk)) {
        Write-Log 'Micerosoft popup already installed - skipping' 'OK'
        return
    }

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
        $local = Get-ChildItem $tools -Filter 'xampp*.exe' -ErrorAction SilentlyContinue |
            Where-Object { $_.Length -gt 50MB } |
            Select-Object -First 1
        if ($local) { $installer = $local.FullName }

        $needDownload = $script:Force -or -not (Test-Path $installer) -or ((Get-Item $installer -ErrorAction SilentlyContinue).Length -lt 50MB)
        if ($needDownload -and -not $script:SkipDownloads) {
            $urls = @()
            if ($x.DownloadUrls) { $urls += @($x.DownloadUrls) }
            if ($x.DownloadUrl) { $urls += $x.DownloadUrl }
            if ($x.DownloadUrlAlt) { $urls += $x.DownloadUrlAlt }
            $urls = $urls | Where-Object { $_ } | Select-Object -Unique
            $min = if ($x.MinBytes) { [long]$x.MinBytes } else { 100000000 }
            $ok = $false
            foreach ($url in $urls) {
                try {
                    Download-File -Url $url -OutFile $installer -MinBytes $min
                    $ok = $true
                    break
                }
                catch {
                    Write-Log "XAMPP URL failed: $($_.Exception.Message)" 'WARN'
                }
            }

            # Portable 7z fallback (no NSIS installer needed)
            if (-not $ok -and $x.PortableUrl) {
                try {
                    Write-Log 'Trying XAMPP portable .7z fallback...' 'INFO'
                    $portableArc = Join-Path $tools 'xampp-portable.7z'
                    Download-File -Url $x.PortableUrl -OutFile $portableArc -MinBytes 50000000
                    $extractTmp = Join-Path $script:WorkDir 'xampp-extract'
                    Expand-ArchiveSafe -Archive $portableArc -Dest $extractTmp
                    $found = Get-ChildItem $extractTmp -Recurse -Filter 'xampp-control.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
                    if (-not $found) { throw 'Portable archive extracted but xampp-control.exe not found' }
                    $srcRoot = $found.DirectoryName
                    Ensure-Dir (Split-Path $x.InstallDir -Parent)
                    if (Test-Path $x.InstallDir) { Remove-Item $x.InstallDir -Recurse -Force -ErrorAction SilentlyContinue }
                    Copy-Item $srcRoot $x.InstallDir -Recurse -Force
                    $ok = $true
                    Write-Log "XAMPP portable staged at $($x.InstallDir)" 'OK'
                }
                catch {
                    Write-Log "XAMPP portable fallback failed: $($_.Exception.Message)" 'WARN'
                }
            }

            if (-not $ok -and -not (Test-Path (Join-Path $x.InstallDir 'xampp-control.exe'))) {
                throw 'XAMPP download failed from all mirrors. Manually download from https://www.apachefriends.org/ into the tools folder as xampp-installer.exe'
            }
        }

        if (-not (Test-Path (Join-Path $x.InstallDir 'xampp-control.exe'))) {
            if (-not (Test-Path $installer) -or ((Get-Item $installer).Length -lt 50MB)) {
                throw 'XAMPP installer missing or corrupt (too small). Place a real installer EXE in the tools folder.'
            }

            Write-Log 'Running XAMPP silent-ish install (may show UI on some builds)...' 'INFO'
            # XAMPP NSIS installer: /S silent, dir via /D=
            $p = Start-Process -FilePath $installer -ArgumentList '/S', "/D=$($x.InstallDir)" -Wait -PassThru
            Write-Log "XAMPP installer exit code: $($p.ExitCode)" 'INFO'
            Start-Sleep 3
        }
    }
    else {
        Write-Log "XAMPP already present at $($x.InstallDir)" 'INFO'
    }

    if (-not (Test-Path (Join-Path $x.InstallDir 'xampp-control.exe'))) {
        throw 'XAMPP does not appear installed - aborting DSJAS steps'
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
Write-Log "State: $script:StatePath (use -Force to re-run completed steps)" 'INFO'
Write-Log "Persona: $($script:Config.Persona.FullName) / $($script:Config.Persona.ComputerName)" 'INFO'
Write-Log 'Host prerequisite: apply proxmox-smbios.conf on the Proxmox node for this VMID.' 'WARN'
if ($script:Force) { Write-Log 'Force mode: ignoring completion markers' 'WARN' }

Invoke-Step 'Sync GitHub / local media assets' 'SyncGitHubAssets' { Sync-ScambaitGitHubAssets } -OnceKey 'SyncGitHubAssets'
Invoke-Step 'Disable Windows Defender' 'DisableDefender' { Disable-ScambaitDefender } -OnceKey 'DisableDefender'
Invoke-Step 'Disable Windows Update' 'DisableWindowsUpdate' { Disable-ScambaitWindowsUpdate } -OnceKey 'DisableWindowsUpdate'
Invoke-Step 'Disable Telemetry' 'DisableTelemetry' { Disable-ScambaitTelemetry } -OnceKey 'DisableTelemetry'
Invoke-Step 'Mask VM artifacts (guest-side)' 'MaskVmArtifacts' { Mask-ScambaitVmArtifacts } -OnceKey 'MaskVmArtifacts'
Invoke-Step 'Set computer name' 'SetComputerName' {
    $name = $script:Config.Persona.ComputerName
    if ((hostname) -eq $name) {
        Write-Log "Computer name already '$name'" 'OK'
        return
    }
    Rename-Computer -NewName $name -Force -ErrorAction SilentlyContinue
    Write-Log "Computer rename scheduled to '$name' (reboot required)" 'WARN'
} -OnceKey 'SetComputerName' -IsInstalled { (hostname) -eq $script:Config.Persona.ComputerName }
Invoke-Step 'Set timezone to Chicago (Central)' 'SetTimezone' {
    # Location Services "managed by org" only blocks auto-timezone from GPS.
    # tzutil / Set-TimeZone still work as Administrator.
    $tz = if ($script:Config.Persona.Timezone) { $script:Config.Persona.Timezone } else { 'Central Standard Time' }
    if (-not $script:Force -and (Get-TimeZone).Id -eq $tz) {
        Write-Log "Timezone already $tz" 'OK'
        return
    }

    # Turn off automatic time zone (location-based)
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\tzautoupdate' -Name 'Start' -Value 4 -Force -ErrorAction SilentlyContinue
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location' -Name 'Value' -Value 'Deny' -Type ([Microsoft.Win32.RegistryValueKind]::String)
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors' -Name 'DisableLocation' -Value 1
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors' -Name 'DisableLocationScripting' -Value 1
    Set-RegistryValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters' -Name 'Type' -Value 'NTP' -Type ([Microsoft.Win32.RegistryValueKind]::String)

    try {
        Set-TimeZone -Id $tz -ErrorAction Stop
        Write-Log "Set-TimeZone -> $tz" 'OK'
    }
    catch {
        Write-Log "Set-TimeZone failed ($($_.Exception.Message)); trying tzutil..." 'WARN'
        & tzutil.exe /s $tz
        if ($LASTEXITCODE -ne 0) { throw "tzutil failed for '$tz'" }
        Write-Log "tzutil /s `"$tz`" OK" 'OK'
    }

    Start-Service w32time -ErrorAction SilentlyContinue
    w32tm /resync /force 2>$null | Out-Null

    $current = (Get-TimeZone).Id
    Write-Log "Current timezone: $current | $(Get-Date)" 'INFO'
    if ($current -ne $tz) {
        Write-Log "Timezone still '$current' (wanted '$tz'). Re-run elevated or check for conflicting domain GPO." 'WARN'
    }
} -OnceKey 'SetTimezone'
Invoke-Step 'Rename Device Manager entries' 'RenameDevices' { Rename-ScambaitDevices } -OnceKey 'RenameDevices'
Invoke-Step 'Disguise QEMU Guest Agent' 'DisguiseQemuAgent' { Disguise-ScambaitQemuAgent } -OnceKey 'DisguiseQemuAgent'
Invoke-Step 'Add fake printer' 'AddFakePrinter' { Add-ScambaitFakePrinter } -OnceKey 'AddFakePrinter' -IsInstalled {
    [bool](Get-Printer -Name $script:Config.FakePrinter.Name -ErrorAction SilentlyContinue)
}
Invoke-Step 'Install common programs' 'InstallPrograms' { Install-ScambaitPrograms }
Invoke-Step 'Set Chrome as default browser' 'SetChromeDefaults' { Set-ScambaitChromeDefaults } -OnceKey 'SetChromeDefaults'
Invoke-Step 'Generate personal files' 'GeneratePersonalFiles' { Generate-ScambaitPersonalFiles } -OnceKey 'GeneratePersonalFiles' -IsInstalled {
    Test-Path (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Passwords\accounts_backup.txt')
}
Invoke-Step 'Copy wallpapers' 'CopyWallpapers' { Copy-ScambaitWallpapers } -OnceKey 'CopyWallpapers' -IsInstalled {
    $d = Join-Path ([Environment]::GetFolderPath('MyPictures')) 'Wallpapers'
    (Test-Path $d) -and [bool](Get-ChildItem $d -File -ErrorAction SilentlyContinue | Select-Object -First 1)
}
Invoke-Step 'Seed Downloads folder' 'SeedDownloads' { Seed-ScambaitDownloads } -OnceKey 'SeedDownloads' -IsInstalled {
    $dl = (New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path
    if (-not $dl) { $dl = Join-Path $env:USERPROFILE 'Downloads' }
    Test-Path (Join-Path $dl 'how_to_use_gmail_notes.txt')
}
Invoke-Step 'Seed Chrome history' 'SeedChromeHistory' { Seed-ScambaitChromeHistory } -OnceKey 'SeedChromeHistory' -IsInstalled {
    Test-ScambaitChromeHistoryPopulated
}
Invoke-Step 'Setup camera loop' 'SetupCameraLoop' { Setup-ScambaitCameraLoop } -OnceKey 'SetupCameraLoop' -IsInstalled {
    $dir = $script:Config.Camera.InstallDir
    (Test-Path (Join-Path $dir 'hp_image_feed.py')) -and
    [bool](Get-ScheduledTask -TaskName $script:Config.Camera.TaskName -ErrorAction SilentlyContinue)
}
Invoke-Step 'Install Moo.FuckScreenConnect' 'InstallFuckScreenConnect' { Install-ScambaitFuckScreenConnect } -OnceKey 'InstallFuckScreenConnect' -IsInstalled {
    (Test-Path (Join-Path ${env:ProgramFiles} 'FuckScreenConnect')) -or
    [bool](Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'FuckScreen|FSC' -or $_.DisplayName -match 'FuckScreen' } | Select-Object -First 1)
}
Invoke-Step 'Install Moo.NoBlockInput' 'InstallNoBlockInput' { Install-ScambaitNoBlockInput } -OnceKey 'InstallNoBlockInput' -IsInstalled {
    Test-Path (Join-Path ${env:ProgramFiles} 'NoBlockInput')
}
Invoke-Step 'Install Micerosoft fake popup' 'InstallMicerosoftPopup' { Install-ScambaitMicerosoft } -OnceKey 'InstallMicerosoftPopup' -IsInstalled {
    Test-Path (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Micerosoft.lnk')
}
Invoke-Step 'Install XAMPP + DSJAS' 'InstallXamppDsjas' { Install-ScambaitXamppDsjas } -OnceKey 'InstallXamppDsjas' -IsInstalled {
    $htdocs = Join-Path $script:Config.Xampp.InstallDir 'htdocs'
    (Test-Path (Join-Path $script:Config.Xampp.InstallDir 'xampp-control.exe')) -and (
        (Test-Path (Join-Path $htdocs 'Version.json')) -or (Test-Path (Join-Path $htdocs 'version.json')) -or (Test-Path (Join-Path $htdocs 'public'))
    )
}

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