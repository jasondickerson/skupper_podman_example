# skupper_podman_example

Example of using the Skupper command with podman to connect 2 network locations

## Use Case

I have the following network configuration:

- Physical network: 192.168.1.0/24
  - Physical host:  skupper1 192.168.1.3
  - libvirt host: 192.168.1.21
    - libvirt network: 192.168.122.0/24
    - Forwarding: NAT
    - libvirt VM's with web sites:
      - clienta 192.168.122.150:80
      - clientb 192.168.122.71:80

The physical network devices cannot access the web sites running on the libvirt VM's.  I would like for skupper1 to be able to reach the web sites on the 2 libvirt VM's

![Skupper Demonstration Lab Configuration](/images/Skupper_Podman_Demo.png)

## Prerequisites

### The unprivileged user

Create an unprivileged user on the skupper1, clienta, and clientb hosts.  I chose a form of my name: jdicke.  This user will need sudo rights to run commands with or without a password.  It does not matter which.  The user is also specified in the ansible.cfg.  This is the user skupper will run as.

### What needs to be installed

#### This project

Download this project to a directory under the unprivileged user's home directory on skupper1, clienta, and clientb.  
I chose ~/ansible_playbooks/configure_skupper.  

#### Ansible-Core and Ansible-Navigator

Install Ansible on all 3 hosts.  If installing via pip use the following while logged on as the unprivileged user:

    # python3 -m pip install ansible-core --user
    # python3 -m pip install ansible-navigator --user

#### Custom Ansible Execution Environment with the skupper.network community collection

Next, create a custom Ansible Execution Environment container, with the skupper.network collection.  This EE will need to be present in the podman registry for the unprivileged user on all 3 hosts.

Create a directory for the execution environment definition files.  I used /home/jdicke/exec_env/skupper-ee.  In this directory you need 2 files:

requirements.yml:  Define the Required Collections

    ---
    collections:
      - name: skupper.network

execution-environment.yml: Define the Execution Environment

    ---
    version: 3

    dependencies:
      galaxy: requirements.yml

    images:
      base_image:
        name: quay.io/ansible/awx-ee:latest

Run the following command in the directory to build the execution environment:

    # ansible-builder build --verbosity 3 --prune-images --tag ee-skupper:1.1

To copy the execution environment to another server, first save the container to a tar file using:

    # podman save --output ee_skupper_1.1.tar localhost/ee-skupper:1.1

To import the container tar file on another server, use:

    # podman load --input ee_skupper_1.1.tar

Update the ansible-navigator line in the run_config.bash script to have the name of your execution environment.  I chose localhost/ee-skupper:1.1.  

#### Skupper CLI

For my purposes I would like to version control the skupper command I am using.  Also, I am not assuming the clients will have access to download the skupper file from the Internet.  As such, download the desired version of skupper and place the extracted skupper command in the playbook directory under files on all 3 hosts.  I used this version of skupper:  

<https://github.com/skupperproject/skupper/releases/download/1.4.1/skupper-cli-1.4.1-linux-amd64.tgz>

## What needs to be configured

### Ansible Vault Password File and vars/vault.yml

Next, either use the Ansible Vault password provided in .secret, or change the password as desired.

If the password is changed, create a new vars/vault.yml with the following content:

    ---
    ansible_become_password: your_password_here

This sets the password to elevate privileges via sudo.  If the ansible user can sudo without password, the vault.yml is not required and can be removed from the configure_*.yml playbooks.  Again, do this on all 3 hosts.

### The Skupper service definition file

Create or update the files/customer_services.yml.  This file is a definition of all services you will create on the hosts.  For my example, I chose to create the following:

    ---
    services:
      clienta:
        ports:
          - 8081
        hostPorts:
          - 8081
      clientb:
        ports:
          - 8082
        hostPorts:
          - 8082

This represents that I will create skupper services on the skupper host(s) for each virtual web server.  I have chosen to assign unique ports on the host to each client, rather than unique IP Addresses, as that is more cumbersome, requires more configuration, and excessively consumes IP Addresses on my Physical Network.  

## Time to configure and Start Skupper

### Host configuration and Start Skupper

Now, it is possible to create the host configuration using:

    # ./create_install_host_inventory.bash skupper1

This will run the playbook to configure an Ansible playbook inventory directory.  

Now, it is possible to configure and start Skupper using:

    # ./run_config.bash

Once completed, your skupper host will be online!

### Client configuration and Start Skupper

