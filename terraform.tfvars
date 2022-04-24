# See https://developer.huaweicloud.com/en-us/endpoint

# ==== general config ====

# https://support.huaweicloud.com/intl/en-us/api-eip/eip_api_0003.html
region_name         = "cn-southwest-2"
region_network_type = "5_sbgp"
image_name    = "Ubuntu 20.04 server 64bit"
/* image_name    = "CentOS 7.9 64bit" */
key_pair_name = "hsteam-bench-gy1"
network_uuid = "66024606-3349-4b36-90d9-f0e6543f1cec"
/* network_uuid = "cd56a7ed-a37a-46f9-ae0d-b8e4e4a536d5" */
security_group_ids = "c43f1f87-b650-4e2e-8479-e4a1b8c672d9"
private_key_path = "~/.ssh/hsteam-bench-gy1.pem"

# ==== server config ====

server_config = {
    node_count = 3
    /* flavor_name   = "ir3.2xlarge.4" */
    /* flavor_name   = "ir3.4xlarge.4" */
    flavor_name   = "s6.xlarge.2"
    /* flavor_name   = "s6.small.1" */
    # See https://support.huaweicloud.com/intl/en-us/productdesc-evs/en-us_topic_0014580744.html
    data_disk_type = null
    data_disk_size = null
    system_disk_type = null
    system_disk_size = null
}

# ==== server config ====

client_config = {
    node_count = 1
    /* sever_flavor_name   = "ir3.2xlarge.4" */
    /* flavor_name   = "c6s.2xlarge.2" */
    /* flavor_name   = "c6s.8xlarge.2" */
    /* flavor_name   = "s6.small.1" */
    flavor_name   = "s6.xlarge.2"
    # See https://support.huaweicloud.com/intl/en-us/productdesc-evs/en-us_topic_0014580744.html
    data_disk_type = null
    data_disk_size = null
    system_disk_type = null
    system_disk_size = null
}

bandwidth_size        = 100
bandwidth_share_type  = "PER"
bandwidth_charge_mode = "traffic"
