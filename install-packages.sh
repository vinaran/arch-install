#!/bin/bash

# installs packages I need for a basic Arch system, 
# after installing these packages you should download the config
# files from here: https://github.com/vinaran/.dotfiles 

# first find the name of the network device/interface
DEVICE=$(ip link | grep BROADCAST | awk -F: '{print $2}')
# enable network to be started on boot
systemctl enable dhcpcd@$DEVICE.service
# start network for this session
systemctl start dhcpcd@$DEVICE.service

# install display manager
pacman -S --noconfirm xorg-server sorg-server-utils xorg-xinit xorg-twm

# firefox
pacman -S --noconfirm firefox

# urxvt terminal
pacman -S --noconfirm rxvt-unicode

# background image manager
pacman -S --noconfirm feh

# monospaced terminal font - used in urxvt config
pacman -S --noconfirm ttf-roboto

# xmonad tiling window manager
pacman -S --noconfirm xmonad

# used to manage dot files
pacman -S --noconfirm stow

# git
pacman -S --noconfirm git
