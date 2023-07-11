#!/bin/bash

### only for fedora
# python3 -m pip install ansible-navigator --user
# python3 -m pip install ansible-core --user

ansible-playbook -i inventory configure_podman.yml
ansible-navigator run configure_skupper.yml -i inventory -m stdout --pp never --eei localhost/ee-skupper:1.1
