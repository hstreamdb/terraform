region = "cn-zhangjiakou"
zone   = "cn-zhangjiakou-c"
#region         = "cn-hangzhou"
#zone           = "cn-hangzhou-a"
vpc_cidr_block   = "172.10.0.0/16"
vsw_cidr_block   = "172.10.1.0/24"
key_pair_name    = "hstream-aliyun"
private_key_path = "~/.ssh/hstream-aliyun.pem"
image_id         = "ubuntu_20_04_x64_20G_alibase_20210623.vhd"

ecs_vswitch_conf = {
  name   = "hstream-vswitch"
  region = "cn-zhangjiakou"
  cidr   = "172.10.1.0/24"
}

ingress_with_cidr_blocks = [
  {
    description = "port-80"
    port_range  = "80/80"
    ip_protocol = "tcp"
    cidr_ip     = "0.0.0.0/0"
  },
  {
    description = "ssh"
    port_range  = "22/22"
    ip_protocol = "tcp"
    cidr_ip     = "0.0.0.0/0"
  },
  {
    description = "https"
    port_range  = "443/443"
    ip_protocol = "tcp"
    cidr_ip     = "0.0.0.0/0"
  },
  {
    description = "grafana"
    port_range  = "3000/3000"
    ip_protocol = "tcp"
    cidr_ip     = "0.0.0.0/0"
  },
  {
    description = "monitor"
    port_range  = "9090/9090"
    ip_protocol = "tcp"
    cidr_ip     = "0.0.0.0/0"
  },
  {
    description = "metrics"
    port_range  = "9100/9100"
    ip_protocol = "tcp"
    cidr_ip     = "0.0.0.0/0"
  },
  {
    description = "cadvisor"
    port_range  = "7000/7000"
    ip_protocol = "tcp"
    cidr_ip     = "0.0.0.0/0"
  },
  {
    description = "zk-monitor"
    port_range  = "7070/7070"
    ip_protocol = "tcp"
    cidr_ip     = "0.0.0.0/0"
  },
]

egress_with_cidr_blocks = [
  {
    description = "all"
    port_range  = "-1/-1"
    protocol    = "all"
    cidr_ip     = "0.0.0.0/0"
  }
]

internet_charge_type       = "PayByTraffic"
internet_max_bandwidth_out = 100

# ==== store node config ====

storage_instance_config = {
  node_count = 3
  #  instance_type        = "ecs.i2gne.2xlarge"
  instance_type        = "ecs.i2gne.4xlarge"
  system_disk_category = "cloud_efficiency"
  system_disk_size     = 50
}

calculate_instance_config = {
  node_count           = 1
  instance_type        = "ecs.g6.4xlarge"
  system_disk_category = "cloud_efficiency"
  system_disk_size     = 50
}