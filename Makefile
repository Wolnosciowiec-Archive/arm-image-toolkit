.SILENT:

PLAYBOOK=../playbook.yml

all:
	printf " >> build_raspbian_arm PLAYBOOK=../playbook.yml\n"

download_vendor:
	if [[ ! -d ./vendor ]]; then \
		git clone git@github.com:solo-io/packer-builder-arm-image.git vendor; \
	else \
		cd vendor && git reset --hard HEAD > /dev/null && git pull; \
	fi

bring_up_vagrant:
	cd vendor && vagrant up --no-provision

join_ansible_playbook_into_volume:
	if [[ $$(dirname ${PLAYBOOK}) != ".." ]]; then\
		rm -rf ./vendor/.ansible-provision || true; \
		cp -pr $$(dirname ${PLAYBOOK}) ./vendor/.ansible-provision; \
	fi

apply_rpi_config:
	cp ./rpi.json vendor/example.json
	sed -i "s={{playbook_path}}=/vagrant/.ansible-provision/$$(basename ${PLAYBOOK})=g" vendor/example.json

apply_custom_provision:
	cd vendor && vagrant ssh -c 'sudo apt-get install -y ansible'

	if [[ -f ./vendor/.ansible-provision/.image-builder.sh ]]; then \
		cd vendor && vagrant ssh -c 'sudo /vagrant/.ansible-provision/.image-builder.sh && sudo chown vagrant:vagrant -R /etc/ansible/roles' 2>/dev/null || true; \
	fi

fix_dns:
	cd vendor && vagrant ssh -c 'sudo /bin/bash -c "echo \"nameserver 8.8.8.8\" > /etc/resolv.conf"'

build_arm_image:
	cd vendor && vagrant provision

build_arm_image_quick:
	cd vendor && vagrant provision --provision-with build-image

build_raspbian_arm: download_vendor bring_up_vagrant fix_dns join_ansible_playbook_into_volume apply_custom_provision apply_rpi_config build_arm_image

build_raspbian_arm@quick: fix_dns join_ansible_playbook_into_volume apply_custom_provision apply_rpi_config build_arm_image_quick
