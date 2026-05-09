param(
    [Parameter(Mandatory = $true)]
    [string]$Query,

    [switch]$IncludeLegacyDocs,

    [int]$Context = 2
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$memoryRoot = Join-Path $repoRoot "docs\memory"

$targets = @($memoryRoot)

if ($IncludeLegacyDocs) {
    $targets += @(
        (Join-Path $repoRoot "docs\history\AUDIT_LOG.md"),
        (Join-Path $repoRoot "docs\history\FIX_LOG.md"),
        (Join-Path $repoRoot "docs\history\PROGRESS.md"),
        (Join-Path $repoRoot "docs\history\REMAINING_WORK.md"),
        (Join-Path $repoRoot "docs\history\CRITICAL_FIXES.md"),
        (Join-Path $repoRoot "docs\history\INDEX.md"),
        (Join-Path $repoRoot "docs\history\SUMMARY.md")
    )
}

$rg = Get-Command rg -ErrorAction SilentlyContinue

if ($rg) {
    & $rg.Source -n -i -C $Context --glob "*.md" -- $Query $targets
    exit $LASTEXITCODE
}

$files = @()
foreach ($target in $targets) {
    if (Test-Path $target -PathType Container) {
        $files += Get-ChildItem $target -Recurse -File -Filter *.md
    } elseif (Test-Path $target -PathType Leaf) {
        $files += Get-Item $target
    }
}

$files | Select-String -Pattern $Query -CaseSensitive:$false -Context $Context, $Context
