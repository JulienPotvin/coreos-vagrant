# -*- mode: ruby -*-
# # vi: set ft=ruby :

#This installer is built using the now defunct coreos tutorials.
#They're still available on web cache : https://web.archive.org/web/20170904114419/https://coreos.com/kubernetes/docs/latest/getting-started.html
#TODO: push addons with kubelet(dns, heapster, dashboard, [kubeless])
#TODO: Ensure flannel is working (https://github.com/coreos/flannel/issues/216)

require 'fileutils'

Vagrant.require_version ">= 1.6.0"

# Make sure the vagrant-ignition plugin is installed
required_plugins = %w(vagrant-ignition)

plugins_to_install = required_plugins.select { |plugin| not Vagrant.has_plugin? plugin }
if not plugins_to_install.empty?
  puts "Installing plugins: #{plugins_to_install.join(' ')}"
  if system "vagrant plugin install #{plugins_to_install.join(' ')}"
    exec "vagrant #{ARGV.join(' ')}"
  else
    abort "Installation of one or more plugins has failed. Aborting."
  end
end

CLOUD_CONFIG_PATH = File.join(File.dirname(__FILE__), "user-data")
IGNITION_CONFIG_PATH = File.join(File.dirname(__FILE__), "config.ign")
CONFIG = File.join(File.dirname(__FILE__), "config.rb")

#Hardcoded IPs
K8S_SERVICE_IP = "10.3.0.1"

def etcdIP(num)
  return "172.17.8.#{num+100}"
end
$etcd_cluster_size = 3
$etcd_instance_name_prefix = "etcd"
etcd_endpoints = (1..$etcd_cluster_size).map { |i| ip=etcdIP(i); "http://#{ip}:2379" }

def controllerIP(num)
  return "172.17.8.#{num+200}"
end
controller_cluster_size = 1
controller_instance_name_prefix = "controller"
controller_vm_memory = 1024
controller_vm_cpus = 1
master_host = controllerIP(1) # Hardcoded to the first controller. TODO: Put controllers behind a routable IP.
controller_ips = (1..controller_cluster_size).map { |i| controllerIP(i) }

def workerIP(num)
  return "172.17.8.#{num+50}"
end
worker_cluster_size = 2
worker_vm_memory = 1024
worker_vm_cpus = 1
worker_instance_name_prefix = "worker"

#TODO: Avoid that every vagrant command triggers a new key generation
# Generate root CA
system("mkdir -p ssl && ./lib/init-ssl-ca ssl") or abort ("failed generating SSL artifacts")

# Generate admin key/cert
# TODO: make sure the superfluous CNF template > config file is not interfering
system("./lib/init-ssl ssl admin kube-admin") or abort("failed generating admin SSL artifacts")


def provisionMachineSSL(machine,certBaseName,cn,ipAddrs)
  tarFile = "ssl/#{cn}.tar"
  ipString = ipAddrs.map.with_index { |ip, i| "IP.#{i+1}=#{ip}"}.join(",")
  system("./lib/init-ssl ssl #{certBaseName} #{cn} #{ipString}") or abort("failed generating #{cn} SSL artifacts")
  machine.vm.provision :file, :source => tarFile, :destination => "/tmp/ssl.tar"
  machine.vm.provision :shell, :inline => "mkdir -p /etc/kubernetes/ssl && tar -C /etc/kubernetes/ssl -xf /tmp/ssl.tar", :privileged => true
end

# Defaults for config options defined in CONFIG
$enable_serial_logging = false
$share_home = false
$vm_gui = false
$vm_memory = 512
$vm_cpus = 1
$vb_cpuexecutioncap = 100
$shared_folders = {}
$forwarded_ports = {}

# Attempt to apply the deprecated environment variable ETCD_CLUSTER_SIZE to
# $etcd_cluster_size while allowing config.rb to override it
if ENV["ETCD_CLUSTER_SIZE"].to_i > 0 && ENV["ETCD_CLUSTER_SIZE"]
  $etcd_cluster_size = ENV["ETCD_CLUSTER_SIZE"].to_i
end

if File.exist?(CONFIG)
  require CONFIG
end

# Use old vb_xxx config variables when set
def vm_gui
  $vb_gui.nil? ? $vm_gui : $vb_gui
end

def vm_memory
  $vb_memory.nil? ? $vm_memory : $vb_memory
end

def vm_cpus
  $vb_cpus.nil? ? $vm_cpus : $vb_cpus
end

#Create etcd ignition config file
ETCD_IGNITION_CONFIG_PATH = "etcd_config.ign"
File.write(ETCD_IGNITION_CONFIG_PATH,`./generate_etcd_ignition_config.sh vagrant-virtualbox #{$etcd_cluster_size}` )
CONTROLLER_IGNITION_CONFIG_PATH = "controller/controller_config.ign"
WORKER_IGNITION_CONFIG_PATH = "worker/worker_config.ign"

