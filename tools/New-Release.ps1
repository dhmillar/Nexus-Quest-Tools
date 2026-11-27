$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$addon = Join-Path $root 'NQT'
$expected = @('Bindings.xml','Core.lua','DungeonCatalog.lua','DungeonPosition.lua','EverlootDrops.lua','ForeverQuestFacts.lua','ForeverTownPins.lua','ForeverVerifiedEndpoints.lua','HunterDeadzone.lua','HunterDeadzone.tga','LeftoverTrash.tga','LevelGuide.lua','LevelGuideData.lua','LevelGuideGivers.lua','LevelGuideObjectiveText.lua','LevelGuideWindowControls.tga','LevelGuideZoneRanges.lua','MacroMobTooltip.lua','MinimapAT.tga','NextMob.lua','NQT.toc','Options.lua','PartyPerson.tga','PartyProgress.lua','Portrait.lua','QuestHUD.lua','QuestItems.lua','QuestStartAlert.lua','QuestLeftovers.lua','QuestMapPins.lua','QuestMenu.lua','QuestMobData.lua','QuestMobs.lua','Quests.lua','QueueBadge.tga','README.md','Roads.lua','Route.lua','ShareArrow.tga','SmartTarget.lua','Target.lua','Walking.lua','WorldRoute.lua')
$files = @(Get-ChildItem -LiteralPath $addon -Force)
if (Compare-Object ($files.Name | Sort-Object) ($expected | Sort-Object)) { throw 'Review any new or missing addon file before packaging.' }
if ($files | Where-Object { $_.PSIsContainer -or ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) }) { throw 'Unexpected addon directory or linked file.' }
$toc = Get-Content -LiteralPath (Join-Path $addon 'NQT.toc')
$version = [regex]::Match(($toc -join "`n"), '(?m)^## Version: (\d+\.\d+\.\d+)\s*$').Groups[1].Value
if (-not $version -or -not ($toc -match '^## Interface: 16001\s*$')) { throw 'Expected a Forever TOC with a numeric version.' }
foreach ($line in $toc) {
    if ($line -match '\.(lua|xml)$' -and $line -notin $expected) { throw "Unexpected TOC entry: $line" }
}
$dist = Join-Path $root 'dist'
$null = New-Item -ItemType Directory -Force -Path $dist
$zip = Join-Path $dist "NexusQuestTools-$version-forever.zip"
if (Test-Path -LiteralPath $zip) { throw 'Build destination already exists. Keep previous versioned archives intact.' }
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::CreateFromDirectory($addon,$zip,[IO.Compression.CompressionLevel]::Optimal,$true)
$archive = [IO.Compression.ZipFile]::OpenRead($zip)
try {
    $paths = @($archive.Entries | Where-Object Name | ForEach-Object { $_.FullName.Replace('\','/') })
    if (Compare-Object ($paths | Sort-Object) ($expected | ForEach-Object { "NQT/$_" } | Sort-Object)) { throw 'Archive layout does not match the addon manifest.' }
} finally { $archive.Dispose() }
Get-FileHash -LiteralPath $zip -Algorithm SHA256
