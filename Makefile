
download_vendor:
	if [[ ! -d ./vendor ]]; then \
		git clone git@github.com:solo-io/packer-builder-arm-image.git vendor; \
	else \
		cd vendor && git reset --hard HEAD && git pull
	fi

	