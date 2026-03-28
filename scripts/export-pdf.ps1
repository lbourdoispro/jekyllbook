param(
    [string]$SiteUrl = "https://lbourdois.github.io/NYU-DLSP21",
    [ValidateSet("fr", "en")]
    [string]$Lang = "fr",
    [ValidateSet("light", "rust", "coal", "navy", "ayu")]
    [string]$Theme = "ayu",
    [string]$OutputPath = "",
    [int]$WaitMs = 20000,
    [string]$BrowserPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-BrowserPath {
    param([string]$RequestedPath)

    if ($RequestedPath) {
        if (-not (Test-Path $RequestedPath)) {
            throw "Browser path not found: $RequestedPath"
        }
        return $RequestedPath
    }

    $candidates = @(
        "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
        "C:\Program Files\Microsoft\Edge\Application\msedge.exe",
        "C:\Program Files\Google\Chrome\Application\chrome.exe"
    )

    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            return $candidate
        }
    }

    throw "No Chromium browser found. Install Microsoft Edge or Google Chrome, or pass -BrowserPath."
}

function Normalize-SiteUrl {
    param([string]$Url)

    if ($Url.EndsWith("/")) {
        return $Url.TrimEnd("/")
    }

    return $Url
}

function Build-PrintUrl {
    param(
        [string]$BaseUrl,
        [string]$Language,
        [string]$CurrentTheme
    )

    if ($Language -eq "fr") {
        return "$BaseUrl/fr/print/?theme=$CurrentTheme"
    }

    return "$BaseUrl/print/?theme=$CurrentTheme"
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$outputDirectory = Join-Path $repoRoot "pdf-output"
$browser = Get-BrowserPath -RequestedPath $BrowserPath
$normalizedSiteUrl = Normalize-SiteUrl -Url $SiteUrl
$printUrl = Build-PrintUrl -BaseUrl $normalizedSiteUrl -Language $Lang -CurrentTheme $Theme

if (-not $OutputPath) {
    $OutputPath = Join-Path $outputDirectory "$Lang-$Theme.pdf"
}

$outputDirectoryForFile = Split-Path -Parent $OutputPath
if (-not (Test-Path $outputDirectoryForFile)) {
    New-Item -ItemType Directory -Path $outputDirectoryForFile | Out-Null
}

$tempProfile = Join-Path $env:TEMP ("jekyllbook-pdf-" + [guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $tempProfile | Out-Null

try {
    $resolvedOutputPath = [System.IO.Path]::GetFullPath($OutputPath)
    $browserArgs = @(
        "--headless",
        "--disable-gpu",
        "--no-first-run",
        "--run-all-compositor-stages-before-draw",
        "--virtual-time-budget=$WaitMs",
        "--user-data-dir=$tempProfile",
        "--print-to-pdf=$resolvedOutputPath",
        "--print-to-pdf-no-header",
        $printUrl
    )

    $process = Start-Process -FilePath $browser -ArgumentList $browserArgs -Wait -PassThru -NoNewWindow

    Start-Sleep -Milliseconds 1000

    if (-not (Test-Path $resolvedOutputPath)) {
        throw "PDF export failed: file was not created."
    }

    Write-Host "PDF generated:"
    Write-Host $resolvedOutputPath
    Write-Host ""
    Write-Host "Source URL:"
    Write-Host $printUrl
}
finally {
    if (Test-Path $tempProfile) {
        Remove-Item -Recurse -Force $tempProfile
    }
}
