Vagrant.configure("2") do |config|
  config.ssh.insert_key = false
  config.vm.box = "centos/7"
  config.vm.synced_folder ".", "/vagrant", type: "virtualbox", mount_options: ["umask=033"]

  config.vm.define "ansible-tower" do |tower|
     tower.vm.network "private_network", ip: "192.168.33.200"
     tower.vm.provision "file", source: "#{Dir.home}/.vagrant.d/insecure_private_key", destination: "/home/vagrant/.ssh/insecure_private_key"
     tower.vm.provision "shell" do |s|
      s.inline = <<-SHELL
        cp /home/vagrant/.ssh/insecure_private_key /home/vagrant/.ssh/id_rsa
        chown vagrant /home/vagrant/.ssh/id_rsa
        chmod 400 /home/vagrant/.ssh/id_rsa
      SHELL
     end
     tower.vm.network "forwarded_port", guest: 443, host: 8443
     tower.vm.network "forwarded_port", guest:80, host:8080
     tower.vm.network "forwarded_port", guest: 15672, host: 5672
     tower.vm.provider "virtualbox" do |vb|
        vb.cpus = "2"
        vb.memory = "4096"
     end
  end

  config.vm.define "postgres" do |postgres|
     postgres.vm.network "private_network", ip: "192.168.33.202"
     postgres.vm.network "forwarded_port", guest: 5432, host: 15432
     postgres.vm.provider "virtualbox" do |vb|
        vb.cpus = "2"
        vb.memory = "2048"
     end
  end

  config.vm.define "ansible" do |control|
     control.vm.network "private_network", ip: "192.168.33.201"
     control.vm.provision "file", source: "#{Dir.home}/.vagrant.d/insecure_private_key", destination: "/home/vagrant/.ssh/insecure_private_key"
     control.vm.provision "shell" do |s|
      s.inline = <<-SHELL
        cp /home/vagrant/.ssh/insecure_private_key /home/vagrant/.ssh/id_rsa
        chown vagrant /home/vagrant/.ssh/id_rsa
        chmod 400 /home/vagrant/.ssh/id_rsa
      SHELL

     end

     # use below provison block to install tower on local vagrant machine
     control.vm.provision "ansible_local" do |ansible|
         ansible.playbook = "vagrant.yml"
         ansible.inventory_path = "environments/vagrant"
         ansible.limit = "all"
         ansible.raw_arguments = ['-vvv']
         ansible.raw_arguments = ['--check']
         ansible.raw_arguments = ['--vault-password-file=vault_pass/vault_pass.txt']
         ansible.verbose= true
     end
  end
end
