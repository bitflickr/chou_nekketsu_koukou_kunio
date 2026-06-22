# GitHub Issues batch setup script
# Usage: .\setup-github-issues.ps1
# Token is read from scripts\.github-token
# Data is read from scripts\github-issues-data.json and scripts\github-issues-list.json

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TokenFile = Join-Path $ScriptDir ".github-token"
$DataFile = Join-Path $ScriptDir "github-issues-data.json"
$IssuesFile = Join-Path $ScriptDir "github-issues-list.json"

if (-not (Test-Path $TokenFile)) {
    Write-Host "[ERROR] Token file not found: $TokenFile" -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $DataFile)) {
    Write-Host "[ERROR] Data file not found: $DataFile" -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $IssuesFile)) {
    Write-Host "[ERROR] Issues file not found: $IssuesFile" -ForegroundColor Red
    exit 1
}

$Token = (Get-Content $TokenFile -Raw).Trim()
$Data = Get-Content $DataFile -Raw -Encoding UTF8 | ConvertFrom-Json
$IssuesList = Get-Content $IssuesFile -Raw -Encoding UTF8 | ConvertFrom-Json

$Owner = "bitflickr"
$Repo = "chou_nekketsu_koukou_kunio"
$BaseUrl = "https://api.github.com/repos/$Owner/$Repo"
$Headers = @{
    "Authorization" = "Bearer $Token"
    "Accept" = "application/vnd.github+json"
    "X-GitHub-Api-Version" = "2022-11-28"
}

# === 1. Create Labels ===
Write-Host "=== 1. Creating Labels ===" -ForegroundColor Cyan

foreach ($label in $Data.labels) {
    $body = @{ name = $label.name; color = $label.color; description = $label.description } | ConvertTo-Json
    try {
        $null = Invoke-RestMethod -Uri "$BaseUrl/labels" -Method Post -Headers $Headers -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -ContentType "application/json; charset=utf-8"
        Write-Host "  [OK] $($label.name)" -ForegroundColor Green
    } catch {
        $status = $null
        if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
        if ($status -eq 422) {
            Write-Host "  [SKIP] $($label.name) (already exists)" -ForegroundColor Yellow
        } else {
            Write-Host "  [FAIL] $($label.name): $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# === 2. Create Milestones ===
Write-Host "`n=== 2. Creating Milestones ===" -ForegroundColor Cyan

foreach ($ms in $Data.milestones) {
    $body = @{ title = $ms.title; description = $ms.description } | ConvertTo-Json
    try {
        $resp = Invoke-RestMethod -Uri "$BaseUrl/milestones" -Method Post -Headers $Headers -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -ContentType "application/json; charset=utf-8"
        Write-Host "  [OK] $($ms.title) -> #$($resp.number)" -ForegroundColor Green
    } catch {
        $status = $null
        if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
        if ($status -eq 422) {
            Write-Host "  [SKIP] $($ms.title) (already exists)" -ForegroundColor Yellow
        } else {
            Write-Host "  [FAIL] $($ms.title): $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# Fetch all milestone numbers for issue assignment
$MilestoneMap = @{}
try {
    $existingMs = Invoke-RestMethod -Uri "$BaseUrl/milestones?state=open&per_page=100" -Method Get -Headers $Headers
    foreach ($m in $existingMs) {
        $MilestoneMap[$m.title] = $m.number
    }
} catch {
    Write-Host "  [WARN] Could not fetch milestones" -ForegroundColor Yellow
}

# === 3. Create Issues ===
Write-Host "`n=== 3. Creating Issues ===" -ForegroundColor Cyan

foreach ($issue in $IssuesList) {
    $issueBody = @{
        title  = $issue.title
        body   = $issue.body
        labels = @($issue.labels)
    }

    if ($issue.milestone -and $issue.milestone -ne "" -and $MilestoneMap.ContainsKey($issue.milestone)) {
        $issueBody["milestone"] = $MilestoneMap[$issue.milestone]
    }

    $json = $issueBody | ConvertTo-Json -Depth 3
    try {
        $resp = Invoke-RestMethod -Uri "$BaseUrl/issues" -Method Post -Headers $Headers -Body ([System.Text.Encoding]::UTF8.GetBytes($json)) -ContentType "application/json; charset=utf-8"
        Write-Host "  [OK] #$($resp.number) $($issue.title)" -ForegroundColor Green
    } catch {
        Write-Host "  [FAIL] $($issue.title): $($_.Exception.Message)" -ForegroundColor Red
    }

    Start-Sleep -Milliseconds 500
}

Write-Host "`n=== Done! ===" -ForegroundColor Cyan
Write-Host "Issues: https://github.com/$Owner/$Repo/issues"
Write-Host "Milestones: https://github.com/$Owner/$Repo/milestones"
