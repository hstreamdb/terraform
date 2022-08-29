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
}

resource "alicloud_key_pair_attachment" "attachment_storage" {
  key_pair_name = var.key_pair_name
  instance_ids  = alicloud_instance.storage_instance.*.id
  force         = true
}

resource "alicloud_key_pair_attachment" "attachment_calculate" {
  key_pair_name = var.key_pair_name
  instance_ids  = alicloud_instance.calculate_instance.*.id
  force         = true
}

# ------------ step ------------

# ----------- generate config file -------------------
resource "local_file" "config" {
  depends_on = [alicloud_instance.storage_instance, alicloud_instance.calculate_instance, alicloud_key_pair_attachment.attachment_storage, alicloud_key_pair_attachment.attachment_calculate]
  filename   = "../file/config.json"
  content = templatefile("../file/clusterCfg.json.tftpl", {
    server_hosts = jsonencode(
      merge(
        { for idx, s in alicloud_instance.storage_instance.* : "hs-s${idx + 1}" => [s.public_ip, s.private_ip] },
        { for idx, s in alicloud_instance.calculate_instance.* : "hs-c${idx + 1}" => [s.public_ip, s.private_ip] }
  )) })
}

resource "null_resource" "echo_config" {
  depends_on = [local_file.config]

  provisioner "local-exec" {
    command = "cat ${local_file.config.filename}"
  }
}

# ---------- start server & client ---------------------

resource "null_resource" "start-server" {
  depends_on = [local_file.config]
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
  depends_on = [local_file.config]
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

# -------------- dump net topology -----------------------

resource "null_resource" "dump_topology" {
  depends_on = [
    alicloud_instance.storage_instance,
    alicloud_instance.calculate_instance
  ]

  provisioner "local-exec" {
    command = "terraform output -json > ../file/topology"
  }
}