# Ansible / Ansible Tower

Use a Ansible "control" machine to install Ansible Tower ;-)


## Usage

1. install vagrant and oracle VM virtual box if its not installed on your machine yet.

2. Run below command to check if all the required vagrant plugins are installed properly:
```
$ vagrant plugin list
```
   If the above plugins are not installed, please install it using below commands:
```
vagrant plugin install vagrant-vbguest
vagrant plugin install vagrant-proxyconf

```
3. Goto base directory where you have cloned this repo and add a file vault_pass.sh with below content:
```
#!/bin/bash

echo dummySecret
```
NOTE: 'dummySecret' in above file is dummy value for secret which will be used to decrypt the passwords stored in ansible vault file stored under environment specific inventories.

4. goto to project base directory on your system where you have cloned this project and run the below command:
```
vagrant up
```
5. In case you face below error while mounting shared folder on either ansible or ansible-tower box:
```
==> ansible-tower: Mounting shared folders...
Vagrant was unable to mount VirtualBox shared folders. This is usually
because the filesystem "vboxsf" is not available. This filesystem is
made available via the VirtualBox Guest Additions and kernel module.
Please verify that these guest additions are properly installed in the
guest. This is not a bug in Vagrant and is usually caused by a faulty
Vagrant box. For context, the command attempted was:

mount -t vboxsf -o uid=1000,gid=1000 vagrant /vagrant

The error output from the command was:

mount: unknown filesystem type 'vboxsf'
```
Please follow below steps:
```
 5.1 ssh into 'ansible' or 'ansible-tower' box for which mounting failed above
 5.2 switch to root with 'sudo su -'
 5.3 run 'yum update' command
 5.4 run 'vagrant reload'
 ```
6. Run the following ansible-playbooks to run the provisioning of postgresql and ansible-tower separately
```
 vagrant ssh postgres
 sudo su -
 cd /vagrant
 ansible-playbook vagrant.yml -i environments/vagrant/hosts --connection=local -l postgresql --ask-vault-pass
```
```
 vagrant ssh tower
 sudo su -
 cd /vagrant
 ansible-playbook vagrant.yml -i environments/vagrant/hosts --connection=local -l tower --ask-vault-pass
```
7. If the vagrant provision fails with below error:
```
fatal: [192.168.33.200]: UNREACHABLE! => {"changed": false, "msg": "Failed to connect to the host via ssh: ssh: connect to host 192.168.33.200 port 22: Connection timed out\r\n", "unreachable": true}
```
Follow below steps to fix it:
```
 7.1 ssh into ansible tower box by running 'vagrant ssh ansible-tower'
 7.2 run command 'sudo ifup eth1'
 7.3 check if eth1 is configured properly
 ```

8. If the install was successful, you can access the ansible tower GUI at: https://localhost:8443 (if the forwarded port for ansible-tower box is 8443, use the port which you have specified in vagrantfile for forwarded_port for ansible-tower box).

9. If you want to restore the database follow the below mentioned steps
```
9.1 Login to ansible tower server and stop the ansible tower service -
9.2 Run the playbook and restoration of database will be done
     ansible-playbook  restore.yml -i environments/vagrant/hosts --connection=local --ask-vault-pass --become-method=su
```