# ==== general config ====

region                      = "us-east-2"
zone                        = "us-east-2a"
image_id                    = "ami-0fb653ca2d3203ac1" # ubuntu 20.04
delete_block_on_termination = true

# ==== vpc ====
vpc_cidr_block    = "172.31.0.0/16"
vpc_name          = "hstream"
subnet_cidr_block = "172.31.0.0/16"
private_key_path  = "~/.ssh/hstreamdb.pem"
key_pair_name     = "hstreamdb"

// ==== Security Group ====

ingress_rules = [
  {
    description = "ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  },
  {
    description = "port-80"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  },
  {
    description = "https"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  },
  #  {
  #    description = "self"
  #    from_port   = 0
  #    to_port     = 0
  #    protocol    = "-1"
  #    self        = true
  #    cidr_blocks = ["0.0.0.0/0"]
  #  },
  {
    description = "zk-monitor"
    from_port   = 7070
    to_port     = 7070
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  },
  {
    description = "cadvisor"
    from_port   = 7000
    to_port     = 7000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  },
  {
    description = "metrics"
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  },
  {
    description = "monitor"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  },
  {
    description = "grafana"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
]

egress_rules = [
  {
    description = "all"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
]

# ==== store node config ====

store_config = {
  node_count = 3
  #  instance_type = "t2.micro"
  instance_type = "i3en.2xlarge"
  volume_size   = 50
  volume_type   = "gp3"
  iops          = 3000
  throughput    = 125
}

# ==== compute node config ====

cal_config = {
  node_count = 1
  #  instance_type = "t2.micro"
  instance_type = "c5.4xlarge"
  volume_size   = 50
  volume_type   = "gp3"
  iops          = 3000
  throughput    = 125
}
