ARM Image Builder
=================

Automation of sdcard image building for ARM.
At first you need to adjust a configuration file, it's placed in `rpi.json`


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

