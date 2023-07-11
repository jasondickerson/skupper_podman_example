#!/bin/bash
ansible-playbook create_customer_inventory.yml --extra-vars "customer_name=${1} customer_port=${2}"
