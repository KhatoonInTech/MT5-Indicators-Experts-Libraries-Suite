# Offline tests: only temporary fixture files inside this MQL5 workspace are touched.
$ErrorActionPreference='Stop'
$Workspace = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..')).TrimEnd('\')
$TestRoot = Join-Path $Workspace ('.vps-test-'+[guid]::NewGuid().ToString('N').Substring(0,8))
$Export = Join-Path $Workspace 'Tools\VpsTransfer\MLQ2mlqhFiles.ps1'
$Import = Join-Path $Workspace 'Tools\VpsTransfer\ps12mlq.ps1'
$Checks=0
function Check($Condition,[string]$Message) { $script:Checks++; if (-not $Condition) { throw "FAIL: $Message" } }
function Put([string]$Path,[byte[]]$Bytes) {
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path)) | Out-Null
    [IO.File]::WriteAllBytes($Path,$Bytes)
}
function EqualBytes([string]$A,[string]$B) {
    return [Convert]::ToBase64String([IO.File]::ReadAllBytes($A)) -ceq [Convert]::ToBase64String([IO.File]::ReadAllBytes($B))
}
function MustFail([scriptblock]$Action,[string]$Message) {
    $Failed=$false
    try { & $Action | Out-Null } catch { $Failed=$true }
    Check $Failed $Message
}
try {
    [IO.Directory]::CreateDirectory($TestRoot) | Out-Null
    $Source=Join-Path $TestRoot 'source\MQL5'
    $Target=Join-Path $TestRoot 'target\MQL5'
    $Bundle=Join-Path $TestRoot 'bundles'
    $Utf8=New-Object Text.UTF8Encoding($true)
    $SourceText="// fixture`r`nvoid OnTick() { /* no trading */ }`r`n"
    [byte[]]$SourceBytes=$Utf8.GetPreamble()+$Utf8.GetBytes($SourceText)
    $Files=@{
        'Experts\Custom EAs\Marco\expert.mq5'=$SourceBytes
        'Experts\Custom EAs\Marco\expert.ex5'=[byte[]](0..255)
        'Indicators\Custom\Marco\indicator.mq5'=$SourceBytes
        'Indicators\Custom\Marco\indicator.ex5'=[byte[]](255..0)
        'Include\Custom\Marco\engine.mqh'=$SourceBytes
        'Include\Custom\Marcotrades\pivot_entry.mqh'=$SourceBytes
        'Scripts\Custom\helper.mq5'=$SourceBytes
        'Scripts\Custom\helper.ex5'=[byte[]](0,1,255)
        'Tools\Marcotrades\import_broker_rejections.py'=[Text.Encoding]::UTF8.GetBytes('# tool fixture')
        'Tools\VpsTransfer\ps12mlq.ps1'=[Text.Encoding]::UTF8.GetBytes('# transfer fixture')
        'Files\Logs\20261117\marco_live_auto_ea.log'=[Text.Encoding]::UTF8.GetBytes('daily log fixture')
        'Logs\20261117.log'=[Text.Encoding]::Unicode.GetBytes('native log fixture')
        'Files\marcotrades\LiveEA\TP_123_456_789.bin'=[byte[]](0,255,128,13,10,0,1)
        'Files\marcotrades\LiveEA\2026-11-13.csv'=[Text.Encoding]::Unicode.GetBytes("date;trade`r`n1;2")
        'Files\marcotrades\BrokerExecution\imported_rejections.csv'=[Text.Encoding]::UTF8.GetBytes('version;symbol')
        'Files\marcotrades\BrokerExecution\rejections_123_hash.csv'=[byte[]](1,2,3)
        'Files\marcotrades\pip_units_reference.txt'=[Text.Encoding]::UTF8.GetBytes('reference')
        'Profiles\Tester\demo.set'=[Text.Encoding]::Unicode.GetBytes('InpEntryTF=1')
        'Profiles\Presets\live.set'=[Text.Encoding]::UTF8.GetBytes('InpRisk=1')
    }
    foreach ($Path in $Files.Keys) { Put (Join-Path $Source $Path) $Files[$Path] }
    foreach ($Path in @('Files\marcotrades\IndicatorCache\cache.bin','Files\marcotrades\old-report.xls','Files\marcotrades\LiveEA\TP_123.tmp','Tools\__pycache__\helper.pyc','Tools\_review\helper.py','Tools\helper.py.bak','Tools\VpsTransfer\mq5-experts.txt')) {
        Put (Join-Path $Source $Path) ([byte[]](4,5,6))
    }
    [IO.Directory]::CreateDirectory($Target) | Out-Null
    $ActiveLog=[IO.File]::Open((Join-Path $Source 'Files\Logs\20261117\marco_live_auto_ea.log'),[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::Read)
    try { & $Export -ProjectRoot $Source -OutputRoot $Bundle | Out-Null }
    finally { $ActiveLog.Dispose() }
    Check (Test-Path -LiteralPath (Join-Path $Bundle 'mq5-vps-package.zip')) 'ZIP exists'
    & $Import -SourceDir $Bundle -BaseDir $Target -WhatIf | Out-Null
    Check (@(Get-ChildItem -LiteralPath $Target -Recurse -File).Count -eq 0) 'WhatIf is read only'
    & $Import -SourceDir $Bundle -BaseDir $Target | Out-Null
    foreach ($Path in $Files.Keys) { Check (EqualBytes (Join-Path $Source $Path) (Join-Path $Target $Path)) "Byte-exact restore: $Path" }
    Check (@(Get-ChildItem -LiteralPath $Target -Recurse -File).Count -eq $Files.Count) 'Only selected files restored'
    # Conflicting VPS logs must survive, including when open by a running logger.
    $Log=Join-Path $Target 'Files\Logs\20261117\marco_live_auto_ea.log'
    Put $Log ([Text.Encoding]::UTF8.GetBytes('VPS history'))
    $ActiveLog=[IO.File]::Open($Log,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::Read)
    try {
        & $Import -SourceDir $Bundle -BaseDir $Target -WhatIf | Out-Null
        Check (-not (Test-Path -LiteralPath (Join-Path $Target 'Files\Logs\20261117\Imported'))) 'WhatIf does not create log copies'
        & $Import -SourceDir $Bundle -BaseDir $Target | Out-Null
    } finally { $ActiveLog.Dispose() }
    Check ([IO.File]::ReadAllText($Log) -eq 'VPS history') 'Existing VPS log preserved'
    $Imported=@(Get-ChildItem -LiteralPath (Join-Path $Target 'Files\Logs\20261117\Imported') -File)
    Check ($Imported.Count -eq 1) 'Conflicting snapshot saved separately'
    Check (EqualBytes $Imported[0].FullName (Join-Path $Source 'Files\Logs\20261117\marco_live_auto_ea.log')) 'Imported log byte exact'
    & $Import -SourceDir $Bundle -BaseDir $Target | Out-Null
    Check (@(Get-ChildItem -LiteralPath (Join-Path $Target 'Files\Logs\20261117\Imported') -File).Count -eq 1) 'Repeated log import is idempotent'
    $NoLogs=Join-Path $TestRoot 'withoutlogs'
    & $Export -ProjectRoot $Source -OutputRoot $NoLogs -SkipLogs | Out-Null
    $Zip=[IO.Compression.ZipFile]::OpenRead((Join-Path $NoLogs 'mq5-vps-package.zip'))
    try {
        Check (@($Zip.Entries | Where-Object { $_.FullName -match '^(Files/Logs|Logs)/' }).Count -eq 0) 'SkipLogs excludes both log roots'
        Check ($null -ne $Zip.GetEntry('Tools/Marcotrades/import_broker_rejections.py')) 'SkipLogs keeps tools'
    } finally { $Zip.Dispose() }
    # Existing live state and rejection evidence are preserved; code updates receive backups.
    $State=Join-Path $Target 'Files\marcotrades\LiveEA\TP_123_456_789.bin'
    $Code=Join-Path $Target 'Experts\Custom EAs\Marco\expert.mq5'
    Put $State ([byte[]](9,8,7));Put $Code ([Text.Encoding]::UTF8.GetBytes('older code'))
    & $Import -SourceDir $Bundle -BaseDir $Target | Out-Null
    Check ([Convert]::ToBase64String([IO.File]::ReadAllBytes($State)) -eq 'CQgH') 'Existing runtime state preserved'
    Check (EqualBytes (Join-Path $Source 'Experts\Custom EAs\Marco\expert.mq5') $Code) 'Code updated'
    $Backups=@(Get-ChildItem -LiteralPath (Join-Path $Target '.vps-backups') -Recurse -File)
    Check (@($Backups | Where-Object { [IO.File]::ReadAllText($_.FullName) -eq 'older code' }).Count -eq 1) 'Previous code backed up'
    & $Import -SourceDir $Bundle -BaseDir $Target -OverwriteRuntimeState | Out-Null
    Check (EqualBytes (Join-Path $Source 'Files\marcotrades\LiveEA\TP_123_456_789.bin') $State) 'Explicit state replacement'
    $Backups=@(Get-ChildItem -LiteralPath (Join-Path $Target '.vps-backups') -Recurse -File)
    Check (@($Backups | Where-Object { [Convert]::ToBase64String([IO.File]::ReadAllBytes($_.FullName)) -eq 'CQgH' }).Count -eq 1) 'Previous state backed up'
    # Source bundle mode remains available even with a ZIP present, and strips END FILE wrappers.
    $TextTarget=Join-Path $TestRoot 'text\MQL5';[IO.Directory]::CreateDirectory($TextTarget) | Out-Null
    & $Import -SourceDir $Bundle -BaseDir $TextTarget -UseTextBundles | Out-Null
    Check (@(Get-ChildItem -LiteralPath $TextTarget -Recurse -File).Count -eq 5) 'Text mode restores only source including custom scripts'
    Check (EqualBytes (Join-Path $Source 'Experts\Custom EAs\Marco\expert.mq5') (Join-Path $TextTarget 'Experts\Custom EAs\Marco\expert.mq5')) 'Text roundtrip removes wrappers correctly'
    # Verify tampering is rejected before any destination writes.
    $Bad=Join-Path $TestRoot 'bad';[IO.Directory]::CreateDirectory($Bad) | Out-Null
    Copy-Item -LiteralPath (Join-Path $Bundle 'mq5-vps-package.zip') -Destination $Bad
    $Zip=[IO.Compression.ZipFile]::Open((Join-Path $Bad 'mq5-vps-package.zip'),[IO.Compression.ZipArchiveMode]::Update)
    $Zip.GetEntry('Experts/Custom EAs/Marco/expert.mq5').Delete()
    $Stream=$Zip.CreateEntry('Experts/Custom EAs/Marco/expert.mq5').Open()
    $Stream.WriteByte(42);$Stream.Dispose();$Zip.Dispose()
    $Empty=Join-Path $TestRoot 'badtarget\MQL5';[IO.Directory]::CreateDirectory($Empty) | Out-Null
    MustFail { & $Import -SourceDir $Bad -BaseDir $Empty } 'Corrupt package rejected'
    Check (@(Get-ChildItem -LiteralPath $Empty -Recurse -File).Count -eq 0) 'Corruption rejected before writes'
    # Traversal through a valid source-text marker is rejected too.
    [IO.File]::WriteAllText((Join-Path $Bundle 'mq5-experts.txt'),"// FILE: Experts\Custom EAs\..\..\..\escape.mq5`r`n// ===`r`nbad`r`n")
    MustFail { & $Import -SourceDir $Bundle -BaseDir $Empty -UseTextBundles } 'Traversal rejected'
    Check (@(Get-ChildItem -LiteralPath $Empty -Recurse -File).Count -eq 0) 'Traversal rejected before writes'
    MustFail { & $Import -SourceDir $Bundle -BaseDir (Join-Path $TestRoot 'wrong') } 'Missing destination rejected'
    Write-Host "PASS: $Checks VPS transfer checks" -ForegroundColor Green
}
finally {
    # Delete only the verified, uniquely named fixture directory under this workspace.
    $Resolved=[IO.Path]::GetFullPath($TestRoot)
    if ($Resolved.StartsWith($Workspace+'\',[StringComparison]::OrdinalIgnoreCase) -and
        [IO.Path]::GetFileName($Resolved) -like '.vps-test-*' -and (Test-Path -LiteralPath $Resolved)) {
        Remove-Item -LiteralPath $Resolved -Recurse -Force
    }
}
