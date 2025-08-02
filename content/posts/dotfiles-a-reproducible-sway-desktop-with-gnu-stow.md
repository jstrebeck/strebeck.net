---
title: "Dotfiles: A Reproducible Sway Desktop With GNU Stow"
date: "2025-08-01T17:51:55-07:00"
author: "Josh Strebeck"
tags: ["linux", "dotfiles", "sway", "wayland", "zsh", "aws", "shell"]
summary: "How I manage a Sway on Wayland desktop, shell, and a set of AWS helper scripts as a single repo that can rebuild a workstation from scratch."
draft: false
---

Source code: [jstrebeck/Dotfiles](https://github.com/jstrebeck/Dotfiles)

I started this repo in 2019 as a plain dump of config files. In late 2024 I moved my desktop to Sway, a tiling window manager for Wayland that uses the i3 configuration format, and rebuilt the repo around it. The goal is that a fresh Debian based install plus one script gets me back to a working environment.

## Layout With Stow

The repo uses GNU Stow. Each top level directory mirrors the layout of my home directory, so `sway/.config/i3/config` is the Sway config and `rc/.zshrc` is the shell config. Running `stow sway` creates the symlinks in the right place, and `stow -D sway` removes them. This keeps every config in git without copying files around or writing a custom install script.

The packages managed this way are:

- **Sway** for window management, with **swaylock** for the lock screen
- **Waybar** for the status bar
- **Rofi** as the launcher, with Catppuccin Mocha and One Dark themes
- **Alacritty** as the terminal, with matching color themes
- **Mako** for notifications
- **zsh** with oh-my-zsh and a custom prompt theme
- **Neovim**, which is large enough that it lives in its own repo and is cloned by the setup script

## Bootstrapping a Machine

The `deps.sh` script installs everything the configs depend on. It adds the Neovim and Alacritty PPAs, installs the desktop stack and tools like ripgrep, btop, and terraform-ls through apt, and pulls lazygit, lazydocker, and fzf from Homebrew. It then sets up oh-my-zsh, installs Terraform from the HashiCorp repo, installs kubectl and Docker with the post install group changes, downloads a JetBrains Mono Nerd Font, clones the Neovim config, and fixes the xdg-desktop-portal setup so GTK apps behave under Sway.

## Helper Scripts

The `scripts/bin` directory is the part I use every day at work. Most of them combine the AWS CLI, `jq`, and `fzf` into interactive pickers.

- `aws-ssh` and `aws-ssm` search EC2 instances by Name tag, present a fuzzy list, and open an SSH or Session Manager session to the selection
- `aws-rdp` and `aws-rdp-portfroward` do the same for Windows hosts, including tunneling RDP through SSM
- `aws-sec`, `aws-reboot`, and `deleteami` cover common security group, reboot, and AMI cleanup tasks
- `fsb` fuzzy searches local and remote git branches and checks out the match
- `jwt-decode` and `vimdiff-strings` are small utilities for inspecting tokens and comparing strings

There is also `share_fix.sh`, which restarts PipeWire and the wlr portal so screen sharing works in browser calls. Anyone running Wayland will recognize why that script exists.

## Why Keep This Public

None of this is clever on its own. The value is that a new laptop takes about half an hour to become familiar, and every change to how I work is a commit I can look back on.