Vagrant.configure("2") do |config|
  # always use Vagrants insecure key
  config.ssh.insert_key = false
  # forward ssh agent to easily ssh into the different machines
  config.ssh.forward_agent = true

  config.vm.box = "coreos-alpha"
  config.vm.box_url = "https://alpha.release.core-os.net/amd64-usr/current/coreos_production_vagrant_virtualbox.json"

  ["vmware_fusion", "vmware_workstation"].each do |vmware|
    config.vm.provider vmware do |v, override|
      override.vm.box_url = "https://alpha.release.core-os.net/amd64-usr/current/coreos_production_vagrant_vmware_fusion.json"
    end
  end

  config.vm.provider :virtualbox do |v|
    # On VirtualBox, we don't have guest additions or a functional vboxsf
    # in CoreOS, so tell Vagrant that so it can be smarter.
    v.check_guest_additions = false
    v.functional_vboxsf     = false
    # enable ignition (this is always done on virtualbox as this is how the ssh key is added to the system)
    config.ignition.enabled = true
  end

  # plugin conflict
  if Vagrant.has_plugin?("vagrant-vbguest") then
    config.vbguest.auto_update = false
  end

  (1..$etcd_cluster_size).each do |i|
    config.vm.define vm_name = "%s-%02d" % [$etcd_instance_name_prefix, i] do |config|
      config.vm.hostname = vm_name

      if $enable_serial_logging
        logdir = File.join(File.dirname(__FILE__), "log")
        FileUtils.mkdir_p(logdir)

        serialFile = File.join(logdir, "%s-serial.txt" % vm_name)
        FileUtils.touch(serialFile)

        ["vmware_fusion", "vmware_workstation"].each do |vmware|
          config.vm.provider vmware do |v, override|
            v.vmx["serial0.present"] = "TRUE"
            v.vmx["serial0.fileType"] = "file"
            v.vmx["serial0.fileName"] = serialFile
            v.vmx["serial0.tryNoRxLoss"] = "FALSE"
          end
        end

        config.vm.provider :virtualbox do |vb, override|
          vb.customize ["modifyvm", :id, "--uart1", "0x3F8", "4"]
          vb.customize ["modifyvm", :id, "--uartmode1", serialFile]
        end
      end

      if $expose_docker_tcp
        config.vm.network "forwarded_port", guest: 2375, host: ($expose_docker_tcp + i - 1), host_ip: "127.0.0.1", auto_correct: true
      end

      $forwarded_ports.each do |guest, host|
        config.vm.network "forwarded_port", guest: guest, host: host, auto_correct: true
      end

      ["vmware_fusion", "vmware_workstation"].each do |vmware|
        config.vm.provider vmware do |v|
          v.gui = vm_gui
          v.vmx['memsize'] = vm_memory
          v.vmx['numvcpus'] = vm_cpus
        end
      end

      config.vm.provider :virtualbox do |vb|
        vb.gui = vm_gui
        vb.memory = vm_memory
        vb.cpus = vm_cpus
        vb.customize ["modifyvm", :id, "--cpuexecutioncap", "#{$vb_cpuexecutioncap}"]
        config.ignition.config_obj = vb
      end

      ip = "172.17.8.#{i+100}"
      config.vm.network :private_network, ip: ip
      # This tells Ignition what the IP for eth1 (the host-only adapter) should be
      config.ignition.ip = ip

      # Uncomment below to enable NFS for sharing the host machine into the coreos-vagrant VM.
      #config.vm.synced_folder ".", "/home/core/share", id: "core", :nfs => true, :mount_options => ['nolock,vers=3,udp']
      $shared_folders.each_with_index do |(host_folder, guest_folder), index|
        config.vm.synced_folder host_folder.to_s, guest_folder.to_s, id: "core-share%02d" % index, nfs: true, mount_options: ['nolock,vers=3,udp']
      end

      if $share_home
        config.vm.synced_folder ENV['HOME'], ENV['HOME'], id: "home", :nfs => true, :mount_options => ['nolock,vers=3,udp']
      end

      # This shouldn't be used for the virtualbox provider (it doesn't have any effect if it is though)
      if File.exist?(CLOUD_CONFIG_PATH)
        config.vm.provision :file, :source => "#{CLOUD_CONFIG_PATH}", :destination => "/tmp/vagrantfile-user-data"
        config.vm.provision :shell, inline: "mkdir /var/lib/coreos-vagrant", :privileged => true
        config.vm.provision :shell, :inline => "mv /tmp/vagrantfile-user-data /var/lib/coreos-vagrant/", :privileged => true
      end

      config.vm.provider :virtualbox do |vb|
        config.ignition.hostname = vm_name
        config.ignition.drive_name = "config" + i.to_s
        # when the ignition config doesn't exist, the plugin automatically generates a very basic Ignition with the ssh key
        # and previously specified options (ip and hostname). Otherwise, it appends those to the provided config.ign below
        if File.exist?(ETCD_IGNITION_CONFIG_PATH)
          config.ignition.path = ETCD_IGNITION_CONFIG_PATH
        end
      end
    end
  end #of etcd cluster

  (1..controller_cluster_size).each do |controller_i|
    config.vm.define vm_name = "%s-%02d" % [controller_instance_name_prefix, controller_i] do |controller|
      controller.vm.hostname = vm_name

      controller.vm.provider :virtualbox do |vb|
        vb.gui = vm_gui
        vb.memory = controller_vm_memory
        vb.cpus = controller_vm_cpus
        vb.customize ["modifyvm", :id, "--cpuexecutioncap", "#{$vb_cpuexecutioncap}"]
        controller.ignition.config_obj = vb
      end


      controller_IP = controllerIP(controller_i)
      controller.vm.network :private_network, ip: controller_IP

      #ignition stuff
      controller.ignition.enabled = true
      controller.ignition.ip = controller_IP
      controller.ignition.hostname = vm_name
      controller.ignition.drive_name = "controller_config" + controller_i.to_s # TODO: validate there is no convention on 'config'
      

      # Each controller gets the same cert
      provisionMachineSSL(config,"apiserver","kube-apiserver-#{controller_IP}",controller_ips << K8S_SERVICE_IP)
      # TODO: test removal
      env_file = Tempfile.new('env_file', :binmode => true)
      env_file.write("ETCD_ENDPOINTS=#{etcd_endpoints.join(',')}\nADVERTISE_IP=#{controller_IP}\n")
      env_file.close
      controller.vm.provision :file, :source => env_file, :destination => "/tmp/coreos-kube-options.env"
      controller.vm.provision :shell, :inline => "mkdir -p /run/coreos-kubernetes && mv /tmp/coreos-kube-options.env /run/coreos-kubernetes/options.env", :privileged => true

      # system("mkdir trash && curl -o trash/controller-install.sh https://raw.githubusercontent.com/coreos/coreos-kubernetes/master/multi-node/generic/controller-install.sh")
      # controller.vm.provision :file, :source => "trash/controller-install.sh", :destination => "/tmp/vagrantfile-user-data"
      # controller.vm.provision :shell, :inline => "mkdir -p /var/lib/coreos-vagrant && mv /tmp/vagrantfile-user-data /var/lib/coreos-vagrant/", :privileged => true

      #TODO: go ignition all the way. The above script is not automatically run on the vm...
      File.write('./controller/options.env', "ETCD_ENDPOINTS=#{etcd_endpoints.join(',')}\nADVERTISE_IP=#{controller_IP}\n")
      File.write(CONTROLLER_IGNITION_CONFIG_PATH, `./controller/build_master_cl_config.sh | ./ct --platform=vagrant-virtualbox --pretty`)
      controller.ignition.path = CONTROLLER_IGNITION_CONFIG_PATH

    end
  end # of master cluster

  (1..worker_cluster_size).each do |worker_i|
    config.vm.define vm_name = "w%d" % worker_i do |worker|
      worker.vm.hostname = vm_name

      worker.vm.provider :virtualbox do |vb|
        vb.gui = vm_gui
        vb.memory = worker_vm_memory
        vb.cpus = worker_vm_cpus
        vb.customize ["modifyvm", :id, "--cpuexecutioncap", "#{$vb_cpuexecutioncap}"]
        worker.ignition.config_obj = vb
      end

      worker_IP = workerIP(worker_i)
      worker.vm.network :private_network, ip: worker_IP

      #ignition stuff
      worker.ignition.enabled = true
      worker.ignition.ip = worker_IP
      worker.ignition.hostname = vm_name
      worker.ignition.drive_name = "worker_config" + worker_i.to_s

      provisionMachineSSL(worker,"worker","kube-worker-#{worker_IP}",[worker_IP])

      # TODO: test removal
      env_file = Tempfile.new('env_file', :binmode => true)
      env_file.write("ETCD_ENDPOINTS=#{etcd_endpoints.join(',')}\nMASTER_ENDPOINT=https://#{master_host}\nADVERTISE_IP=#{worker_IP}\n")#TODO(aaron): LB or DNS across control nodes
      env_file.close
      worker.vm.provision :file, :source => env_file, :destination => "/tmp/coreos-kube-options.env"
      worker.vm.provision :shell, :inline => "mkdir -p /run/coreos-kubernetes && mv /tmp/coreos-kube-options.env /run/coreos-kubernetes/options.env", :privileged => true

      # worker.vm.provision :file, :source => WORKER_CLOUD_CONFIG_PATH, :destination => "/tmp/vagrantfile-user-data"
      # worker.vm.provision :shell, :inline => "mv /tmp/vagrantfile-user-data /var/lib/coreos-vagrant/", :privileged => true

      #ignition config
      File.write('./worker/options.env', "ETCD_ENDPOINTS=#{etcd_endpoints.join(',')}\nMASTER_ENDPOINT=https://#{master_host}\nADVERTISE_IP=#{worker_IP}\n")
      #TODO: Create worker_cl_config.template and build_worker_cl_config.sh
      config_path = "#{WORKER_IGNITION_CONFIG_PATH}-#{worker_i}"
      File.write(config_path, `./worker/build_worker_cl_config.sh | ./ct --platform=vagrant-virtualbox --pretty`)
      worker.ignition.path = config_path

    end
  end #of worker cluster

end
