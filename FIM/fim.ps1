# =====================================
# File Integrity Monitoring (FIM) Script
# =====================================

# Resolve script directory (fixes relative path issues)
$ScriptRoot   = Split-Path -Parent $MyInvocation.MyCommand.Path
$TargetFolder = Join-Path $ScriptRoot "Files"
$BaselineFile = Join-Path $ScriptRoot "baseline.txt"

# -------------------------------------
# Calculate SHA-512 File Hash
# -------------------------------------
Function Calculate-File-Hash ($FilePath) {
    return (Get-FileHash -Path $FilePath -Algorithm SHA512)
}

# -------------------------------------
# Remove old baseline if exists
# -------------------------------------
Function Erase-Baseline-If-Already-Exists {
    if (Test-Path $BaselineFile) {
        Remove-Item $BaselineFile
    }
}

# -------------------------------------
# Ensure target folder exists
# -------------------------------------
if (-Not (Test-Path $TargetFolder)) {
    Write-Host "Target folder not found. Creating it..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $TargetFolder | Out-Null
}

Write-Host ""
Write-Host "What would you like to do?"
Write-Host "A) Collect new Baseline"
Write-Host "B) Begin Monitoring with saved Baseline"
Write-Host ""

$response = (Read-Host "Enter A or B").ToUpper()

# =====================================
# OPTION A: Create Baseline
# =====================================
if ($response -eq "A") {

    Erase-Baseline-If-Already-Exists

    $files = Get-ChildItem -Path $TargetFolder -File

    foreach ($file in $files) {
        $hash = Calculate-File-Hash $file.FullName
        "$($hash.Path)|$($hash.Hash)" | Out-File -FilePath $BaselineFile -Append
    }

    Write-Host "Baseline created successfully!" -ForegroundColor Green
}

# =====================================
# OPTION B: Monitor Files
# =====================================
elseif ($response -eq "B") {

    if (-Not (Test-Path $BaselineFile)) {
        Write-Host "Baseline file not found. Create baseline first!" -ForegroundColor Red
        exit
    }

    $fileHashDictionary = @{}

    Get-Content $BaselineFile | ForEach-Object {
        $parts = $_ -split "\|"
        $fileHashDictionary[$parts[0]] = $parts[1]
    }

    Write-Host "Monitoring started..." -ForegroundColor Cyan
    Write-Host "Press CTRL + C to stop monitoring"
    Write-Host ""

    while ($true) {
        Start-Sleep -Seconds 1

        $currentFiles = Get-ChildItem -Path $TargetFolder -File

        foreach ($file in $currentFiles) {
            $hash = Calculate-File-Hash $file.FullName

            if (-Not $fileHashDictionary.ContainsKey($hash.Path)) {
                Write-Host "$($hash.Path) CREATED" -ForegroundColor Green
            }
            elseif ($fileHashDictionary[$hash.Path] -ne $hash.Hash) {
                Write-Host "$($hash.Path) MODIFIED" -ForegroundColor Yellow
            }
        }

        foreach ($baselineFilePath in $fileHashDictionary.Keys) {
            if (-Not (Test-Path $baselineFilePath)) {
                Write-Host "$baselineFilePath DELETED" -ForegroundColor Red
            }
        }
    }
}

else {
    Write-Host "Invalid selection. Please choose A or B." -ForegroundColor Red
}
