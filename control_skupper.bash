#!/bin/bash

case ${1} in

  on)
    echo "Activating Skupper:"
    systemctl --user enable --now skupper-podman
    podman system service --time 60 & sleep 1
    skupper status
    skupper link status --show-incoming-links
    skupper service status
    ;;

  off)
    echo "De-activating Skupper:"
    systemctl --user disable --now skupper-podman
    ;;

  status)
    systemctl --user status skupper-podman
    ;;

esac

case ${1}_${2} in

  on_firewall)
    echo "Enable Skupper firewall rules:"
    for PORT in 55671 8081 8082; do
      sudo firewall-cmd --add-port=${PORT}/tcp
    done
    sudo firewall-cmd --runtime-to-permanent
    ;;

  off_firewall)
    echo "Disable Skupper firewall rules:"
    for PORT in 55671 8081 8082; do
      sudo firewall-cmd --remove-port=${PORT}/tcp
    done
    sudo firewall-cmd --runtime-to-permanent
    ;;

esac

