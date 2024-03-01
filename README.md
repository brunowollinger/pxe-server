## Table of Contents

1. [Server Setup](#server-setup)<br>
    1.1. [Install Required Packages](#install-required-packages)<br>
    1.2. [Create Folder Structure](#create-folder-structure)<br>
    1.3. [TFTP and Proxy DHCP Configuration](#tftp-and-proxy-dhcp-configuration)<br>
    1.4. [HTTP Configuration](#http-configuration)<br>
    1.5. [Samba Configuration](#samba-configuration)<br>
    1.6. [NFS Configuration](#nfs-configuration)<br>

2. [File Preparation](#file-preparation)<br>
    2.1. [Windows](#windows)<br>
    2.2. [Windows Additional Files](#windows-additional-files)<br>
    2.3. [Ubuntu](#ubuntu)<br>
    2.4. [Ubuntu Preseed (Optional)](#ubuntu-preseed-optional)<br>

3. [Build iPXE](#build-ipxe)<br>
    3.1. [Install Required Packages](#install-required-packages-1)<br>
    3.2. [Clone Repository](#clone-repository)<br>
    3.3. [Modify Source Code (Optional)](#modify-source-code-optional)<br>
    3.4. [Create Script](#create-script)<br>
    3.5. [Compile Source Code](#compile-source-code)<br>
    3.6. [Selection Menu Creation](#selection-menu-creation)<br>

4. [Docker](#docker)<br>
    4.1. [Install Required Packages](#install-required-packages-2)<br>
    4.2. [Adapting to Your Environment](#adapting-to-your-environment)<br>
    4.3. [Using the Container](#using-the-container)<br>

5. [References](#references)<br>
   

## Server Setup

### Install Required Packages

```bash
apt install -y dnsmasq nginx-light samba nfs-kernel-server
```

### Create Folder Structure

```bash
mkdir -p /tftpboot/{windows,ubuntu}
```

### TFTP and Proxy DHCP Configuration

Backup the configuration file.

```bash
cp /etc/dnsmasq.conf /etc/dnsmasq.conf.old
```

Overwrite the configuration file.

```bash
cat <<EOF > /etc/dnsmasq.conf
# Disable Built-in DNS Server
port=0
# Enable TFTP Server
enable-tftp
# Set TFTP Base Folder
tftp-root=/tftpboot
# Set boot file to x64 machines with UEFI firmware
pxe-service=x86-64_EFI,,ipxe.efi
# Set boot file to x64 machines with BIOS/Legacy firmware
#pxe-service=x86PC,,ipxe.pxe
# Set DHCP Range and Proxy operation mode
dhcp-range=192.168.15.0,proxy
# Enable Logging
log-dhcp
# Set log file
log-facility=/var/log/dnsmasq.log
EOF
```

Restart the service to apply changes.

```bash
systemctl restart dnsmasq
```

### HTTP Configuration

Overwrite the configuration file.

```bash
cat <<EOF > /etc/nginx/sites-enabled/default
server {
        listen 80 default_server;
        listen [::]:80 default_server;
        #root /var/www/html;
        root /tftpboot;
        #index index.html;
        server_name _;
        location / {
                try_files $uri $uri/ =404;
        }
}
EOF
```

Restart the service to apply changes.

```bash
systemctl restart nginx
```

### Samba Configuration

Backup the configuration file.

```bash
cp /etc/samba/smb.conf /etc/samba/smb.conf.old
```

Overwrite the configuration file.

```bash
cat <<EOF > /etc/samba/smb.conf
[global]
   workgroup = WORKGROUP
   server string = Samba Server
   security = user
   map to guest = bad user
   guest account = nobody

[windows]
   path = /tftpboot/windows
   guest ok = yes
   read only = yes
   browseable = yes
EOF
```

Restart the service to apply changes.

```bash
systemctl restart smbd
```

### NFS Configuration

Backup the configuration file.

```bash
cp /etc/exports /etc/exports.old
```

Overwrite the configuration file. Change the subnet and mask as needed

```bash
cat <<EOF >> /etc/exports
/tftpboot/ubuntu    192.168.15.0/24(ro,no_root_squash,no_subtree_check)
EOF
```

Export the folder

```bash
exportfs -av
```

Restart the service

```bash
systemctl restart nfs-kernel-server
```

## File Preparation

### Windows

Mount your Windows ISO

```bash
mkdir /mnt/cdrom && mount ~/path/to/iso /mnt/cdrom
```

Copy the content to the HTTP/SMB Folder

```bash
cp -rv /mnt/cdrom /tftpboot/windows
```

Unmount the ISO after copying it's contents

```bash
umount /mnt/cdrom
```

### Windows Additional Files

Download `wimboot` from ipxe's repository

```bash
wget 'https://github.com/ipxe/wimboot/releases/latest/download/wimboot' -o /tftpboot/windows/wimboot
```

Create the `winpeshl.ini` file

```bash
cat <<EOF > /tftpboot/windows/winpeshl.ini
[LaunchApp]
AppPath = .\install.bat
EOF
```

Create the `install.bat` file, which contains a script to map our smb share and execute the installer

```bash
cat <<EOF > /tftpboot/windows/install.bat
wpeinit

net use i: \\192.168.15.200\windows

i:\setup.exe
EOF
```

### Ubuntu

Mount your Ubuntu ISO

```bash
mkdir /mnt/cdrom && mount ~/path/to/iso /mnt/cdrom
```

Copy the content to the HTTP/SMB Folder

```bash
cp -rv /mnt/cdrom/. /tftpboot/ubuntu
```

Unmount the ISO after copying it's contents

```bash
umount /mnt/cdrom
```

### Ubuntu Preseed (Optional)

This file will set the Locale, Keyboard Layout to Brazilian Portuguese and System Language to English.

```bash
cat <<EOF > /tftpboot/ubuntu/preseed/ubuntu.seed
# The values can also be preseeded individually for greater flexibility.
d-i debian-installer/language string en
d-i debian-installer/locale string pt_BR.UTF-8
# Keyboard selection.
d-i keyboard-configuration/xkb-keymap select br
EOF
```

## Build iPXE

This repository have the same [ipxe.efi](ipxe/ipxe.efi) compiled binary available, but feel free to build it yourself.

### Install Required Packages

```bash
apt install -y git gcc make liblzma-dev
```

### Clone Repository

```bash
git clone https://github.com/ipxe/ipxe.git ~/ipxe
```

### Modify Source Code (Optional)

Enable NFS support, which is usually necessary when booting live USB ISOs.

```bash
sed -i 's/#undef\tDOWNLOAD_PROTO_NFS/#define\tDOWNLOAD_PROTO_NFS/' ~/ipxe/src/config/general.h
```

The following commands are used during ipxe troubleshooting.

Enable ping command support

```bash
sed -i 's/\/\/#define\ PING_CMD/#define\ PING_CMD/' ~/ipxe/src/config/general.h
```

Enable command to show ip information

```bash
sed -i 's/\/\/#define\ IPSTAT_CMD/#define\ IPSTAT_CMD/' ~/ipxe/src/config/general.h
```

Enable Shutdown and Reboot commands inside iPXE CLI

```bash
sed -i 's/\/\/#define\ REBOOT_CMD/#define\ REBOOT_CMD/' ~/ipxe/src/config/general.h
sed -i 's/\/\/#define\ POWEROFF/#define\ POWEROFF/' ~/ipxe/src/config/general.h
```

### Create Script

This script will request the seletion menu to all boot options.

```bash
cat <<EOF > ipxe/src/embed.ipxe
#!ipxe

isset ${next-server} || set next-server ${proxydhcp/dhcp-server}

dhcp

chain http://${next-server}/menu.ipxe || shell
EOF
```

### Compile Source Code

In this case we'll be compiling to x64 machines with UEFI Firmware.

```bash
cd ipxe/src/ && make bin-x86_64-efi/ipxe.efi EMBED=embed.ipxe
```

Read the [official documentation](https://ipxe.org/appnote/buildtargets) for all build targets.

When the build process finish, copy the file the TFTP server folder.

```bash
cp ~/ipxe/src/bin-x86_64-efi/ipxe.efi /tftpboot
```

### Selection Menu Creation

This menu have entries for Windows, Ubuntu and Boot from Hard Disk.

```bash
cat <<EOF > /tftpboot/menu.ipxe
#!ipxe

isset ${menu-default} || set menu-default WinPE

################################################## 
:start
menu Welcome to iPXE's Boot Menu
item WinPE Install Windows 10
item Ubuntu Ubuntu Live
item BootHardDisk Boot from Hard Disk
choose --default exit --timeout 15000 target && goto ${target}
################################################## 

:WinPE
  kernel http://${next-server}/windows/wimboot
  initrd http://${next-server}/windows/winpeshl.ini
  initrd http://${next-server}/windows/install.bat
  initrd http://${next-server}/windows/bootmgr.efi                  bootmgr.efi
  initrd http://${next-server}/windows/efi/boot/bootx64.efi         Bootx64.efi
  initrd http://${next-server}/windows/boot/bcd                     BCD
  initrd http://${next-server}/windows/boot/boot.sdi                boot.sdi
  initrd http://${next-server}/windows/sources/boot.wim             boot.wim
  boot

:Ubuntu
  kernel http://${next-server}/ubuntu/casper/vmlinuz
  initrd http://${next-server}/ubuntu/casper/initrd
  imgargs vmlinuz initrd=initrd root=/dev/nfs boot=casper file=preseed/ubuntu.seed keyboard-configuration/layoutcode=br netboot=nfs nfsroot=${next-server}:/tftpboot/ubuntu ip=dhcp --
  boot

:BootHardDisk
  exit
  goto start
EOF
```

## Docker

This repository contains a docker version of the server that can only install Windows.

### Install Required Packages

```bash
apt install -y docker.io docker-compose
```

### Adapting to Your Environment

- Edit [ipxe.efi](conf/dnsmasq.conf) changing `dhcp-range=192.168.15.0,proxy` line to match your subnet address

- Edit [install.bat](files/install.bat) changing `net use i: \\192.168.15.200\windows` line to match the host machine address

### Using the Container

- Mount a **single** windows ISO to `files/iso`
- Build and run the container in background using `docker-compose up -d`
- Stop the container using `docker-compose down`

## References

- [Arch Wiki dnsmasq - PXE Server](https://wiki.archlinux.org/title/dnsmasq#PXE_server)
- [Arch Wiki dnsmasq - Proxy DHCP](https://wiki.archlinux.org/title/dnsmasq#Proxy_DHCP)
- [Arch Wiki dnsmasq - TFTP](https://wiki.archlinux.org/title/dnsmasq#TFTP_server)
- [iPXE official Build Reference](https://ipxe.org/download)
- [rikka0w0's iPXE customization/build guide](https://gist.github.com/rikka0w0/50895b82cbec8a3a1e8c7707479824c1)
- [iPXE official Build Targets Reference](https://ipxe.org/appnote/buildtargets)
- [robinsmidsrod's Extensive iPXE Menu Example](https://gist.github.com/robinsmidsrod/2234639#file-menu-ipxe)
- [Customizing WinPE](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/winpe-mount-and-customize?view=windows-11)
- [Adding Drivers to WinPE](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/winpe-network-drivers-initializing-and-adding-drivers?view=windows-11)
- [iPXE Official WinPE Menu Entry Reference](https://ipxe.org/howto/winpe)
- [winpeshl.ini Reference](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/winpeshlini-reference-launching-an-app-when-winpe-starts?view=windows-11)
- [NFS Configuration Reference](https://ubuntu.com/server/docs/service-nfs)
- [iPXE Official Live Ubuntu Menu Entry Reference](https://ipxe.org/appnote/ubuntu_live)
- [Docker Compose cap_add Reference](https://docs.docker.com/compose/compose-file/05-services/#cap_add)
- [All cap_add Options](https://man7.org/linux/man-pages/man7/capabilities.7.html)
