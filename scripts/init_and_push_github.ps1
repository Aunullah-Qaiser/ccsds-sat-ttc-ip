param(
    [Parameter(Mandatory=$false)]
    [string]$RemoteUrl = "",
    [Parameter(Mandatory=$false)]
    [string]$RepoName = "ccsds-sat-ttc-ip",
    [Parameter(Mandatory=$false)]
    [switch]$Private
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path ".git")) {
    Write-Host "[GIT] Initializing Git repository on branch 'main'..." -ForegroundColor Cyan
    git init -b main
}

git add .
$status = git status --porcelain
if ($status) {
    git commit -m "feat(ccsds-ttc-ip): Stage 8 v2.14 4-Pillar CCSDS Flight & EGSE RTL IP Core"
}

if ($RemoteUrl -ne "") {
    $existing = git remote
    if ($existing -contains "origin") {
        git remote set-url origin $RemoteUrl
    } else {
        git remote add origin $RemoteUrl
    }
    Write-Host "[GIT] Pushing branch 'main' to $RemoteUrl ..." -ForegroundColor Green
    git branch -M main
    git push -u origin main
} elseif (Get-Command gh -ErrorAction SilentlyContinue) {
    $vis = if ($Private) { "--private" } else { "--public" }
    Write-Host "[GH-CLI] Creating GitHub repository '$RepoName' ($vis) and pushing..." -ForegroundColor Green
    gh repo create $RepoName $vis --source=. --remote=origin --push
} else {
    Write-Host "[INFO] Local Git repository is committed and ready on branch 'main'!" -ForegroundColor Yellow
    Write-Host "To push to GitHub, create an empty repo on https://github.com/new and run:"
    Write-Host "  .\scripts\init_and_push_github.ps1 -RemoteUrl https://github.com/<your-username>/ccsds-sat-ttc-ip.git"
}
