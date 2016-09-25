config_proxy_fqdn   = 'proxy.example.com'
config_proxy_ip     = '10.10.10.222'
config_ubuntu_fqdn  = 'ubuntu.example.com'
config_ubuntu_ip    = '10.10.10.223'
config_windows_fqdn = 'windows.example.com'
config_windows_ip   = '10.10.10.224'

Vagrant.configure('2') do |config|
  config.vm.box = 'ubuntu-16.04-amd64'

  config.vm.provider :virtualbox do |vb|
    vb.linked_clone = true
    vb.memory = 2048
    vb.customize ['modifyvm', :id, '--cableconnected1', 'on']
  end

  config.vm.define :proxy do |config|
    config.vm.hostname = config_proxy_fqdn
    config.vm.network :private_network, ip: config_proxy_ip
    config.vm.provision :shell, path: 'provision.sh'
  end

  config.vm.define :ubuntu do |config|
    config.vm.hostname = config_ubuntu_fqdn
    config.vm.network :private_network, ip: config_ubuntu_ip
    config.vm.provision :shell, inline: "echo '#{config_proxy_ip} #{config_proxy_fqdn}' >>/etc/hosts"
    config.vm.provision :shell, path: 'provision-ubuntu.sh'
  end

  config.vm.define :windows do |config|
    config.vm.box = 'windows_2012_r2'
    config.vm.provider :virtualbox do |vb|
      vb.customize ['modifyvm', :id, '--vram', 64]
    end
    config.vm.network :private_network, ip: config_windows_ip
    config.vm.provision :shell, inline: "echo '#{config_proxy_ip} #{config_proxy_fqdn}' | Out-File -Encoding ASCII -Append c:/Windows/System32/drivers/etc/hosts"
    config.vm.provision :shell, path: 'provision-windows-proxy.ps1'
    config.vm.provision :shell, inline: "$env:chocolateyVersion='0.10.2'; iwr https://chocolatey.org/install.ps1 -UseBasicParsing | iex", name: "Install Chocolatey"
    config.vm.provision :shell, path: 'provision-windows.ps1'
  end
end
