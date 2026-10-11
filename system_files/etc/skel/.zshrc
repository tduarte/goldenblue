# goldenblue default zsh config (Oh My Zsh is installed read-only in the image)
export ZSH=/usr/share/oh-my-zsh
ZSH_CUSTOM="$HOME/.oh-my-zsh-custom"
ZSH_THEME="robbyrussell"
plugins=(git sudo z)

# The image updates Oh My Zsh.
zstyle ':omz:update' mode disabled

source "$ZSH/oh-my-zsh.sh"

source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# User-local tools (ujust install-comfyui / install-unsloth put launchers here)
path=("$HOME/.local/bin" $path)
