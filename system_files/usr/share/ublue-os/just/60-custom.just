# goldenblue recipes (imported by ujust)

# PyTorch ROCm wheel index used by ComfyUI and Unsloth (bundles its own ROCm)
torch_index := "https://download.pytorch.org/whl/rocm7.2"

# Install or update ComfyUI with PyTorch ROCm in ~/.local/share/comfyui
[group('goldenblue')]
install-comfyui:
    #!/usr/bin/bash
    set -euo pipefail
    DIR="${XDG_DATA_HOME:-$HOME/.local/share}/comfyui"
    mkdir -p "$DIR/data" "$HOME/.local/bin" "$HOME/.local/share/applications"
    if [[ -d "$DIR/app/.git" ]]; then
        git -C "$DIR/app" pull --ff-only
    else
        git clone --depth 1 https://github.com/Comfy-Org/ComfyUI "$DIR/app"
    fi
    uv venv --allow-existing --python 3.13 "$DIR/venv"
    export VIRTUAL_ENV="$DIR/venv"
    uv pip install --upgrade torch torchvision torchaudio --index-url "{{ torch_index }}"
    # Pin the ROCm torch build so later installs (requirements, custom nodes)
    # can't swap in the CUDA wheels from PyPI.
    uv pip freeze | grep -E '^(torch|torchvision|torchaudio)==' > "$DIR/torch-pins.txt"
    REQS=(-r "$DIR/app/requirements.txt")
    [[ -f "$DIR/app/manager_requirements.txt" ]] && REQS+=(-r "$DIR/app/manager_requirements.txt")
    uv pip install --upgrade "${REQS[@]}" --overrides "$DIR/torch-pins.txt"
    cat > "$HOME/.local/bin/comfyui" <<EOF
    #!/usr/bin/bash
    exec "$DIR/venv/bin/python" "$DIR/app/main.py" --base-directory "$DIR/data" --enable-manager "\$@"
    EOF
    chmod +x "$HOME/.local/bin/comfyui"
    cat > "$HOME/.local/share/applications/comfyui.desktop" <<EOF
    [Desktop Entry]
    Type=Application
    Name=ComfyUI
    Comment=Node-based image and video generation (http://127.0.0.1:8188)
    Exec=ghostty --title=ComfyUI -e $HOME/.local/bin/comfyui --auto-launch
    Icon=applications-graphics
    Categories=Graphics;
    EOF
    echo "ComfyUI installed. Run 'comfyui' (models go in $DIR/data/models)."

# Install or update Unsloth (fine-tuning) with PyTorch ROCm in ~/.local/share/unsloth
[group('goldenblue')]
install-unsloth:
    #!/usr/bin/bash
    set -euo pipefail
    DIR="${XDG_DATA_HOME:-$HOME/.local/share}/unsloth"
    mkdir -p "$DIR" "$HOME/.local/bin"
    uv venv --allow-existing --python 3.13 "$DIR/venv"
    export VIRTUAL_ENV="$DIR/venv"
    uv pip install --upgrade "torch<2.15" torchvision torchaudio --index-url "{{ torch_index }}"
    # Per Unsloth's AMD docs: keep ROCm torch, never pull CUDA triton/xformers.
    uv pip freeze | grep -E '^(torch|torchvision|torchaudio)==' > "$DIR/torch-pins.txt"
    echo "triton ; sys_platform == 'never'" >> "$DIR/torch-pins.txt"
    echo "xformers ; sys_platform == 'never'" >> "$DIR/torch-pins.txt"
    uv pip install --upgrade "unsloth[amd]" ipykernel --overrides "$DIR/torch-pins.txt"
    ln -sf "$DIR/venv/bin/unsloth" "$HOME/.local/bin/unsloth"
    echo "Unsloth installed. Activate with: source $DIR/venv/bin/activate"
    echo "Web UI: unsloth studio"

# Start llama-server as a user service (configure in ~/.config/llama-server.env)
[group('goldenblue')]
enable-llama-server:
    #!/usr/bin/bash
    set -euo pipefail
    ENV="$HOME/.config/llama-server.env"
    if [[ ! -f "$ENV" ]]; then
        mkdir -p "$HOME/.config"
        echo 'LLAMA_ARGS=--host 127.0.0.1 --port 8080 -hf ggml-org/gemma-3-4b-it-GGUF' > "$ENV"
        echo "Created $ENV - edit it to pick your model."
    fi
    systemctl --user daemon-reload
    systemctl --user enable --now llama-server.service
    echo "llama-server running on http://127.0.0.1:8080 (logs: journalctl --user -u llama-server -f)"

# Stop and disable the llama-server user service
[group('goldenblue')]
disable-llama-server:
    systemctl --user disable --now llama-server.service

# Make zsh (with Oh My Zsh) your login shell; new users get it by default
[group('goldenblue')]
zsh-default:
    #!/usr/bin/bash
    set -euo pipefail
    [[ -f "$HOME/.zshrc" ]] || cp /etc/skel/.zshrc "$HOME/.zshrc"
    sudo usermod --shell /usr/bin/zsh "$USER"
    echo "Login shell set to zsh. Log out and back in to use it."
