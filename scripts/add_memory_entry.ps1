param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("active-context", "architecture-map", "decisions", "lessons", "change-log", "backlog")]
    [string]$File,

    [Parameter(Mandatory = $true)]
    [string]$Summary,

    [string]$Tags = "",

    [string]$Impact = ""
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$targetPath = Join-Path $repoRoot ("docs\memory\" + $File + ".md")
$date = Get-Date -Format "yyyy-MM-dd"

$entry = @()
$entry += ""
$entry += "## $date"
$entry += ""

if ($Tags -ne "") {
    $entry += "- Tags: $Tags"
}

$entry += "- Summary: $Summary"

if ($Impact -ne "") {
    $entry += "- Impact: $Impact"
}

Add-Content -LiteralPath $targetPath -Value $entry
