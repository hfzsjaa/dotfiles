# dotfiles

My Arch Linux / Hyprland configuration.

Currently using:

Screenshots:
<img width="1366" height="768" alt="image" src="https://github.com/user-attachments/assets/06aa78ca-090b-49d7-a4bc-12f49a255966" />
<img width="1366" height="768" alt="image" src="https://github.com/user-attachments/assets/01a4d1a6-8621-4d32-8d80-1119605b5253" />
<img width="1366" height="768" alt="image" src="https://github.com/user-attachments/assets/4a5f6f7a-574a-4677-ae53-ad18bcfa51c9" />
<img width="1366" height="768" alt="image" src="https://github.com/user-attachments/assets/65bc4a70-905c-41f3-b196-34a927c8b439" />
<img width="1366" height="768" alt="image" src="https://github.com/user-attachments/assets/249a252c-84df-4bab-869d-7625297a87b1" />
<img width="1366" height="768" alt="image" src="https://github.com/user-attachments/assets/371d31db-f5dd-4e9c-b787-afcabe03cf63" />
<img width="1366" height="768" alt="image" src="https://github.com/user-attachments/assets/c2081d9e-59c5-406d-83cd-21579f8ced61" />

* Hyprland
* QuickShell
* Kitty
* Yazi
* Neovim
* VSCodium
* Cava
* Pywal
* Brave

## Structure

```text
config/
├── cava/
├── fastfetch/
├── hypr/
├── kitty/
├── nvim/
├── quickshell/
├── wal/
└── starship.toml

wallpapers/
install.sh
```

## Install

```bash
git clone git@github.com:hfzsjaa/dotfiles.git
cd dotfiles
chmod +x install.sh
./install.sh
```

The configs are mainly made for my own machine, so some paths, packages and settings may need to be changed.

## Keybinds

`SUPER` is the main modifier.

### Apps

```text
SUPER + Q              Kitty
SUPER + E              Yazi
SUPER + B              Browser
SUPER + T              VSCodium
SUPER + R              Reload Hyprland
SUPER + M              Exit Hyprland
Print                   Screenshot
SUPER + Print           Recording
SUPER + SHIFT + P       Color picker
```

### QuickShell

```text
SUPER + TAB             Launcher
ALT + TAB               Overview
SUPER + SHIFT + TAB     Dashboard
SUPER + SHIFT + C       Clipboard
SUPER + G               Wallpaper picker
SUPER + SHIFT + G       Toggle bar
SUPER + SHIFT + Q       Power menu
SUPER + L               Lock
```

### Windows

```text
SUPER + Arrow           Focus
SUPER + CTRL + Arrow    Resize
SUPER + ALT + Arrow     Move

SUPER + C               Close
SUPER + V               Toggle floating
SUPER + P               Toggle pseudo
SUPER + J               Toggle split

SUPER + F               Fullscreen / fit
SUPER + SHIFT + W       Swap up
SUPER + SHIFT + S       Swap down
SUPER + SHIFT + A       Swap left
SUPER + SHIFT + D       Swap right
```

### Layout

```text
SUPER + SPACE           Dwindle / Scrolling
SUPER + W               Increase size
SUPER + S               Decrease size
SUPER + A               Move left
SUPER + D               Move right
SUPER + SHIFT + F       Promote / move to root
```

### Workspaces

```text
SUPER + 1-9             Switch workspace
SUPER + 0               Workspace 10

SUPER + SHIFT + 1-9     Move window
SUPER + SHIFT + 0       Move window to workspace 10
```

### Media

```text
F9                      Volume +5%
F8                      Volume -5%

XF86AudioMute           Mute
XF86AudioMicMute        Mic mute

XF86AudioNext           Next
XF86AudioPrev           Previous
XF86AudioPlay           Play / pause
XF86AudioPause          Play / pause

XF86MonBrightnessUp    Brightness +5%
XF86MonBrightnessDown  Brightness -5%
```

## Wallpaper / Pywal

Wallpaper colors are generated with Pywal and used by parts of the setup.

```bash
wal -i ~/wallpapers/<image>
```

## Notes

This is a personal configuration rather than a universal setup.

Things will probably break if you copy it blindly to another machine. Check `install.sh` and the configs first.
