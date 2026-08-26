$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$archive = Join-Path $projectRoot 'references\ai-studio\hourtv-android-streaming-2026-08-26.zip'
$expected = 'ED0D1FC439FC1CADFC0162ECFCBA0F050E973A1736CCEE0D93019AFCC84A53C0'

if (-not (Test-Path -LiteralPath $archive -PathType Leaf)) {
    throw "AI Studio reference archive not found: $archive"
}

$stream = [System.IO.File]::OpenRead($archive)
try {
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hashBytes = $sha256.ComputeHash($stream)
        $actual = ([System.BitConverter]::ToString($hashBytes)).Replace('-', '')
    }
    finally {
        $sha256.Dispose()
    }
}
finally {
    $stream.Dispose()
}
if ($actual -ne $expected) {
    throw "AI Studio reference hash mismatch. Expected $expected but found $actual."
}

Write-Output "AI Studio reference verified: $actual"