Next, collect the skupper1_token file from ~/skupper_config/skupper1_token and place in the Ansible playbook directory under files on both clienta and clientb.  This provides the host information the Skupper clients will connect to.

Now to configure the clients:

On clienta run the following:

    # ./create_customer_inventory.bash clienta 8081
    # ./run_config.bash

This will create the Ansible playbook inventory information to configure clienta.

NOTE:  This command must match the skupper service name and skupper service port listed in files/customer_services.yml.  

On clientb run the following:

    # ./create_customer_inventory.bash clientb 8082
    # ./run_config.bash

Now Skupper is running on all 3 systems.  

## Accessing the Web Sites

On the skupper host, skupper1, you can access the clienta and clientb web sites as follows:

- clienta website: <http://0.0.0.0:8081>
- clientb website: <http://0.0.0.0:8082>

Further, anything that can connect to skupper1, 192.168.1.3, can connect to the web sites on clienta and clientb.  For instance, the clienta and clientb websites are reachable from any host on the 192.168.1.0/24 network at the following:

- clienta website: <http://192.168.1.3:8081>
- clientb website: <http://192.168.1.3:8082>

Without the Skupper environment running, nothing on the physical network would be able to reach the web sites on the libvirt network.

## So What Just happened?  

This example shows how to use ansible to dynamically create an Ansible inventory for a Skupper Host or Skupper Client and then configure it.  So Let's look at the commands that happen behind the scenes:

### Host Configuration

Here is the bash version of the playbook run:

    #!/bin/bash

    # Download latest skupper CLI
    cd /tmp
    curl -OL https://github.com/skupperproject/skupper/releases/download/1.4.1/skupper-cli-1.4.1-linux-amd64.tgz

    # Install skupper
    cd /usr/local/bin
    sudo tar xvzf /tmp/skupper-cli-1.4.1-linux-amd64.tgz
    sudo chown root:root skupper
    sudo chmod 755 skupper

    # install podman
    sudo yum -y install podman

    # configure podman
    sudo touch /etc/{subuid,subgid}
    sudo usermod --add-subuids 100000-165536 --add-subgids 100000-165536 ${USER}
    podman system migrate

    # start podman api, only needs to be running during skupper configuration
    # most likely will set a time like 5m or so...
    podman system service --time 0 &

    # open firewall for skupper
    sudo firewall-cmd --add-port=55671/tcp
   
    # initialize skupper as a host
    skupper --platform podman init --ingress-host $(hostname -i)

    # create token file
    skupper --platform podman token create ~/$(hostname -s)-$USER

    ### Each client skupper service must be assigned a unique IP Address or Port on the host.
    ### For this example, I chose clienta and tcp 8081

    # create skupper service, service listening
    skupper --platform podman service create clienta 8081 --host-port 8081

    # setup user for lingering
    loginctl enable-linger

    ### test command to connect to clienta via skupper
    # curl 0.0.0.0:8081

    ### Check rootless systemd unit
    # systemctl --user status skupper-podman

### Client Configuration

