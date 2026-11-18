# Restore the VPS ZIP, or explicitly use the older source-text bundle workflow.
[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [string]$SourceDir = $PSScriptRoot,
    [string]$BaseDir = 'C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5',
    [switch]$UseTextBundles,
    [switch]$OverwriteRuntimeState
)
$ErrorActionPreference = 'Stop'
$SourceDir = [IO.Path]::GetFullPath($SourceDir)
$BaseDir = [IO.Path]::GetFullPath($BaseDir).TrimEnd('\')
if (-not (Test-Path -LiteralPath $BaseDir -PathType Container) -or [IO.Path]::GetFileName($BaseDir) -ine 'MQL5') {
    throw 'Set -BaseDir to the existing MQL5 folder inside the VPS terminal File > Open Data Folder.'
}
$BasePrefix = $BaseDir + '\'
$OutputFiles = @{}


# Snapshot only the bytes present at open, even if MT5 keeps appending to a log.
# ReadWrite sharing is required for files held open by the daily logger.
function Read-Snapshot {
    param([string]$Path)
    $Stream = [IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,
                            ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
    $Memory = New-Object IO.MemoryStream
    try {
        [long]$Remaining = $Stream.Length
        $Buffer = New-Object byte[] 65536
        while ($Remaining -gt 0) {
            $Read = $Stream.Read($Buffer,0,[int][Math]::Min($Buffer.Length,$Remaining))
            if ($Read -eq 0) { throw "File shortened during snapshot: $Path" }
            $Memory.Write($Buffer,0,$Read)
            $Remaining -= $Read
        }
        return ,$Memory.ToArray()
    }
    finally { $Stream.Dispose(); $Memory.Dispose() }
}

function Get-Hash {
    param([byte[]]$Bytes)
    $Hasher = [Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($Hasher.ComputeHash($Bytes)).Replace('-','').ToLowerInvariant() }
    finally { $Hasher.Dispose() }
}
function Test-AllowedPath {
    param([string]$Relative)
    return ($Relative -match '^(Experts/Custom EAs|Indicators/Custom|Scripts/Custom)/.+\.(mq5|mqh|ex5)$' -or
        $Relative -match '^Include/Custom/.+\.(mqh|mq5)$' -or
        $Relative -match '^Tools/.+\.(ps1|psm1|psd1|py|json|toml|yaml|yml|ini|cfg|csv|txt|md|bat|cmd)$' -or
        $Relative -match '^(Files/Logs|Logs)/.+\.(log|txt)$' -or
        $Relative -match '^Files/marcotrades/LiveEA/.+\.(bin|csv)$' -or
        $Relative -match '^Files/marcotrades/BrokerExecution/.+\.csv$' -or
        $Relative -match '^Profiles/(Presets|Tester)/.+\.set$' -or
        $Relative -ieq 'Files/marcotrades/pip_units_reference.txt')
}
function Get-SafeTarget {
    param([string]$Relative)
    $Relative = $Relative.Replace('\','/')
    if ([IO.Path]::IsPathRooted($Relative) -or $Relative -match '[:\x00-\x1f]' -or
        $Relative -match '(^|/)(\.|\.\.)($|/)' -or $Relative.Contains('//') -or -not (Test-AllowedPath $Relative)) {
        throw "Unsafe or unsupported package path: $Relative"
    }
    foreach ($Part in $Relative.Split('/')) {
        if ($Part -match '[. ]$' -or $Part -match '^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\.|$)' -or
            $Part.IndexOfAny([IO.Path]::GetInvalidFileNameChars()) -ge 0) { throw "Invalid path component: $Relative" }
    }
    $Target = [IO.Path]::GetFullPath((Join-Path $BaseDir $Relative))
    if (Test-Path -LiteralPath $Target -PathType Container) { throw "A directory occupies the file destination: $Relative" }
    if (-not $Target.StartsWith($BasePrefix,[StringComparison]::OrdinalIgnoreCase)) { throw "Path escapes destination: $Relative" }
    # Do not follow a junction or symbolic link out of the selected destination.
    $Check = $Target
    while ($null -ne $Check -and $Check -ne '') {
        if (Test-Path -LiteralPath $Check) {
            $Item = Get-Item -LiteralPath $Check -Force
            if (($Item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Linked destination: $Check" }
        }
        $Check = [IO.Path]::GetDirectoryName($Check)
    }
    return $Target
}
function Add-Payload {
    param([string]$Relative,[byte[]]$Bytes)
    $Relative = $Relative.Replace('\','/')
    $null = Get-SafeTarget $Relative
    if ($OutputFiles.ContainsKey($Relative)) { throw "Duplicate package path: $Relative" }
    $OutputFiles[$Relative] = $Bytes
}
function Read-ZipBytes {
    param($Entry)
    $Stream = $Entry.Open()
    $Memory = New-Object IO.MemoryStream
    try { $Stream.CopyTo($Memory); return ,$Memory.ToArray() }
    finally { $Stream.Dispose(); $Memory.Dispose() }
}

$PackagePath = Join-Path $SourceDir 'mq5-vps-package.zip'
if (-not $UseTextBundles -and (Test-Path -LiteralPath $PackagePath -PathType Leaf)) {
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $Archive = [IO.Compression.ZipFile]::OpenRead($PackagePath)
    try {
        $Entries = @{}
        foreach ($Entry in $Archive.Entries) {
            $Name = $Entry.FullName.Replace('\','/')
            if ($Entries.ContainsKey($Name)) { throw "Duplicate ZIP entry: $Name" }
            $Entries[$Name] = $Entry
        }
        if (-not $Entries.ContainsKey('vps-manifest.json')) { throw 'Package manifest is missing.' }
        $Manifest = [Text.Encoding]::UTF8.GetString((Read-ZipBytes $Entries['vps-manifest.json'])) | ConvertFrom-Json
        if ($Manifest.Version -notin @(1,2) -or @($Manifest.Files).Count -eq 0) { throw 'Unsupported or empty package manifest.' }
        if (@($Manifest.SkippedLogs).Count -gt 0 -and $null -ne $Manifest.SkippedLogs) {
            Write-Warning "The export omitted unreadable logs: $($Manifest.SkippedLogs -join ', ')"
        }
        foreach ($Record in $Manifest.Files) {
            $Relative = [string]$Record.Path
            if (-not $Entries.ContainsKey($Relative)) { throw "Missing package file: $Relative" }
            $Bytes = Read-ZipBytes $Entries[$Relative]
            if ($Bytes.Length -ne $Record.Length -or (Get-Hash $Bytes) -ine $Record.SHA256) { throw "Package integrity check failed: $Relative" }
            Add-Payload $Relative $Bytes
        }
        if ($Entries.Count -ne $OutputFiles.Count + 1) { throw 'ZIP contains files not listed in its manifest.' }
    }
    finally { $Archive.Dispose() }
    Write-Host "Verified package: $PackagePath ($($OutputFiles.Count) files)" -ForegroundColor Cyan
}
else {
    if (-not $UseTextBundles) { Write-Warning 'No VPS ZIP found. Restoring legacy source bundles only; binary state and compiled programs are not included.' }
    $BundleNames = @('mq5_Indicators.txt','mq5-experts.txt','mq5-libraries.txt')
    if (Test-Path -LiteralPath (Join-Path $SourceDir 'mq5-scripts.txt') -PathType Leaf) { $BundleNames += 'mq5-scripts.txt' }
    foreach ($Name in $BundleNames) {
        $Path = Join-Path $SourceDir $Name
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Missing source bundle: $Path" }
        $Raw = [IO.File]::ReadAllText($Path)
        $Markers = [regex]::Matches($Raw,'(?m)^// FILE:[ \t]*(?<path>[^\r\n]+?)[ \t]*\r?$')
        if ($Markers.Count -eq 0 -and -not [string]::IsNullOrWhiteSpace($Raw)) { throw "No FILE markers found: $Path" }
        for ($Index=0; $Index -lt $Markers.Count; $Index++) {
            $Relative = $Markers[$Index].Groups['path'].Value.Trim()
            if ([IO.Path]::GetExtension($Relative) -notin @('.mq5','.mqh')) { throw "Unsupported source file: $Relative" }
            $Start = $Markers[$Index].Index + $Markers[$Index].Length
            $End = $Raw.Length
            if ($Index+1 -lt $Markers.Count) { $End=$Markers[$Index+1].Index }
            $Content = $Raw.Substring($Start,$End-$Start)
            $EndMarker = [regex]::Match($Content,'(?m)^// END FILE:[ \t]*'+[regex]::Escape($Relative)+'[ \t]*\r?$')
            if ($EndMarker.Success) { $Content=$Content.Substring(0,$EndMarker.Index) }
            # Remove wrapper separators, not // END FILE markers from the next source.
            $Content = [regex]::Replace($Content,'\A(?:\s*\r?\n|// =+\r?\n)+','')
            $Content = [regex]::Replace($Content,'(?:\r?\n// =+|\s)+\z','')
            if ([string]::IsNullOrWhiteSpace($Content)) { continue }
            $Content = $Content.Replace("`r`n","`n").Replace("`n","`r`n") + "`r`n"
            $Encoding = New-Object Text.UTF8Encoding($true)
            [byte[]]$Bytes = $Encoding.GetPreamble() + $Encoding.GetBytes($Content)
            Add-Payload $Relative $Bytes
        }
    }
    Write-Warning 'Text mode restores MQL source only. Use the ZIP to transfer Tools, Logs, compiled programs and runtime data. Recompile text-restored programs.'
}
if ($OutputFiles.Count -eq 0) { throw 'No deployable files were extracted.' }

# Verify every destination and integrity check before changing any target files.
$Targets = @{}
$ResolvedTargets = @{}
$LogCopies=0
foreach ($Relative in $OutputFiles.Keys) {
    $Target = Get-SafeTarget $Relative
    if ($Relative -match '^(Files/Logs|Logs)/' -and (Test-Path -LiteralPath $Target -PathType Leaf)) {
        $IncomingHash = Get-Hash $OutputFiles[$Relative]
        if ((Get-Hash (Read-Snapshot $Target)) -ne $IncomingHash) {
            # Preserve VPS history. Reimporting this exact snapshot is idempotent.
            $Parent = [IO.Path]::GetDirectoryName($Relative).Replace('\','/')
            $Name = [IO.Path]::GetFileNameWithoutExtension($Relative)
            $Extension = [IO.Path]::GetExtension($Relative)
            $Conflict = $Parent+'/Imported/'+$Name+'.'+$IncomingHash.Substring(0,16)+$Extension
            $Target = Get-SafeTarget $Conflict
            if ((Test-Path -LiteralPath $Target -PathType Leaf) -and (Get-Hash (Read-Snapshot $Target)) -ne $IncomingHash) {
                throw "Conflicting imported log snapshot already exists: $Conflict"
            }
            $LogCopies++
        }
    }
    if ($ResolvedTargets.ContainsKey($Target)) { throw "Multiple package files resolve to the same destination: $Target" }
    $ResolvedTargets[$Target] = $true
    $Targets[$Relative] = $Target
}
$BackupRoot = Join-Path $BaseDir ('.vps-backups\'+[datetime]::Now.ToString('yyMMdd_HHmmss')+'_'+[guid]::NewGuid().ToString('N').Substring(0,6))
# Verify the backup directory ancestors too, before any source file is overwritten.
$Check = $BackupRoot
while ($Check -and $Check.StartsWith($BaseDir,[StringComparison]::OrdinalIgnoreCase)) {
    if (Test-Path -LiteralPath $Check) {
        if (((Get-Item -LiteralPath $Check -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Linked backup directory: $Check" }
    }
    $Check=[IO.Path]::GetDirectoryName($Check)
}
$Created=0; $Unchanged=0; $Preserved=0; $BackedUp=0
foreach ($Relative in @($OutputFiles.Keys | Sort-Object)) {
    $Target = $Targets[$Relative]
    [byte[]]$Bytes = $OutputFiles[$Relative]
    $Exists = Test-Path -LiteralPath $Target -PathType Leaf
    if ($Exists -and (Get-Hash ((Read-Snapshot $Target))) -eq (Get-Hash $Bytes)) { $Unchanged++; continue }
    $Runtime = $Relative -match '^Files/marcotrades/(LiveEA|BrokerExecution)/'
    if ($Exists -and $Runtime -and -not $OverwriteRuntimeState) {
        Write-Warning "Preserving existing runtime data: $Relative. Use -OverwriteRuntimeState only when intentionally replacing it with the source snapshot."
        $Preserved++; continue
    }
    if ($PSCmdlet.ShouldProcess($Target,'Restore verified package file (back up existing file first)')) {
        if ($Exists) {
            $Backup = Join-Path $BackupRoot $Relative
            [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Backup)) | Out-Null
            [IO.File]::Copy($Target,$Backup,$false)
            $BackedUp++
        }
        [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Target)) | Out-Null
        [IO.File]::WriteAllBytes($Target,$Bytes)
        if ((Get-Hash ((Read-Snapshot $Target))) -ne (Get-Hash $Bytes)) { throw "Output verification failed: $Relative" }
        Write-Host "Restored: $($Target.Substring($BasePrefix.Length))" -ForegroundColor Green
        $Created++
    }
}
Write-Host "Restored: $Created; unchanged: $Unchanged; existing runtime files preserved: $Preserved."
if ($LogCopies -gt 0) { Write-Host "Different log versions kept separately in Imported subfolders: $LogCopies" }
if ($BackedUp -gt 0) { Write-Host "Backups: $BackupRoot" }
Write-Host "Destination: $BaseDir"
Write-Host 'Use the same account and magic number when continuing open trades. Stop the old EA before enabling the VPS copy.'
Write-Host 'Load your saved .set inputs and configure Algo Trading/WebRequest settings in the VPS terminal. This script does not launch MT5 or compile programs.'
