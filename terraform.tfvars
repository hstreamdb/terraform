# ==== general config ====

region   = "us-east-2"
image_id = "ami-0fb653ca2d3203ac1" # ubuntu 20.04
delete_block_on_termination = true

# ==== vpc ====
cidr_block       = "172.31.0.0/16"
private_key_path = "~/.ssh/hstreamdb.pem"
key_pair_name    = "hstreamdb"

# ==== store node config ====

store_config = {
    node_count    = 3
    /* instance_type = "t2.micro" */
    instance_type = "i3en.2xlarge"
    volume_size   = 50
    volume_type   = "gp3"
    iops          = 3000
    throughput    = 125
}

# ==== compute node config ====

cal_config = {
    node_count    = 1
    /* instance_type = "t2.micro" */
    instance_type = "c5.4xlarge"
    volume_size   = 50
    volume_type   = "gp3"
    iops          = 3000
    throughput    = 125
}
