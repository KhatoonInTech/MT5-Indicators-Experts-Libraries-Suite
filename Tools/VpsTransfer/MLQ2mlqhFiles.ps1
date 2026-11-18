# Export custom code plus the files required to move Marcotrades to another MT5 terminal.
[CmdletBinding()]
param(
    [string]$ProjectRoot = 'C:\Users\Super\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5',
    [string]$OutputRoot = $PSScriptRoot,
    [switch]$SkipLogs
)
$ErrorActionPreference = 'Stop'
$ProjectRoot = [IO.Path]::GetFullPath($ProjectRoot).TrimEnd('\')
$OutputRoot = [IO.Path]::GetFullPath($OutputRoot)
if (-not (Test-Path -LiteralPath $ProjectRoot -PathType Container)) { throw "MQL5 folder not found: $ProjectRoot" }
[IO.Directory]::CreateDirectory($OutputRoot) | Out-Null
$Utf8Bom = New-Object System.Text.UTF8Encoding($true)


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

# Refuse linked files/folders rather than packaging data outside the selected MQL5 tree.
function Assert-LocalFile {
    param([string]$Path)
    $Item = Get-Item -LiteralPath $Path -Force
    while ($null -ne $Item) {
        if (($Item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Linked path cannot be exported: $Path" }
        if ($Item.FullName.TrimEnd('\') -ieq $ProjectRoot) { return }
        if ($Item -is [IO.FileInfo]) { $Item = $Item.Directory } else { $Item = $Item.Parent }
    }
    throw "File outside MQL5 folder: $Path"
}

function Get-SourceFiles {
    param([string[]]$RelativeRoots)

    $Files = @()
    foreach ($RelativeRoot in $RelativeRoots) {
        $SourceRoot = Join-Path $ProjectRoot $RelativeRoot
        if (Test-Path -LiteralPath $SourceRoot) {
            $Files += Get-ChildItem -LiteralPath $SourceRoot -Recurse -File |
                Where-Object { $_.Extension -ieq '.mq5' -or $_.Extension -ieq '.mqh' }
        }
    }

    $Files | Sort-Object FullName
}

function Write-CodeBundle {
    param(
        [string]$BundlePath,
        [object[]]$Files
    )

    $Builder = New-Object System.Text.StringBuilder
    $PrefixLength = $ProjectRoot.Length + 1

    foreach ($File in $Files) {
        Assert-LocalFile $File.FullName
        $Relative = $File.FullName.Substring($PrefixLength) -replace '/', '\'

        [void]$Builder.AppendLine('// ============================================================================')
        [void]$Builder.AppendLine("// FILE: $Relative")
        [void]$Builder.AppendLine('// ============================================================================')
        $Content = [System.IO.File]::ReadAllText($File.FullName)
        [void]$Builder.Append($Content.TrimEnd("`r", "`n"))
        [void]$Builder.AppendLine()
        [void]$Builder.AppendLine()
        [void]$Builder.AppendLine("// END FILE: $Relative")
        [void]$Builder.AppendLine()
    }

    [System.IO.File]::WriteAllText($BundlePath, $Builder.ToString(), $Utf8Bom)
}

$Experts = @(Get-SourceFiles @('Experts\Custom EAs'))
$Indicators = @(Get-SourceFiles @('Indicators\Custom'))
$Libraries = @(Get-SourceFiles @('Include\Custom'))
$Scripts = @(Get-SourceFiles @('Scripts\Custom'))
$Guardrails = @($Experts + $Indicators + $Libraries |
    Where-Object { $_.Name -match '(?i)guardrail|guardrais' } |
    Sort-Object FullName)

Write-CodeBundle (Join-Path $OutputRoot 'mq5-experts.txt') $Experts
Write-CodeBundle (Join-Path $OutputRoot 'mq5_Indicators.txt') $Indicators
Write-CodeBundle (Join-Path $OutputRoot 'mq5-libraries.txt') $Libraries
Write-CodeBundle (Join-Path $OutputRoot 'mq5-scripts.txt') $Scripts
Write-CodeBundle (Join-Path $OutputRoot 'Gurdrail system.txt') $Guardrails

'UPDATED BUNDLES'
"mq5-experts.txt      = $($Experts.Count) source files"
"mq5_Indicators.txt  = $($Indicators.Count) source files"
"mq5-libraries.txt   = $($Libraries.Count) source files"
"mq5-scripts.txt     = $($Scripts.Count) source files"
"Gurdrail system.txt = $($Guardrails.Count) source files"

''
'DIRECTORY STRUCTURE'
$Roots = @('Experts\Custom EAs','Indicators\Custom','Include\Custom','Scripts\Custom')
foreach ($Root in $Roots) {
    $RootPath = Join-Path $ProjectRoot $Root
    "[$Root]"
    if (-not (Test-Path -LiteralPath $RootPath)) { continue }
    Get-ChildItem -LiteralPath $RootPath -Recurse -File | Sort-Object FullName | ForEach-Object {
        $Relative = $_.FullName.Substring($RootPath.Length + 1) -replace '/', '\'
        "  $Relative"
    }
}
# A ZIP preserves .ex5, .bin, encodings and line endings byte for byte.
# Include tools and log snapshots. Simulation caches, backups, reports and temporary files are excluded.
$Rules = @(
    @{ Root='Experts\Custom EAs'; Extensions=@('.mq5','.mqh','.ex5') },
    @{ Root='Indicators\Custom'; Extensions=@('.mq5','.mqh','.ex5') },
    @{ Root='Include\Custom'; Extensions=@('.mqh','.mq5') },
    @{ Root='Scripts\Custom'; Extensions=@('.mq5','.mqh','.ex5') },
    @{ Root='Tools'; Extensions=@('.ps1','.psm1','.psd1','.py','.json','.toml','.yaml','.yml','.ini','.cfg','.csv','.txt','.md','.bat','.cmd') },
    @{ Root='Files\marcotrades\LiveEA'; Extensions=@('.bin','.csv') },
    @{ Root='Files\marcotrades\BrokerExecution'; Extensions=@('.csv') },
    @{ Root='Profiles\Presets'; Extensions=@('.set') },
    @{ Root='Profiles\Tester'; Extensions=@('.set') }
)
if (-not $SkipLogs) {
    $Rules += @{ Root='Files\Logs'; Extensions=@('.log','.txt') }
    $Rules += @{ Root='Logs'; Extensions=@('.log','.txt') }
}
$PackageFiles = @{}
foreach ($Rule in $Rules) {
    $RootPath = Join-Path $ProjectRoot $Rule.Root
    if (-not (Test-Path -LiteralPath $RootPath -PathType Container)) { continue }
    foreach ($File in Get-ChildItem -LiteralPath $RootPath -File -Recurse) {
        if ($File.Extension.ToLowerInvariant() -notin $Rule.Extensions) { continue }
        Assert-LocalFile $File.FullName
        $Relative = $File.FullName.Substring($ProjectRoot.Length + 1).Replace('\','/')
        if ($Relative -match '(^|/)(__pycache__|\.git|\.venv|venv|node_modules|_review|\.vps-backups)(/|$)' -or
            $File.Name -match '(?i)\.(bak|backup|tmp)(\.|$)' -or
            ($Relative -match '^Tools/' -and $File.Name -in @('mq5-experts.txt','mq5_Indicators.txt','mq5-libraries.txt','mq5-scripts.txt','Gurdrail system.txt'))) { continue }
        $PackageFiles[$Relative] = $File.FullName
    }
}
$Guide = Join-Path $ProjectRoot 'Files\marcotrades\pip_units_reference.txt'
if (Test-Path -LiteralPath $Guide -PathType Leaf) {
    Assert-LocalFile $Guide
    $PackageFiles['Files/marcotrades/pip_units_reference.txt'] = $Guide
}
if ($PackageFiles.Count -eq 0) { throw 'No deployable files found.' }

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$PackagePath = Join-Path $OutputRoot 'mq5-vps-package.zip'
$TemporaryPackage = $PackagePath + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
$ManifestFiles = @()
$SkippedLogs = @()
$Archive = [IO.Compression.ZipFile]::Open($TemporaryPackage,[IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($Relative in @($PackageFiles.Keys | Sort-Object)) {
        try { $Bytes = Read-Snapshot $PackageFiles[$Relative] }
        catch {
            if ($Relative -match '^(Files/Logs|Logs)/') {
                $SkippedLogs += $Relative
                Write-Warning "Log snapshot skipped: $Relative ($($_.Exception.Message))"
                continue
            }
            throw
        }
        $Hasher = [Security.Cryptography.SHA256]::Create()
        try { $Hash = [BitConverter]::ToString($Hasher.ComputeHash($Bytes)).Replace('-','').ToLowerInvariant() }
        finally { $Hasher.Dispose() }
        $Entry = $Archive.CreateEntry($Relative,[IO.Compression.CompressionLevel]::Optimal)
        $Stream = $Entry.Open()
        try { $Stream.Write($Bytes,0,$Bytes.Length) } finally { $Stream.Dispose() }
        $ManifestFiles += [pscustomobject]@{ Path=$Relative; Length=$Bytes.Length; SHA256=$Hash }
    }
    $Manifest = [ordered]@{ Version=2; ExportedUtc=[datetime]::UtcNow.ToString('o'); LogsIncluded=(-not $SkipLogs); SkippedLogs=$SkippedLogs; Files=$ManifestFiles }
    $Bytes = [Text.Encoding]::UTF8.GetBytes(($Manifest | ConvertTo-Json -Depth 5))
    $Stream = $Archive.CreateEntry('vps-manifest.json').Open()
    try { $Stream.Write($Bytes,0,$Bytes.Length) } finally { $Stream.Dispose() }
}
finally { $Archive.Dispose() }
Move-Item -LiteralPath $TemporaryPackage -Destination $PackagePath -Force

$Includes = @($PackageFiles.Values | Where-Object { [IO.Path]::GetExtension($_) -ieq '.mqh' } | Get-Item)
$LatestInclude = ($Includes | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1).LastWriteTimeUtc
$CompileNeeded = @()
foreach ($Source in @($Experts + $Indicators + $Scripts | Where-Object { $_.Extension -ieq '.mq5' })) {
    $Binary = [IO.Path]::ChangeExtension($Source.FullName,'.ex5')
    if (-not (Test-Path -LiteralPath $Binary -PathType Leaf)) { $CompileNeeded += $Source.FullName; continue }
    $Built = (Get-Item -LiteralPath $Binary).LastWriteTimeUtc
    if ($Built -lt $Source.LastWriteTimeUtc -or ($null -ne $LatestInclude -and $Built -lt $LatestInclude)) { $CompileNeeded += $Source.FullName }
}
Write-Host "VPS PACKAGE: $PackagePath ($($ManifestFiles.Count) files)" -ForegroundColor Green
if ($CompileNeeded.Count -gt 0) {
    Write-Warning "$($CompileNeeded.Count) programs have missing or possibly outdated .ex5 files. Compile the programs you use before enabling them on the VPS; source files are included."
}
Write-Host 'Tools and saved inputs are included.'
if ($SkipLogs) { Write-Host 'Log history excluded (-SkipLogs).' }
else { Write-Host 'Dated Files\Logs and native MQL5\Logs snapshots are included. Use -SkipLogs to omit log history.' }
if ($SkippedLogs.Count -gt 0) { Write-Warning "$($SkippedLogs.Count) log snapshots could not be read; see manifest SkippedLogs." }
Write-Host 'Upload mq5-vps-package.zip and ps12mlq.ps1. Restore with -BaseDir pointing to the VPS terminal MQL5 folder.'
Write-Host 'For an active-trade migration, stop the source EA before exporting its final LiveEA state. Do not run both copies.'
Write-Host 'Saved inputs are included when stored as .set under Profiles\Presets or Profiles\Tester. WebRequest settings must be configured in the VPS terminal.'
