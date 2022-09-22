terraform {
  required_version = ">=1.1.9"
  required_providers {
    alicloud = {
      source  = "hashicorp/alicloud"
      version = "1.178.0"
    }
  }
}

provider "alicloud" {
  region = var.region
  # setting `access_key` and `secret_key` via environment
  # variables `ALICLOUD_ACCESS_KEY` and `ALICLOUD_SECRET_KEY`
}

module "ali_vpc" {
  source         = "./modules/vpc"
  vpc_cidr_block = var.vpc_cidr_block
  vpc_name       = "hstream"
  vpc_zone       = var.zone
  vsw_cidr_block = var.vsw_cidr_block
}

module "ali_sec_group" {
  source                   = "./modules/security_group"
  vpc_id                   = module.ali_vpc.vpc_id
  ingress_with_cidr_blocks = var.ingress_with_cidr_blocks
  egress_with_cidr_blocks  = var.egress_with_cidr_blocks
}

resource "alicloud_instance" "storage_instance" {
  count             = var.storage_instance_config.node_count
  availability_zone = var.zone
  security_groups   = [module.ali_sec_group.sec_group_id]

  instance_type              = var.storage_instance_config.instance_type
  system_disk_category       = var.storage_instance_config.system_disk_category
  system_disk_size           = var.storage_instance_config.system_disk_size
  image_id                   = var.image_id
  instance_name              = "hserver-${count.index}"
  vswitch_id                 = module.ali_vpc.vsw_id
  internet_max_bandwidth_out = var.internet_max_bandwidth_out
  internet_charge_type       = var.internet_charge_type
  key_name                   = var.key_pair_name
  user_data                  = <<-EOF
    #!/bin/bash
    echo "==== mount disks ===="
    sudo mkdir /data
    sudo mkdir /mnt/data{0,1}
    sudo mkfs -t ext4 /dev/vdb
    sudo mount /dev/vdb /mnt/data0
  EOF
}

resource "alicloud_instance" "calculate_instance" {
  count             = var.calculate_instance_config.node_count
  availability_zone = var.zone
  security_groups   = [module.ali_sec_group.sec_group_id]

  instance_type              = var.calculate_instance_config.instance_type
  system_disk_category       = var.calculate_instance_config.system_disk_category
  system_disk_size           = var.calculate_instance_config.system_disk_size
  image_id                   = var.image_id
  instance_name              = "hclient-${count.index}"
  vswitch_id                 = module.ali_vpc.vsw_id
  internet_max_bandwidth_out = var.internet_max_bandwidth_out
  internet_charge_type       = var.internet_charge_type
  key_name                   = var.key_pair_name

  connection {
    type        = "ssh"
    user        = "root"
    private_key = file(var.private_key_path)
    host        = self.public_ip
  }

  provisioner "file" {
    source      = var.private_key_path
    destination = "/root/.ssh/id_rsa"
  }

  provisioner "remote-exec" {
    inline = [
      "cp ~/.ssh/authorized_keys ~/.ssh/id_rsa.pub",
      "chmod 600 ~/.ssh/id_rsa",
      "chmod 600 ~/.ssh/id_rsa.pub",
    ]
  }
}

# ------------ step ------------
# ---------- start server & client ---------------------

resource "null_resource" "start-server" {
  depends_on = [alicloud_instance.storage_instance]
  count      = var.storage_instance_config.node_count

  connection {
    user        = "root"
    private_key = file(var.private_key_path)
    host        = alicloud_instance.storage_instance[count.index].public_ip
  }

  provisioner "remote-exec" {
    script = "./script/store-node-start.sh"
  }
}

resource "null_resource" "start-client" {
  depends_on = [alicloud_instance.calculate_instance]
  count      = var.calculate_instance_config.node_count

  connection {
    user        = "root"
    private_key = file(var.private_key_path)
    host        = alicloud_instance.calculate_instance[count.index].public_ip
  }

  provisioner "remote-exec" {
    script = "./script/cal-node-start.sh"
  }
}

# -------------- dump node_info -----------------------

resource "null_resource" "dump_topology" {
  depends_on = [
    null_resource.start-server,
    null_resource.start-client
  ]

  provisioner "local-exec" {
    command = "terraform output -json > ../node_info"
  }
}