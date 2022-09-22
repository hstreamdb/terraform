#!/bin/bash

echo "start server $1"

sudo apt-get update
sudo apt-get -y install apt-transport-https ca-certificates curl gnupg lsb-release sysstat glances dstat

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "==== install docker now ===="
sudo apt-get update
sudo apt-get -y install docker-ce docker-ce-cli containerd.io

cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "registry-mirrors": ["https://docker.mirrors.sjtug.sjtu.edu.cn"],
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

#echo "==== mount disks ===="
##sudo mkdir -p /data
##sudo mkdir -p /mnt/data{0,1}
##sudo mkfs -t ext4 /dev/vdb
##sudo mount /dev/vdb /mnt/data0
## # sudo mkdir /data/logdevice
## # echo 1 | sudo tee /data/logdevice/NSHARDS
## # sudo useradd logdevice
## # sudo chown -R logdevice /data/logdevice/

echo "==== pull images ===="
docker pull hstreamdb/hstream:latest
docker pull zookeeper:3.6
docker pull gcr.io/cadvisor/cadvisor:v0.39.3
#docker pull gcr.lank8s.cn/cadvisor/cadvisor:v0.39.3
docker pull prom/node-exporter
# docker pull prom/prometheus
