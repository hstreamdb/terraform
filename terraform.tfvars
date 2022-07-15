# ==== general config ====

region                      = "cn-shenzhen" # https://www.alibabacloud.com/help/en/basics-for-beginners/latest/regions-and-zones
zone                        = "cn-shenzhen-d"
image_id                    = "ubuntu_20_04_x64_20G_alibase_20220428.vhd"
delete_block_on_termination = true

# ==== vpc ====
cidr_block       = "172.31.0.0/16"
private_key_path = "~/.ssh/hstreamdb.pem"
key_pair_name    = "hstreamdb"

# ==== store node config ====

store_config = {
  node_count = 1
  /* instance_type = "t2.micro" */
  instance_type = "ecs.t6-c1m1.large"
  volume_size   = 50
  volume_type   = "gp3"
  iops          = 3000
  throughput    = 125
}

# ==== compute node config ====

cal_config = {
  node_count = 0
  /* instance_type = "t2.micro" */
  instance_type = "ecs.t6-c1m1.large"
  volume_size   = 50
  volume_type   = "gp3"
  iops          = 3000
  throughput    = 125
}
