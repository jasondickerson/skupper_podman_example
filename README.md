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

Next, create a custom Ansible Execution Environment container, with the skupper.network collection.  This EE will need to be present in the podman registry for the unprivileged user.  The creation of this EE is outside the scope of this example, but required for it to work.  ( If I have time I may update to include an open source EE container image for use. )

Update the ansible-navigator line in the run_config.bash script to have the name of your execution environment.  I chose localhost/ee-skupper:1.1.  

#### Skupper CLI

For my purposes I would like to version control the skupper command I am using.  As such, download the desired version of skupper and place the extracted skupper command in the playbook directory under files on all 3 hosts.  I used this version of skupper:  

<https://github.com/skupperproject/skupper/releases/download/1.4.1/skupper-cli-1.4.1-linux-amd64.tgz>

### What needs to be configured

#### Ansible Vault Password File and vars/vault.yml

Next, either use the Ansible Vault password provided in .secret, or change the password as desired.

If the password is changed, create a new vars/vault.yml with the following content:

    ---
    ansible_become_password: your_password_here

This sets the password to elevate privileges via sudo.  If the ansible user can sudo without password, the vault.yml is not required and can be removed from the configure_*.yml playbooks.  Again, do this on all 3 hosts.

#### The Skupper service definition file

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

### Time to configure and Start Skupper

#### Host configuration and Start Skupper

Now, it is possible to create the host configuration using:

    # ./create_install_host_inventory.bash skupper1

This will run the playbook to configure an Ansible playbook inventory directory.  

Now, it is possible to configure and start Skupper using:

    # ./run_config.bash

Once completed, your skupper host will be online!

#### Client configuration and Start Skupper

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

### Accessing the Web Sites

On the skupper host, skupper1, you can access the clienta and clientb web sites as follows:

- clienta website: <http://0.0.0.0:8081>
- clientb website: <http://0.0.0.0:8082>

Further, anything that can connect to skupper1, 192.168.1.3, can connect to the web sites on clienta and clientb.  For instance, the clienta and clientb websites are reachable from any host on the 192.168.1.0/24 network at the following:

- clienta website: <http://192.168.1.3:8081>
- clientb website: <http://192.168.1.3:8082>

Without the Skupper environment running, nothing on the physical network would be able to reach the web sites on the libvirt network.

I hope you found this example helpful!
