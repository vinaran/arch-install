#!/bin/bash

# copied over choice and execute_command from install-arch.sh
# the functions are small, not worth the complexity of seperating into
# individual files

confirm_command=$1

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
	echo "$2"
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

#3.3 - timezone
echo "3.3 - timezone"

execute_command "ln -s -f /usr/share/zoneinfo/Australia/Melbourne /etc/localtime"
execute_command "hwclock --systohc --utc"

#3.4 - locale
echo "#3.4 - locale"

lang="en_AU.UTF-8"
execute_command "sed -i -e \"s/#${lang}/${lang}/\" /etc/locale.gen"
execute_command "locale-gen"
execute_command "echo LANG=${lang} > /etc/locale.conf"
execute_command "LANG=${lang}"

#3.5 - hostname
echo "#3.5 - hostname"

hostname="archie"
execute_command "echo ${hostname} > /etc/hostname"

#3.6 -  multilib
echo "#3.6 - multilib"
execute_command "sed -i -e 's/#\[multilib\]/\[multilib\]\nInclude = \/etc\/pacman.d\/mirrorlist/' /etc/pacman.conf"

#update system packages
echo "#3.7 - update packages"
execute_command "pacman -Syu"

#3.7 - network configuration
echo "#3.7 - network configuration"
echo "skipped - VM connects via the hosts network"

#3.7 - initramfs
echo "#3.7 - initramfs"
echo "skipped - this is not a 'special' configuration" 

#4.0 - root password
echo "#4.0 - Root password"
execute_command "passwd"

#4.1 - create user
echo "#4.1 - create user"

user_name=vnaran
execute_command "useradd -m -g users -G wheel,storage,power -s /bin/bash ${user_name}"
execute_command "passwd ${user_name}"

#4.2 - sudo permissions
echo "#4.2 - sudo permissions"

sudo_permission="%wheel ALL=(ALL) ALL"
new_sudo_permission="%wheel ALL=(ALL) ALL\n\n#sudoers must use root password\nDefaults rootpw"
tmp_sudo_file="/etc/sudoers.tmp"

execute_command "pacman -S sudo --noconfirm"
execute_command "cp /etc/sudoers ${tmp_sudo_file}"
execute_command "sed -i -e \"s/# $sudo_permission/$new_sudo_permission/\" $tmp_sudo_file"
execute_command "visudo --check -f ${tmp_sudo_file}"

execute_command "cp /etc/sudoers /etc/sudoers.bak"
execute_command "cp ${tmp_sudo_file} /etc/sudoers"
execute_command "rm ${tmp_sudo_file}"

#5.0 - boot loader
echo "#5.0 - boot loader"

execute_command "bootctl install"

uuid="$(blkid -s PARTUUID -o value /dev/sda2)"
text="title Arch Linux\nlinux /vmlinuz-linux\ninitrd /initramfs-linux.img\noptions root=PARTUUID=$uuid rw"

execute_command "echo -e \"${text}\" >  /boot/loader/entries/arch.conf"
