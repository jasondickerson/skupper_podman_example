#!/bin/bash
ansible-playbook create_install_host_inventory.yml --extra-vars "skupper_host=${1}"

