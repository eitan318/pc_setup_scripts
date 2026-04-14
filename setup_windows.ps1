# --- CONFIGURATION ---
$DOTFILES_URL = "https://github.com/eitan318/dotfiles.git"
$TEMP_DOTS = "$HOME\temp_dots"
$REBOOT_FLAG = "$HOME\.setup_reboot_done"

Write-Host "`n=== WINDOWS UNIFIED SETUP (Performance & WPF) ===" -ForegroundColor Cyan

function Install-App {
    param([string]$id, [string]$executableName)
    $inPath = Get-Command $executableName -ErrorAction SilentlyContinue
    if (!$inPath) {
        Write-Host "[INSTALLING] $id..." -ForegroundColor Green
        winget install --id $id --silent --force --accept-package-agreements --accept-source-agreements | Out-Null
        return $true
    }
    Write-Host "[EXISTS] $id skipping." -ForegroundColor Gray
    return $false
}

# --- PHASE 1: SYSTEM CORE ---
if (!(Test-Path $REBOOT_FLAG)) {
    Write-Host "`n[STEP 1/2] Installing System Components" -ForegroundColor Yellow
    
    Install-App "Git.Git" "git"
    Install-App "Microsoft.WSL" "wsl"
    Install-App "OpenJS.NodeJS" "node"
    Install-App "Microsoft.DotNet.SDK.9" "dotnet"

    New-Item -Path $REBOOT_FLAG -ItemType File -Force | Out-Null

    Write-Host "`nCORE COMPONENTS INSTALLED." -ForegroundColor Cyan
    Write-Host "------------------------------------------------------------"
    Write-Host "ACTION REQUIRED: Please restart your computer now." -ForegroundColor Red
    Write-Host "Run this script again immediately after logging back in."
    Write-Host "------------------------------------------------------------"
    exit
}

# --- PHASE 2: APPS & CONFIGS ---
Write-Host "`n[STEP 2/2] Configuring Environment" -ForegroundColor Yellow

# Refresh Path
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

Install-App "Mozilla.Firefox" "firefox"
Install-App "Microsoft.VisualStudioCode" "code"

# Ensure 'code' is available for extension install
if (!(Get-Command "code" -ErrorAction SilentlyContinue)) {
    $vscodePath = "$env:LocalAppData\Programs\Microsoft VS Code\bin"
    if (Test-Path $vscodePath) { $env:Path += ";$vscodePath" }
}

# --- INSTALL VS CODE EXTENSIONS ---
if (Get-Command "code" -ErrorAction SilentlyContinue) {
    Write-Host "[CONFIG] Installing VS Code Extensions..." -ForegroundColor Cyan
    $extensions = @(
        "ms-dotnettools.csdevkit",
        "groosoft.visualstudiocodexamlstyler",
        "shevchenko-nikita.xaml-previewer",
        "ms-vscode-remote.remote-wsl",  
        "vscodevim.vim",
        "anthropic.claude-dev"
    )
    foreach ($ext in $extensions) {
        Write-Host "  -> $ext" -ForegroundColor Gray
        Start-Process "code" -ArgumentList "--install-extension $ext --force" -Wait -NoNewWindow
    }
}

# --- INSTALL CLAUDE CODE CLI (NPM) ---
if (Get-Command "npm" -ErrorAction SilentlyContinue) {
    Write-Host "[INSTALLING] Claude Code CLI..." -ForegroundColor Green
    npm install -g @anthropic-ai/claude-code
}

# --- WSL SETUP ---
if (!(wsl --list --quiet | Select-String "Ubuntu")) {
    Write-Host "[WSL] Installing Ubuntu..." -ForegroundColor Green
    wsl --install -d Ubuntu --no-launch
}

# --- DOTFILES SYNC ---
Write-Host "[DOTFILES] Syncing configurations..." -ForegroundColor Cyan
if (Test-Path $TEMP_DOTS) { Remove-Item -Recurse -Force $TEMP_DOTS }
git clone $DOTFILES_URL $TEMP_DOTS --quiet

# --- CONFIG DEPLOYMENT (Based on your Tree structure) ---


# Kanata Windows
if (Test-Path "$TEMP_DOTS\win\kanata") {
    $kanataDir = "$HOME\kanata"
    if (!(Test-Path $kanataDir)) { New-Item -ItemType Directory -Path $kanataDir }
    Copy-Item -Path "$TEMP_DOTS\win\kanata\*" -Destination $kanataDir -Force
    Write-Host "[OK] Kanata Windows configs deployed." -ForegroundColor Green
}

# WSL Performance (.wslconfig)
$repoWslConfig = "$TEMP_DOTS\nix\wsl\.wslconfig"
if (Test-Path $repoWslConfig) {
    Copy-Item -Path $repoWslConfig -Destination "$HOME\.wslconfig" -Force
    Write-Host "[OK] WSL performance config deployed." -ForegroundColor Green
    wsl --shutdown
}

Remove-Item $REBOOT_FLAG -Force
Write-Host "`n=== SETUP COMPLETE ===" -ForegroundColor Cyan