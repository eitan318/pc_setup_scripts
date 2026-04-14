# --- CONFIGURATION ---
$DOTFILES_URL = "https://github.com/eitan318/dotfiles.git"
$DOTFILES_DIR = "$HOME\dotfiles"
$CONFIG_DIR   = "$HOME\.config"
$REBOOT_FLAG  = "$HOME\.setup_reboot_done"
$STARTUP_FOLDER = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"

Write-Host "`n=== WINDOWS UNIFIED SETUP (i3-Style & Performance) ===" -ForegroundColor Cyan

function Install-App {
    param([string]$id, [string]$executableName)
    # Check winget list first
    $installed = winget list --id $id -e --accept-source-agreements 2>$null
    
    if (!$installed) {
        Write-Host "[INSTALLING] $id..." -ForegroundColor Green
        winget install --id $id --silent --force --accept-package-agreements --accept-source-agreements | Out-Null
        
        # Force refresh PATH in current session after install
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        return $true
    }
    
    Write-Host "[EXISTS] $id skipping." -ForegroundColor Gray
    return $false
}

function Create-Link {
    param([string]$source, [string]$target)
    if (Test-Path $source) {
        if (Test-Path $target) {
            Remove-Item -Recurse -Force $target
        }
        New-Item -ItemType SymbolicLink -Path $target -Value $source | Out-Null
        Write-Host "[LINKED] $target -> $source" -ForegroundColor Green
    }
}

# --- PHASE 1: SYSTEM CORE ---
if (!(Test-Path $REBOOT_FLAG)) {
    Write-Host "`n[STEP 1/2] Installing System Components" -ForegroundColor Yellow
    
    Install-App "Git.Git" "git"
    Install-App "vim.vim" "vim"  # Installs Vim 9.x
    Install-App "Microsoft.WSL" "wsl"
    Install-App "OpenJS.NodeJS" "node"
    Install-App "Microsoft.DotNet.SDK.9" "dotnet"
    Install-App "AutoHotkey.AutoHotkey" "AutoHotkeyUX.exe"

    New-Item -Path $REBOOT_FLAG -ItemType File -Force | Out-Null

    Write-Host "`nCORE COMPONENTS INSTALLED." -ForegroundColor Cyan
    Write-Host "------------------------------------------------------------"
    Write-Host "ACTION REQUIRED: Please restart your computer now." -ForegroundColor Red
    Write-Host "------------------------------------------------------------"
    exit
}

# --- PHASE 2: APPS & SYMLINKS ---
Write-Host "`n[STEP 2/2] Configuring Environment" -ForegroundColor Yellow

# Final PATH refresh
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

Install-App "Mozilla.Firefox" "firefox"
Install-App "Microsoft.VisualStudioCode" "code"
Install-App "LGUG2Z.Komorebi" "komorebi"

if (!(Test-Path $CONFIG_DIR)) { New-Item -ItemType Directory -Path $CONFIG_DIR }

# --- DOTFILES SYNC ---
Write-Host "[DOTFILES] Syncing configurations..." -ForegroundColor Cyan
if (!(Test-Path $DOTFILES_DIR)) {
    git clone $DOTFILES_URL $DOTFILES_DIR --quiet
} else {
    Set-Location $DOTFILES_DIR
    git pull --quiet
    Set-Location $HOME
}

# --- SYMLINK DEPLOYMENT ---

# 1. Common Configs (Neovim, Alacritty, etc.)
$commonPath = "$DOTFILES_DIR\common\.config"
if (Test-Path $commonPath) {
    Get-ChildItem -Path $commonPath | ForEach-Object {
        Create-Link -source $_.FullName -target "$CONFIG_DIR\$($_.Name)"
    }
}

# 2. Vim Configuration
$repoVimrc = "$DOTFILES_DIR\common\.vimrc"
if (Test-Path $repoVimrc) {
    Create-Link -source $repoVimrc -target "$HOME\.vimrc"
}

# 3. Komorebi
Create-Link -source "$DOTFILES_DIR\win\komorebi\komorebi.json" -target "$CONFIG_DIR\komorebi.json"

# 4. Kanata Windows
$kanataWinDir = "$HOME\kanata"
if (!(Test-Path $kanataWinDir)) { New-Item -ItemType Directory -Path $kanataWinDir }
if (Test-Path "$DOTFILES_DIR\win\kanata") {
    Get-ChildItem -Path "$DOTFILES_DIR\win\kanata" | ForEach-Object {
        Create-Link -source $_.FullName -target "$kanataWinDir\$($_.Name)"
    }
}

# 5. WSL Config
Create-Link -source "$DOTFILES_DIR\nix\wsl\.wslconfig" -target "$HOME\.wslconfig"

# --- STARTUP AUTOMATION ---
Write-Host "[STARTUP] Registering Komorebi & i3.ahk..." -ForegroundColor Cyan

if (Get-Command "komorebic" -ErrorAction SilentlyContinue) {
    komorebic enable-autostart --config "$CONFIG_DIR\komorebi.json"
}

$ahkSource = "$DOTFILES_DIR\win\komorebi\i3.ahk"
if (Test-Path $ahkSource) {
    Create-Link -source $ahkSource -target "$STARTUP_FOLDER\i3.ahk"
}

# --- POST-LINK ACTIONS ---

# VS Code Extensions
if (Get-Command "code" -ErrorAction SilentlyContinue) {
    $extensions = @("ms-dotnettools.csdevkit", "vscodevim.vim", "anthropic.claude-dev", "ms-vscode-remote.remote-wsl")
    foreach ($ext in $extensions) {
        Start-Process "code" -ArgumentList "--install-extension $ext --force" -Wait -NoNewWindow
    }
}

# Claude Code
if (Get-Command "npm" -ErrorAction SilentlyContinue) {
    npm install -g @anthropic-ai/claude-code
}

# Finalize WSL
if (!(wsl --list --quiet | Select-String "Ubuntu")) {
    wsl --install -d Ubuntu --no-launch
}
wsl --shutdown

Remove-Item $REBOOT_FLAG -Force
Write-Host "`n=== SETUP COMPLETE ===" -ForegroundColor Cyan