Here is the bash version of the playbook run:

    #!/bin/bash

    # Download latest skupper CLI
    cd /tmp
    curl -OL https://github.com/skupperproject/skupper/releases/download/1.4.1/skupper-cli-1.4.1-linux-amd64.tgz

    # Install skupper
    cd /usr/local/bin
    sudo tar xvzf /tmp/skupper-cli-1.4.1-linux-amd64.tgz
    sudo chown root:root skupper
    sudo chmod 755 skupper

    # install podman for skupper, and nginx for testing
    sudo yum -y install podman nginx

    # start nginx test site
    sudo systemctl enable --now nginx

    # configure podman
    sudo touch /etc/{subuid,subgid}
    sudo usermod --add-subuids 100000-165536 --add-subgids 100000-165536 ${USER}
    podman system migrate

    # start podman api, only needs to be running during skupper configuration
    # most likely will set a time like 5m or so...
    podman system service --time 0 &

    # initialize skupper as a host
    skupper --platform podman init --ingress none

    # store skupper token file generated by host
    cat <<EOF > /tmp/jasond-jdicke
    apiVersion: v1
    data:
      ca.crt: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURMRENDQWhTZ0F3SUJBZ0lRZk5acnNYd2UwWTVCWTJpTFBqaHVCekFOQmdrcWhraUc5dzBCQVFzRkFEQWEKTVJnd0ZnWURWUVFERXc5emEzVndjR1Z5TFhOcGRHVXRZMkV3SGhjTk1qTXdOak13TVRReE9UQTJXaGNOTWpndwpOakk0TVRReE9UQTJXakFhTVJnd0ZnWURWUVFERXc5emEzVndjR1Z5TFhOcGRHVXRZMkV3Z2dFaU1BMEdDU3FHClNJYjNEUUVCQVFVQUE0SUJEd0F3Z2dFS0FvSUJBUUNTTm9LT0t6elI5UFZqQmlyY1FENUpLaEpnU1ExeTFzbTYKVmo2MjZDSllwYld0MmgwbWhNWEt5YjFKTGpYd0tibExESDlNYktIZ3Z2SGJaTCtXR3ZFdTF3a3V1dFFTdVJtNApEQzc1eWxzb2tCc3ZaTHk2dUd2YnVNakNmMWthNU1xY3NPa01PU2NSUk03clhHeXNqRGNyRkdmWUtVZ0k2bU1wCmhraGJ2bmhxaUZBRFZLWTVQTVRmUExVd0ZPQXk5R3RlOVdTNXVwdVJxSC9LdUg1VjdUYlJwT0lIN0tEY3dKVEgKd0V2bWlEZ1N0eXNhMXY2OEZ3d2crSXBIdU93ZjZ5bE9IcUJENkNWUU5XQkNLREdvdWc1T0s4VnVqMGUxSCtkUQpRd09OTUo2ajFmeW9FbEhuSG0vZlZGMzRIZXpDWXM0RjQ5TXBnZGxuSmtqeG5PTlJsL3NGQWdNQkFBR2piakJzCk1BNEdBMVVkRHdFQi93UUVBd0lDcERBZEJnTlZIU1VFRmpBVUJnZ3JCZ0VGQlFjREFRWUlLd1lCQlFVSEF3SXcKRHdZRFZSMFRBUUgvQkFVd0F3RUIvekFkQmdOVkhRNEVGZ1FVREwwL2R6MjJGVjJORHpTaEQySklMWXVKWEtjdwpDd1lEVlIwUkJBUXdBb0lBTUEwR0NTcUdTSWIzRFFFQkN3VUFBNElCQVFBcHNrYjEwTFg3STdHbXh4cGo3S2ZDClNHL213L1JEZUwyTS9ZYXpXVHQwelpQRzlqOVROUmFrWkRjY2hzMVdQYnJFdEZtSG1hMkJxTlFUL1p5aElYdUgKUTNtN3RxVWgwR1pxdVovUnBDVUNsaVRuOCtGYy9rVW5qV0ZLdFl2S1hpYVZHMUVJL2thVlplaWtIR1lTZmVzOAo5WU1mSm9MWlRRQVdXb0VoVVBDc2pKSmtBYnFUTjZDcllLZDZtMDM4STBIOWFZb0paZHNkc1FPTHBPdHAyY0UzCldRWHNWQTVsekMxWFRURm1jbHBDaFJwVVJPSThZWlMrKzNQZ1JDV2FIY2pIZ0RDbmFFeHdka1dWU3VTbExSWmcKUVVwNmxUNnNuVDhoYlNhK0FDUzhnQmhWYXBkRFB6NFlZcUlsNEc3NmJFNGk0RzgwYy9mNm8vMk12QUE5OUUwbwotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg==
      tls.crt: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURTVENDQWpHZ0F3SUJBZ0lRU3FWaHNoL3NGeHIzdUdDQzc3NmsyVEFOQmdrcWhraUc5dzBCQVFzRkFEQWEKTVJnd0ZnWURWUVFERXc5emEzVndjR1Z5TFhOcGRHVXRZMkV3SGhjTk1qTXdOak13TVRReE9USXpXaGNOTWpndwpOakk0TVRReE9USXpXakFTTVJBd0RnWURWUVFERXdkemEzVndjR1Z5TUlJQklqQU5CZ2txaGtpRzl3MEJBUUVGCkFBT0NBUThBTUlJQkNnS0NBUUVBNGltZzc4SXJCMEFrbm1RMDAwRitjcFVPNERWQUpRY2ZzR2txNXpMallkcU0Kc3NoMWJ6am1GN1BKTjREOURoMVJDeTl2ZkJwUzUxZW5aMi9NQmEvZENLREUrZWhxUXJwaTUraUQ0QThRTnBKTQpVOEx1WmJwQ2J1TERYckVmcVRoYmxLZ2ZScVFYYm5SL0EzY2dTd0JlNjNjaE85b3p1cGtyK25GYVlVOHlyNndwCkpKcmdCM3VvSGszWnVzclF2akZERWFaMTRONVpiTTBDa2V2aE9kM3dqcTJFOHZSeEowNTlyVE9EUmo0dUtUQUIKRkR4aGd0UW8rT20yKzd1RUQxYW5OUjdpQ2FtYm5BTDRZUEt2Sys2QTQwRWRtUFFJcDhtNHJUbUIxTDhoeDhFQwpFeGlINGYydkhqa3lGenFZTnZ6WE9QcGN0bTQzaytMUWFNeEtUZ2wyQlFJREFRQUJvNEdTTUlHUE1BNEdBMVVkCkR3RUIvd1FFQXdJRm9EQWRCZ05WSFNVRUZqQVVCZ2dyQmdFRkJRY0RBUVlJS3dZQkJRVUhBd0l3REFZRFZSMFQKQVFIL0JBSXdBREFmQmdOVkhTTUVHREFXZ0JRTXZUOTNQYllWWFkwUE5LRVBZa2d0aTRsY3B6QXZCZ05WSFJFRQpLREFtZ2dzeE9USXVNVFk0TGpFdU00SUxNVGt5TGpFMk9DNHhMak9IQk1Db0FRT0hCTUNvQVFNd0RRWUpLb1pJCmh2Y05BUUVMQlFBRGdnRUJBQ0FFclpTWE9xZ0VJZ1AwWEVhYm85a1A0bXdqcVpvMUFVcVAwTDBXU25palhXai8KeWhvY1NmbkZEQ1BuaFdzRUxOYnhRdytrUkZ3RExVZTBLM0FkRUZsajdmTlY4ck9PTGFlWlRqVjEraXorMEI0UAp6U2hoMjgxcVBsREF5TWhhdWVHSjNwcWNvYURMdzdBdTlHTW5JMm54T0oxU0RLVkkwYnd0aTl5SnQ3Q3ZhZnk4CkpOUlpNZ2J6ZTJIYUZTT05pRkhDM2k5N09mQkc2YXV0alg2bmtLZUlxOHBVUmwxWkZkQjI4a1EzdXpFdUZhSnQKY25WUStZcVN6RTcvSzdRZEhiVzVCMGRFK2w0ZUNsU1YxQWszTWZOT3lGbldlR0dNblMyckIzYmRPNmZUcGw3WgpTOWNvditHeFhlQlNBcnFjTGZ4Q3FuRjNZT2lEWjErNU93K1V6cHc9Ci0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K
      tls.key: LS0tLS1CRUdJTiBSU0EgUFJJVkFURSBLRVktLS0tLQpNSUlFcEFJQkFBS0NBUUVBNGltZzc4SXJCMEFrbm1RMDAwRitjcFVPNERWQUpRY2ZzR2txNXpMallkcU1zc2gxCmJ6am1GN1BKTjREOURoMVJDeTl2ZkJwUzUxZW5aMi9NQmEvZENLREUrZWhxUXJwaTUraUQ0QThRTnBKTVU4THUKWmJwQ2J1TERYckVmcVRoYmxLZ2ZScVFYYm5SL0EzY2dTd0JlNjNjaE85b3p1cGtyK25GYVlVOHlyNndwSkpyZwpCM3VvSGszWnVzclF2akZERWFaMTRONVpiTTBDa2V2aE9kM3dqcTJFOHZSeEowNTlyVE9EUmo0dUtUQUJGRHhoCmd0UW8rT20yKzd1RUQxYW5OUjdpQ2FtYm5BTDRZUEt2Sys2QTQwRWRtUFFJcDhtNHJUbUIxTDhoeDhFQ0V4aUgKNGYydkhqa3lGenFZTnZ6WE9QcGN0bTQzaytMUWFNeEtUZ2wyQlFJREFRQUJBb0lCQVFDQ2YvTFZaZnplR2kwSApHRnRDNnkvRGZpOHZRSXJhMHRsK09iRC81MlU5T1phbU12VlFVRXkwc0pFUzdlTVhHZU9CeU1WVG52em5jTFN3CkF0cC9EWk5GUHo5cDFLbzhCc0M3Z0hkWCtsa29wQkpXNHN3Yzl2VU9kdHEwOFErTDNYRTZ2aWdONHZHQ1VzWlgKZ1kyb3VYWUwrSm04cDVQaHdEQ1lPb0FrVmtheEJsaVpPZW1GRmQwRGExd3RlNTZtVWdWb0NUaUNCVzF3dXl3dgpqeU1PbDN6RlY0TXBGcVpHcTNudzB6S3NCSjJ2ZURaeHVFWEpmTmtBTmNqYjRwcDVZWXdodWdheFI0OTRzVDNvCnV4M1E5Q3VKalJSaFQ4SWovNGZoVWp5dDhWL1M1VkttaEdybk5tYURvUy9DNHIwT0hrTzZpbzdVNEdvZGsydzMKczk2Rmx5R2hBb0dCQU92aFNnd3Fya0wzcEdBTEhac2svaGI2QnpmNDlLT05kNFlQRzZZdmVJV0ZYcVpXTE1ZYgpDTlFEUGNsRTZmb3luZmpJb3h3b3laTW8vV2RQL2pzTi9BanpjTTRrM2RWTVJ5QjlvOTFqMkplYm85ZC9CRU00CnM5TmJZUXlFSDdZcEw3aEpHc01uNVg4VWd3NnpTVkZxZkFaVCtFZFRZNnJ6emdSYlU1UGUzTkRIQW9HQkFQVjAKSmZpSWw2ZytLZUpkcnk5cFVoSVZQNWpRUXFQTDR5NlBoSTQ5dUVGcFBzZ1VQT3diemFXU3NSWUY3K1NLbUgyLwpxbkVuSGErT2duc3pwbU5NY1VYTHl2REhFMTEyUEFyV0ZpNWN5WVQvR0EvSzhwNUF4UjhaZEN4UFkrckFSY0dCCkRGTzdIVmtUUHNEWjd3Q2JDUS83WXZZSXFJZ3lzMmtrRGUxVzdZN1RBb0dCQU5kYWxycEk5VlNhdCs0ZjkrVy8KZm1RSDNqTlNEamlNWGdWOUlhYzJTL2pMYlVDOENLRE42ZDkzSGgvMTFSRGl5YXRyc3M5d3hhaWZrY3VURXU5agpzeW1RNlBxc1dnUDFZakxkd28vTUt1RXY3Z1EvS09zZWg3OTkvRHJySGZDMzVhT0F5dmhHSXBkRmFPb3c4YzF0ClJOS2FNMkViVnpHcTZmcThUckFBbHVYZEFvR0FGL1JwOEVPRWFZc0hrMndKT050U2d5bEh0Nlk3bXJpL1IwQUMKYzg5YU9DZ0pWSVdGSEpYcUVBcXM5YlZHb0V0V2JvOVNGeEQyT0xmenpBcFNac2FERjRpNEdaK1VLRDd0eFREMwpvVGExQkNIUk8xbFhMRkt0NmtjVnEyMWtGdmtFMWNtK1pqMlFzNnpKSnhFZDNqVkRRU2dMbEc5cjR6N3ZlNGRsClJKQ0RScmtDZ1lCZ2ljQURZMThKWTFiYkNHZE1qcXBIMFF3OUtXVVZBbElVRjFkK0lPNjB2VGsrSXQ5YXd4N3gKYXdzSVJHKyswTlVoUUFlM0JyZTN4b3hrQm9UdnVYNm1IRm9xNGFvMllISWNBaFpEcFNGNzJKL0h2VXBNTTF4QgpDTHl6azU5RGtyS2h3eE5IVjlaTVJwR2dsVS9wWnNHNGNjV2U3V1BPYlhld0NUZmlJMU1Bc3c9PQotLS0tLUVORCBSU0EgUFJJVkFURSBLRVktLS0tLQo=
    kind: Secret
    metadata:
      annotations:
        edge-host: 192.168.1.3
        edge-port: "45671"
        inter-router-host: 192.168.1.3
        inter-router-port: "55671"
        skupper.io/generated-by: a4f76b38-ed3e-439b-8306-2c096c421e9a
        skupper.io/site-version: 1.4.1
      creationTimestamp: null
      labels:
        skupper.io/type: connection-token
      name: skupper
    type: kubernetes.io/tls
    EOF

    # create skupper link
    skupper --platform podman link create /tmp/jasond-jdicke

    ### Each client skupper service must be assigned a unique IP Address or Port on the host.
    ### For this example, I chose clienta and tcp 8081

    # create skupper service
    skupper --platform podman service create clienta 8081

    # bind skupper service to local vm app port
    skupper --platform podman service bind clienta host host.containers.internal --target-port 80

    # setup user for lingering
    loginctl enable-linger

    ### Check rootless systemd unit
    # systemctl --user status skupper-podman

I hope you found this example helpful!
