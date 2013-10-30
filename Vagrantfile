Vagrant.configure("2") do |config|

  config.vm.box = "precise32"

  config.vm.define "ffmpeg" do |subcfg|
    subcfg.vm.provision "shell",
        inline: "cd /vagrant; LIBRARY=ffmpeg scripts/test-setup"
  end

  config.vm.define "libav" do |subcfg|
    subcfg.vm.provision "shell",
        inline: "cd /vagrant; LIBRARY=libav scripts/test-setup"
  end
end
