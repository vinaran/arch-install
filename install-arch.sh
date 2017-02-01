#!/bin/bash

# parse arguments
while [[ $# -gt 0 ]]
do
    key=$1
    case $key in
	-c)
	    confirm_command=true
	    shift
	    ;;
	*)
	    print_usage
	    ;;
    esac
done

choice () {
     read -n1 -resp $"${1} [Y/N]" answer
     
     if [[ $answer = [Nn] ]]; then
	 return 0
     elif [[ $answer = [Yy] ]]; then
	 return 1
     else
	 choice
     fi
}

# takes 2 args
# 1 - the command to execute
# 2 - optional - additional info to print
execute_command () {
    if [[ $confirm_command = true ]]; then
	 if choice "Execute Command?" = 0; then
	     return
	 fi
     fi

    if [ ! -z "$2" ]
    then
	echo -e "$2\n"
    fi
    
    echo $1
    
    eval $1 # run the command

    if [ $? -ne 0 ]; then
        echo -e "\n***command failed"
	if choice "Continue?" = 0; then
           exit 0
	fi
    fi

    echo -e "\n"
 }

execute_chroot_command () {
    execute_command "arch-chroot /mnt /bin/bash -c \"${1}\""
}

create_a_partition () {
     # get sector number of first useable block
     first_sector=$(sgdisk -F $4)

     echo "creating partition $1: Size: $2 Type: $3 Device: $4 First Sector: ${first_sector}"
     
     # create partition
     if [ $2 = "remaining" ]
     then
	 end_sector=$(sgdisk -E $4)
	  execute_command "sgdisk -n $1:${first_sector}:${end_sector} -t $1:$3 $4"
     else
	  execute_command "sgdisk -n $1:${first_sector}:$2 -t $1:$3 $4"
     fi 
 }

#usage
print_usage () {
cat << endUsage
NAME 
    install-arch - install a basic Linux Arch environment in Virtual Box
    
SYNOPSIS
    install-arch [-c]

DESCRIPTION
    install-arch is a basic bash script that configures a system for Arch linux and installs an 
    Arch Linux environment.

    the script follows the steps outlined in the arch installation guide:
    https://wiki.archlinux.org/index.php/installation_guide

    this script is intended to be used for installing Arch in a Virtual Box environment

    to assist with debugging users can choose to be prompted before executing a command or step

    the script creates a UEFI partition and uses GRUB as its bootloader
    
    drive will be partitioned as follows:
        1 - 512MB -UEFI boot
        2 - 35G - root
        3 - 5G - swap
        4 - remaining space - home

OPTIONS
    -c    prompt user for confirmation before executing each command

endUsage
}

#print warning
cat << endIntro

Arch Installer
=============
Before you continue, ensure that:
    - you are logged in as 'root'
    - you have enabled UEFI
    - you are connected to the internet

Arch Installer will execute the following steps:
    #1.1 - set keyboard layout
    #1.2 - verify boot mode
    #1.3 - test internet connection
    #1.4 - update system clock
    #1.5 - partition the disks
    #1.6 - format the partitions
    #1.7 - turn on swap
    #1.8 - mount file systems
    #2.1 - select the mirrors
    #2.2 - install base packages
    #3.1 - fstab
    #3.2 - chroot
    #3.3 - timezone
    #3.4 - locale
    #3.5 - hostname
    #3.6 - network configuration
    #3.7 - initramfs
    #4.0 - root password
    #4.1 - create user
    #4.2 - sudo permissions
    #5.0 - boot loader
    #6.0 - reboot

endIntro

# last chance to exit befoer the script starts :)
choice "Continue?"

#### Pre-Installation ####
echo -e "##Pre-installation\n"

#1.1 - set keyboard layout
echo -e "#1.1 - set keyboard layout"
echo -e "skipped because I use the default of US\n"

#1.2 - verify boot mode
echo "#1.2 - Verify the boot mode"
execute_command "ls -d /sys/firmware/efi/efivars"

#1.3 - test internet connection
echo "#1.3 - test internet connection"
execute_command "ping -W 3 -c 1 'google.com.au'"
    
#1.4 - update system clock
echo "#1.4 - update system clock"
execute_command "timedatectl set-ntp true"
 
#1.5 - partition the disks
echo "#1.5 - partition disk"

partition_info="The following partitions will be created:
/dev/sda1 512MB  EFI System
/dev/sda2 30G Linux FileSystem
/dev/sda3 5G  Linux swap
/dev/sda4 34G Linux FileSystem"

device="/dev/sda"

#clear out existing partition table and convert to GPT
execute_command "sgdisk -og ${device}" "${partition_info}" 

create_a_partition 1 "+512M" "ef00" ${device} #UEFI boot
create_a_partition 2 "+35G" "8300" ${device} #root
create_a_partition 3 "+5G" "8200" ${device} #swap
create_a_partition 4 "remaining" "8300" ${device} #home

#1.6 - format the partitions
echo  "#1.6 - format partitions"

execute_command "mkfs.fat -F32 /dev/sda1"
execute_command "mkfs.ext4 /dev/sda2"
execute_command "mkfs.ext4 /dev/sda4"

#1.7 - turn on swap
echo "#1.7a - turn on swap"

execute_command "mkswap /dev/sda3"
execute_command "swapon /dev/sda3"

#1.8 - mount file systems
echo  "#1.7b - mount file systems"

execute_command "mount /dev/sda2 /mnt"

execute_command "mkdir /mnt/boot"
execute_command "mount /dev/sda1 /mnt/boot"

execute_command "mkdir /mnt/home"
execute_command "mount /dev/sda4 /mnt/home"

#### Installation ####
echo -e "##Installation\n"

#2.1 - select the mirrors
echo  "#2.1 - select the mirrors"

execute_command "wget \"https://www.archlinux.org/mirrorlist/?use_mirror_Status=on\" -O new-mirrorlist"
execute_command "sed -i -e 's/#Server/Server/' new-mirrorlist"
execute_command "cp new-mirrorlist /etc/pacman.d/mirrorlist"

#2.2 - install base packages
echo "#2.2 - Install base packages"

execute_command "pacstrap /mnt base base-devel"

#### Configure the system ####
echo -e "Configure the system\n"

#3.1 - fstab
echo "#3.1 - fstab"
execute_command "genfstab -U -p /mnt >> /mnt/etc/fstab"

#3.2 - chroot
echo "#3.2 - mount chroot"
echo "skipped - don't need to do this - see run_in_chroot command"

#4.0 - chroot
echo "#3.2 - chroot"
execute_command "cp install-chroot.sh /mnt/home/install-chroot.sh"
execute_chroot_command "chmod +x /home/install-chroot.sh"
execute_chroot_command "/home/install-chroot.sh ${confirm_command}"
execute_chroot_command "rm /home/install-chroot.sh"

#6.0 - reboot
echo "#6.0 - unmount and reboot"
execute_command "umount -R /mnt"
execute_command "reboot"
