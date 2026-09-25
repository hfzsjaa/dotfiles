#!/usr/bin/env bash
set -uo pipefail

DOTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

PACKAGES=(
    hyprland
    hypridle
    hyprpicker
    hyprshot
    uwsm
    xdg-desktop-portal-hyprland
    xdg-utils
    polkit-kde-agent
    qt5-wayland
    qt6-wayland
    quickshell
    awww
    python-pywal16
    cliphist
    grim
    slurp
    wf-recorder
    cava
    fastfetch
    neovim
    kitty
    starship
    thunar
    nwg-look
    pavucontrol
    blueman
    network-manager-applet
    networkmanager
    pipewire
    pipewire-alsa
    pipewire-jack
    pipewire-pulse
    wireplumber
    gst-plugin-pipewire
    libpulse
    playerctl
    ttf-iosevka-nerd
    ttf-jetbrains-mono-nerd
    noto-fonts
    noto-fonts-emoji
)

OPTIONAL=(
    ly
    mpv
    yt-dlp
    feh
    htop
    vscodium-bin
    brave-origin-nightly-bin
    spotatui-bin
    lavat
    lyse
    peaclock
    pipes.sh
    unimatrix-git
    fetch-git
    pfetch-rs
    cowsay
)

FAILED=()

log()  { printf '\033[1;34m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }

check_system() {
    [[ -f /etc/arch-release ]] || die "this script only supports Arch Linux"
    [[ $EUID -ne 0 ]] || die "don't run this as root"
    command -v sudo >/dev/null || die "sudo is required"
}

ensure_yay() {
    if command -v yay >/dev/null; then
        log "yay found"
        return
    fi

    log "yay not found, building yay-bin"
    sudo pacman -S --needed --noconfirm base-devel git || die "failed to install base-devel/git"

    local tmp
    tmp="$(mktemp -d)"
    git clone https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin" || die "failed to clone yay-bin"
    (cd "$tmp/yay-bin" && makepkg -si --noconfirm) || die "failed to build yay"
    rm -rf "$tmp"
}

install_list() {
    for pkg in "$@"; do
        if pacman -Qi "$pkg" >/dev/null 2>&1; then
            continue
        fi
        log "installing $pkg"
        yay -S --needed --noconfirm "$pkg" || FAILED+=("$pkg")
    done
}

install_packages() {
    log "syncing package databases"
    sudo pacman -Sy

    install_list "${PACKAGES[@]}"

    read -rp "install optional apps too? [y/N] " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
        install_list "${OPTIONAL[@]}"
    fi
}

backup() {
    local target="$1"
    if [[ -e "$target" || -L "$target" ]]; then
        mkdir -p "$BACKUP_DIR"
        mv "$target" "$BACKUP_DIR/"
        warn "backed up $target"
    fi
}

link() {
    local src="$1" dst="$2"
    if [[ -L "$dst" && "$(readlink -f "$dst")" == "$(readlink -f "$src")" ]]; then
        return
    fi
    backup "$dst"
    mkdir -p "$(dirname "$dst")"
    ln -s "$src" "$dst"
    log "linked $dst"
}

link_configs() {
    for dir in "$DOTS"/config/*/; do
        link "${dir%/}" "$CONFIG_DIR/$(basename "$dir")"
    done

    if [[ -d "$DOTS/local/bin" ]]; then
        mkdir -p "$HOME/.local/bin"
        for f in "$DOTS"/local/bin/*; do
            chmod +x "$f"
            link "$f" "$HOME/.local/bin/$(basename "$f")"
        done
    fi
}

install_fonts() {
    [[ -d "$DOTS/fonts" ]] || return
    mkdir -p "$HOME/.local/share/fonts"
    cp -r "$DOTS"/fonts/. "$HOME/.local/share/fonts/"
    fc-cache -f >/dev/null
    log "fonts installed"
}

setup_wallpapers() {
    mkdir -p "$HOME/wallpapers"
    if [[ -d "$DOTS/wallpapers" ]]; then
        cp -n "$DOTS"/wallpapers/* "$HOME/wallpapers/" 2>/dev/null || true
    fi

    local first
    first="$(find "$HOME/wallpapers" -maxdepth 1 -type f | head -n 1)"
    if [[ -n "$first" ]] && command -v wal >/dev/null; then
        wal -n -i "$first" >/dev/null 2>&1 && log "generated pywal colors"
    else
        warn "no wallpapers in ~/wallpapers, run 'wal -i <image>' yourself before starting Hyprland"
    fi
}

main() {
    check_system
    ensure_yay
    install_packages
    link_configs
    install_fonts
    setup_wallpapers

    if ((${#FAILED[@]})); then
        warn "these packages failed to install: ${FAILED[*]}"
    fi
    log "done. log out and pick Hyprland from your display manager, or run 'Hyprland' from a tty"
}

main "$@"
