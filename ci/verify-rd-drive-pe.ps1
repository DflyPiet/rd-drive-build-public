param(
  [Parameter(Mandatory=$true)][string]$Path
)
$ErrorActionPreference = 'Stop'
[byte[]]$pe = [IO.File]::ReadAllBytes($Path)
if ($pe.Length -lt 512) { throw "$Path is unexpectedly small." }
if ($pe[0] -ne 0x4d -or $pe[1] -ne 0x5a) { throw "$Path has no MZ header." }
$peOffset = [BitConverter]::ToInt32($pe, 0x3c)
if ($pe[$peOffset] -ne 0x50 -or $pe[$peOffset + 1] -ne 0x45) { throw "$Path has no PE header." }
$machine = [BitConverter]::ToUInt16($pe, $peOffset + 4)
if ($machine -ne 0x8664) { throw ("$Path is not x64. Machine=0x{0:x4}" -f $machine) }
$optionalHeader = $peOffset + 24
$magic = [BitConverter]::ToUInt16($pe, $optionalHeader)
if ($magic -ne 0x20b) { throw ("$Path is not PE32+. Magic=0x{0:x4}" -f $magic) }
$subsystem = [BitConverter]::ToUInt16($pe, $optionalHeader + 68)
if ($subsystem -ne 2) { throw "$Path is not Windows GUI subsystem. Subsystem=$subsystem" }
Write-Host "Verified: $Path is x64 PE32+ Windows GUI subsystem."
