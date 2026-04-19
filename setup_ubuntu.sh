#!/bin/bash

# --- 0. Self-Fix Line Endings ---
sed -i 's/\r$//' "$0" 2>/dev/null

DOT_DIR="$HOME/dotfiles"

echo "--- Ubuntu Setup: Performance Dev Env ---"

# 1. Update and install Core Tools + GitHub CLI
sudo apt update
sudo apt install -y git neovim tmux curl unzip wget build-essential gh

# 2. GitHub Authentication
if ! gh auth status &>/dev/null; then
    echo "--- GitHub Login Required ---"
    echo "1. Copy the code that appears below."
    echo "2. Open https://github.com/login/device in your Windows browser."
    gh auth login -h github.com -p https -w
fi

# 3. Node.js Installation (Linux Check)
if [ ! -f "/usr/bin/node" ]; then
    echo "Installing Node.js 20 (Linux Version)..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt install -y nodejs
else
    echo "✅ Linux Node.js is already installed."
fi

# Force Linux paths to take priority over Windows paths for this session
export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"
hash -r

# 4. Install Claude Code (Only if missing in Linux)
# We check the physical directory to avoid path conflicts and corruption
if [ ! -d "/usr/lib/node_modules/@anthropic-ai/claude-code" ]; then
    echo "Installing Claude Code..."
    # Clean up any potential broken remnants that cause 'ENOTEMPTY'
    sudo rm -rf /usr/lib/node_modules/@anthropic-ai/claude-code 2>/dev/null
    sudo /usr/bin/npm install -g @anthropic-ai/claude-code
else
    echo "✅ Claude Code is already installed in Linux. Skipping..."
fi

# 5. Clone or Update Dotfiles
if [ ! -d "$DOT_DIR" ]; then
    echo "Cloning dotfiles..."
    gh repo clone eitan318/dotfiles "$DOT_DIR"
else
    echo "Updating existing dotfiles..."
    cd "$DOT_DIR" && git pull && cd - > /dev/null
fi

# 6. Symlink Logic
mkdir -p ~/.config
echo "Applying symlinks..."

# Link Neovim
if [ -d "$DOT_DIR/common/.config/nvim" ]; then
    ln -sfn "$DOT_DIR/common/.config/nvim" ~/.config/nvim
    echo "✅ Neovim linked."
fi

# Link Tmux
if [ -d "$DOT_DIR/nix/.config/tmux" ]; then
    ln -sfn "$DOT_DIR/nix/.config/tmux" ~/.config/tmux
    [ -f "$DOT_DIR/nix/.config/tmux/.tmux.conf" ] && ln -sf "$DOT_DIR/nix/.config/tmux/.tmux.conf" ~/.tmux.conf
    echo "✅ Tmux linked."
fi

# Link additional tools
for app in alacritty i3 polybar rofi picom; do
    if [ -d "$DOT_DIR/common/.config/$app" ]; then
        ln -sfn "$DOT_DIR/common/.config/$app" ~/.config/$app
        echo "✅ $app linked (from common)."
    elif [ -d "$DOT_DIR/nix/.config/$app" ]; then
        ln -sfn "$DOT_DIR/nix/.config/$app" ~/.config/$app
        echo "✅ $app linked (from nix)."
    fi
done

# Link Bashrc
if [ -f "$DOT_DIR/nix/.bashrc" ]; then
    ln -sf "$DOT_DIR/nix/.bashrc" ~/.bashrc
    echo "✅ Bashrc linked (from nix)."
elif [ -f "$DOT_DIR/.bashrc" ]; then
    ln -sf "$DOT_DIR/.bashrc" ~/.bashrc
    echo "✅ Bashrc linked (from root)."
fi

# Finalizing
source ~/.bashrc
echo "--- Setup Complete! ---"
