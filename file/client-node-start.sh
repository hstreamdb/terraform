#!/bin/bash

echo "start client $1"

sudo apt-get update
sudo apt-get -y install apt-transport-https ca-certificates curl gnupg lsb-release sysstat glances zip openjdk-11-jre-headless
curl -s "https://get.sdkman.io" | bash && source "$HOME/.sdkman/bin/sdkman-init.sh"
sdk install gradle

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
# sudo add-apt-repository \
#    "deb [arch=amd64] https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/ubuntu \
#    $(lsb_release -cs) \
#    stable"

# curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
# 
# echo \
#   "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://mirrors.ustc.edu.cn/docker-ce/linux/ubuntu focal stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "==== install docker now ===="
sudo apt-get update
sudo apt-get -y install docker-ce docker-ce-cli containerd.io

cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  }
}
EOF

sudo groupadd docker
sudo gpasswd -a ${USER} docker
sudo systemctl restart docker
sudo chmod a+rw /var/run/docker.sock

echo "==== mount disks ===="
sudo mkdir /data
sudo chown ubuntu /data
# sudo mkfs -t ext4 /dev/vdb
# sudo mount /dev/vdb /data

echo "==== pull images ===="
docker pull hstreamdb/hstream 
docker pull gcr.io/cadvisor/cadvisor:v0.39.3
docker pull prom/node-exporter
docker pull prom/prometheus
