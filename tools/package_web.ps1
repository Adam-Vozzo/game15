$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$packPath = Join-Path $projectRoot 'docs/index.pck'
$zipPath = Join-Path $projectRoot 'docs/index.zip'
$worldPath = Join-Path $projectRoot 'docs/worlds.zip'
# Godot supports ZIP as the main resource pack. Repackage the exact exported
# resources losslessly so GitHub Pages stays below the 100 MiB file limit.
$reader = [System.IO.BinaryReader]::new([System.IO.File]::OpenRead($packPath))
$zipStream = $null
$archive = $null
$worldStream = $null
$worldArchive = $null
try {
    if ($reader.ReadUInt32() -ne 0x43504447) { throw 'Invalid Godot pack signature' }
    if ($reader.ReadUInt32() -ne 4) { throw 'Review packaging for this new Godot PCK format' }
    $reader.BaseStream.Position = 20
    if ($reader.ReadUInt32() -ne 2) { throw 'Only unencrypted relative-offset packs are supported' }
    $fileBase = $reader.ReadUInt64()
    $directory = $reader.ReadUInt64()
    $reader.BaseStream.Position = $directory
    $count = $reader.ReadUInt32()
    $entries = @()
    for ($i=0; $i -lt $count; $i++) {
        $length = $reader.ReadUInt32()
        $name = [System.Text.Encoding]::UTF8.GetString($reader.ReadBytes($length)).TrimEnd([char]0)
        $offset = $reader.ReadUInt64()
        $size = $reader.ReadUInt64()
        $digest = $reader.ReadBytes(16)
        if ($reader.ReadUInt32() -ne 0) { throw "Unsupported resource flags for $name" }
        if ($name.StartsWith('/') -or $name.Contains('..') -or $offset+$fileBase+$size -gt $directory) { throw "Invalid pack entry $name" }
        $entries += @{Name=$name;Offset=$offset+$fileBase;Size=$size;Digest=$digest}
    }
    $zipStream = [System.IO.File]::Create($zipPath)
    $archive = [System.IO.Compression.ZipArchive]::new($zipStream,[System.IO.Compression.ZipArchiveMode]::Create,$true)
    $worldStream = [System.IO.File]::Create($worldPath)
    $worldArchive = [System.IO.Compression.ZipArchive]::new($worldStream,[System.IO.Compression.ZipArchiveMode]::Create,$true)
    foreach ($entry in $entries) {
        $reader.BaseStream.Position = $entry.Offset
        $bytes = $reader.ReadBytes([int]$entry.Size)
        $hash = [System.Security.Cryptography.MD5]::HashData($bytes)
        if ([Convert]::ToHexString($hash) -ne [Convert]::ToHexString($entry.Digest)) { throw "Pack checksum mismatch: $($entry.Name)" }
        $targetArchive = $archive
        if ($entry.Name -match '^\.godot/imported/(lowwater|signal_grove)\.glb-.*\.scn$') { $targetArchive = $worldArchive }
        $item = $targetArchive.CreateEntry($entry.Name,[System.IO.Compression.CompressionLevel]::Optimal)
        $item.LastWriteTime = [DateTimeOffset]::new(2026,1,1,0,0,0,[TimeSpan]::Zero)
        $destination = $item.Open()
        try { $destination.Write($bytes,0,$bytes.Length) } finally { $destination.Dispose() }
    }
    $archive.Dispose(); $archive=$null
    $zipStream.Dispose(); $zipStream=$null
    $worldArchive.Dispose(); $worldArchive=$null
    $worldStream.Dispose(); $worldStream=$null
    $size = (Get-Item -LiteralPath $zipPath).Length
    $worldSize = (Get-Item -LiteralPath $worldPath).Length
    if ($size -ge 100MB -or $worldSize -ge 100MB) { throw 'A web pack still exceeds GitHub file limit' }
    [System.IO.File]::WriteAllText((Join-Path $projectRoot 'docs/pack.js'),"const STILL_PACK = {`"file`":`"index.zip`",`"size`":$size,`"extra`":{`"file`":`"worlds.zip`",`"size`":$worldSize}};`n")
    Write-Host "PASS: $count checksummed resources packaged losslessly into $size + $worldSize bytes"
} finally {
    if ($archive) { $archive.Dispose() }
    if ($zipStream) { $zipStream.Dispose() }
    if ($worldArchive) { $worldArchive.Dispose() }
    if ($worldStream) { $worldStream.Dispose() }
    $reader.Dispose()
}
# Only this exact generated pack is removed, after its ZIP replacement succeeds.
Remove-Item -LiteralPath $packPath
