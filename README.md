ARM Image Toolkit
=================

Automation of sdcard image building and provisioning for ARM.
At first you need to adjust a configuration file, it's placed in `rpi.json`

Requirements:
- vagrant
- VirtualBox
- bash
- GNU make
- qemu
- wget

## Quick start

#### 1) Running built image
```
make build_raspbian_arm
make run_raspbian_arm

```

#### 2) Flashing built image into sdcard
```
make build_raspbian_arm USER_PASSWD=some_passwd
make flash_sdcard MMC_DEVICE=/dev/mmcblk0
```

## Usage with Ansible

```
make build_raspbian_arm PLAYBOOK=/path/to/ansible/playbook.yml
```

If you are using roles from Ansible Galaxy, then you may want to install them at first.
To install Ansible Galaxy roles create a file `.image-builder.sh` in same folder as playbook.yml
The file needs to be executable.

Example:
```
#!/bin/bash

ansible-galaxy install blackandred.server_multi_user
ansible-galaxy install blackandred.server_docker_project
ansible-galaxy install blackandred.server_ssh_fallback_port
ansible-galaxy install blackandred.server_basic_software
ansible-galaxy install blackandred.server_basic_security
```

## Usage without Ansible

You may want to delete Ansible section in `rpi.json` and run just:

```
make build_raspbian_arm
```

## Parameters

If you do not want to always type parameters in shell you can save them in the `.env` file.

Example of .env file:
```
MMC_DEVICE=/dev/mmcblk0
```

With such env file you can type just:

```
make flash_sdcard
```

