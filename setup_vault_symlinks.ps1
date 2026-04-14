# Define Paths
$UserPath = "C:\Users\eitan"
$VaultPath = "C:\Users\eitan\OneDrive\Vault"
$Folders = @("Desktop", "Documents", "Music", "Pictures", "Videos")

# Ensure Vault exists
if (!(Test-Path $VaultPath)) {
    New-Item -Path $VaultPath -ItemType Directory | Out-Null
}

foreach ($f in $Folders) {
    $Source = Join-Path $UserPath $f
    $Dest = Join-Path $VaultPath $f

    # 1. Create destination folder if missing
    if (!(Test-Path $Dest)) {
        New-Item -Path $Dest -ItemType Directory | Out-Null
        Write-Host "Created destination: $Dest" -ForegroundColor Cyan
    }

    # 2. Check if Source is already a link or exists
    $Item = Get-Item -Path $Source -ErrorAction SilentlyContinue
    if ($Item -and $Item.Attributes -match "ReparsePoint") {
        Write-Host "Skipping ${f}: Already a Junction/Symlink." -ForegroundColor Yellow
        continue
    }

    if (Test-Path $Source) {
        Write-Host "Processing $f..." -ForegroundColor White
        
        # Move files safely (Force handles hidden files)
        Get-ChildItem -Path $Source -Recurse | Move-Item -Destination $Dest -Force -ErrorAction SilentlyContinue
        
        # Remove the now-empty original folder
        Remove-Item -Path $Source -Recurse -Force
        
        # Create the Junction
        New-Item -Path $Source -ItemType Junction -Value $Dest | Out-Null
        Write-Host "Successfully linked $f to Vault." -ForegroundColor Green
    }
}

Write-Host "`nAll operations complete!" -ForegroundColor Magenta
Pause