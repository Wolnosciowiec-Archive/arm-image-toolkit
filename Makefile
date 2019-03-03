.SILENT:

CONFIG=./rpi.json
PLAYBOOK=./ansible/default-playbook.yml
QEMU_IMAGE=./img/arm-image.img
QEMU_KERNEL=./vendor/kernel.img
MMC_DEVICE=/dev/mmcblk0
USER_PASSWD=raspberry
SUDO=sudo
ANSIBLE_OPTS=


IS_ENV_PRESENT=$(shell test -e .env && echo -n yes)

ifeq ($(IS_ENV_PRESENT), yes)
	include .env
	export $(shell sed 's/=.*//' .env)
endif

# Colors
COLOR_RESET   = \033[0m
COLOR_INFO    = \033[32m
COLOR_COMMENT = \033[33m

_info:
	printf " >> ${COLOR_INFO} ${MSG}${COLOR_RESET}\n\n"

## This help screen
help:
	printf "${COLOR_COMMENT}Usage:${COLOR_RESET}\n"
	printf " make [target]\n\n"
	printf "${COLOR_COMMENT}Available targets:${COLOR_RESET}\n"
	awk '/^[a-zA-Z\-\_0-9\.@]+:/ { \
		helpMessage = match(lastLine, /^## (.*)/); \
		if (helpMessage) { \
			helpCommand = substr($$1, 0, index($$1, ":")); \
			helpMessage = substr(lastLine, RSTART + 3, RLENGTH); \
			printf " ${COLOR_INFO}%-16s${COLOR_RESET}\t\t%s\n", helpCommand, helpMessage; \
		} \
	} \
	{ lastLine = $$0 }' $(MAKEFILE_LIST)

	printf " \n\nAvailable variables:"
	(head -n10 | tail -n 9) < ./Makefile

download_vendor:
	mkdir -p vendor
	make _info MSG="Downloading dependencies"

	if [[ ! -d ./vendor/packer-builder-arm-image ]]; then \
		git clone https://github.com/solo-io/packer-builder-arm-image.git vendor/packer-builder-arm-image; \
	else \
		cd vendor/packer-builder-arm-image && git reset --hard HEAD > /dev/null && git pull; \
	fi

	if [[ ! -f ./vendor/kernel.img ]]; then \
		wget https://github.com/M0Rf30/simonpi/blob/master/simonpiemu/kernels/rpi/Image\?raw\=true -O vendor/kernel.img; \
	fi
#	if [[ ! -d ./vendor/qemu-rpi-kernel ]]; then \
#		git clone https://github.com/dhruvvyas90/qemu-rpi-kernel.git ./vendor/qemu-rpi-kernel; \
#	else \
#		cd vendor/qemu-rpi-kernel && git pull; \
#	fi

bring_up_vagrant:
	make _info MSG="Bringing up machine"
	cd vendor/packer-builder-arm-image && vagrant halt || true
	cd vendor/packer-builder-arm-image && vagrant up --no-provision

join_ansible_playbook_into_volume:
	make _info MSG="Copying Ansible playbook into volume"
	if [[ $$(dirname ${PLAYBOOK}) != ".." ]]; then\
		rm -rf ./vendor/packer-builder-arm-image/.ansible-provision || true; \
		cp -prL $$(dirname ${PLAYBOOK}) ./vendor/packer-builder-arm-image/.ansible-provision; \
	fi

apply_rpi_config:
	make _info MSG="Applying ${CONFIG} into the machine"

	cp ${CONFIG} vendor/packer-builder-arm-image/example.json
	sed -i "s|{{playbook_path}}|/vagrant/.ansible-provision/$$(basename ${PLAYBOOK})|g" vendor/packer-builder-arm-image/example.json
	sed -i "s|{{user_passwd}}|${USER_PASSWD}|g" vendor/packer-builder-arm-image/example.json
	sed -i "s|{{ansible_opts}}|${ANSIBLE_OPTS}|g" vendor/packer-builder-arm-image/example.json

apply_custom_provision:
	make _info MSG="Installing Ansible"
	cd vendor/packer-builder-arm-image && vagrant ssh -c 'sudo apt-get update && sudo apt-get install -y ansible sshpass'

	make _info MSG="Running a custom provision (.image-builder.sh from playbook directory)"
	if [[ -f ./vendor/packer-builder-arm-image/.ansible-provision/.image-builder.sh ]]; then \
		cd vendor/packer-builder-arm-image && vagrant ssh -c 'sudo /vagrant/.ansible-provision/.image-builder.sh && sudo chown vagrant:vagrant -R /etc/ansible/roles' 2>/dev/null || true; \
	fi

fix_dns:
	make _info MSG="Setting DNS"
	cd vendor/packer-builder-arm-image && vagrant ssh -c 'sudo /bin/bash -c "echo \"nameserver 8.8.8.8\" > /etc/resolv.conf"'

build_arm_image:
	make _info MSG="Starting build..."
	cd vendor/packer-builder-arm-image && vagrant provision

retry_build_arm_image: join_ansible_playbook_into_volume apply_custom_provision apply_rpi_config
	make _info MSG="Retrying build..."
	cd vendor/packer-builder-arm-image && vagrant provision --provision-with build-image

## Build Raspbian image from [CONFIG]
build_raspbian_arm: download_vendor bring_up_vagrant fix_dns join_ansible_playbook_into_volume apply_custom_provision apply_rpi_config build_arm_image move_built_image

## Retry building of Raspbian image (a little bit faster)
build_raspbian_arm@retry: fix_dns join_ansible_playbook_into_volume apply_custom_provision apply_rpi_config build_arm_image_quick move_built_image

move_built_image:
	make _info MSG="Moving built image to ./img directory"
	mv ./vendor/packer-builder-arm-image/output-arm-image.img ./img/arm-image.img

## Flash image into sdcard [MMC_DEVICE]
flash_sdcard:
	read -r -p "Are you sure? This will erase ${MMC_DEVICE} completly [y/N] " response; \
	if [[ $${response} == "y" ]]; then \
		set -x; ${SUDO} dd bs=4M if=./img/arm-image.img of=${MMC_DEVICE} conv=fsync; \
	fi

## Run built image with QEMU
run_raspbian_arm:
	set -x; qemu-system-arm \
		-kernel ${QEMU_KERNEL} \
		-cpu arm1176 \
		-m 256 \
		-M versatilepb \
		-serial stdio \
		-append "root=/dev/sda2 rootfstype=ext4 rw" -hda ${QEMU_IMAGE} \
		-net nic -net user,hostfwd=tcp::22222-:22,hostfwd=tcp::22280-:80\
		-no-reboot

## SSH into vm
vm_ssh:
	cd vendor/packer-builder-arm-image && vagrant ssh
