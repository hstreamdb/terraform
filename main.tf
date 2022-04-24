terraform {
  required_providers {
    huaweicloud = {
      source  = "huaweicloud/huaweicloud"
      version = "~> 1.35.1"
    }
  }
}

variable "bandwidth_size" {}
variable "bandwidth_share_type" {}
variable "bandwidth_charge_mode" {}

# --------------------------------------------------------------------------------

provider "huaweicloud" {
  region = var.region_name
  # setting `access_key` and `secret_key` via environment
  # variables `HW_ACCESS_KEY` and `HW_SECRET_KEY`
}

# --------------------------------------------------------------------------------

data "huaweicloud_vpc_subnet" "mynet" {
  name = "subnet-default"
}

resource "huaweicloud_compute_instance" "server" {
  count       = var.server_config.node_count

  name        = "hserver-${count.index}"
  image_name  = var.image_name
  flavor_name = var.server_config.flavor_name
  key_pair    = var.key_pair_name
  security_group_ids = [var.security_group_ids]

  network {
    access_network = true
    /* uuid           = var.network_uuid */
    uuid           = data.huaweicloud_vpc_subnet.mynet.id
  }

  system_disk_type = var.server_config.system_disk_type
  system_disk_size = var.server_config.system_disk_size
}

resource "huaweicloud_compute_instance" "client" {
  count       = var.client_config.node_count

  name        = "hclient-${count.index}"
  image_name  = var.image_name
  flavor_name = var.client_config.flavor_name
  key_pair    = var.key_pair_name
  security_group_ids = [var.security_group_ids]

  network {
    access_network = true
    /* uuid           = var.network_uuid */
    uuid           = data.huaweicloud_vpc_subnet.mynet.id
  }

  system_disk_type = var.client_config.system_disk_type
  system_disk_size = var.client_config.system_disk_size
}

# ------------ step ------------

# --------- check if server & client ready to handle ssh request -------------
resource "null_resource" "server_probe" {
  depends_on = [huaweicloud_compute_eip_associate.server_associated]
  count = var.server_config.node_count
  
  connection {
    user = "root"
    private_key = file(var.private_key_path)
    host = huaweicloud_vpc_eip.server_eip[count.index].address
  }

  provisioner "remote-exec" {
    inline = ["echo hello server"]
  }
}

resource "null_resource" "client_probe" {
  depends_on = [huaweicloud_compute_eip_associate.client_associated]
  count = var.client_config.node_count
  
  connection {
    user = "root"
    private_key = file(var.private_key_path)
    host = huaweicloud_vpc_eip.client_eip[count.index].address
  }

  provisioner "remote-exec" {
    inline = ["echo hello client"]
  }
}

# ----------- generate config file -------------------
resource "local_file" "config" {
  depends_on = [null_resource.server_probe, null_resource.client_probe]
  filename = "./file/config.json"
  content = templatefile("./file/topology.json.tftpl", {
    server_hosts = jsonencode(
    merge(
      /* {for idx, s in huaweicloud_compute_instance.server: "hw-s${idx + 1}" => [s.public_ip, s.access_ip_v4]}, */ 
      /* {for idx, s in huaweicloud_compute_instance.client: "hw-c${idx + 1}" => [s.public_ip, s.access_ip_v4]} */
      {for idx, s in huaweicloud_compute_eip_associate.server_associated: "hw-s${idx + 1}" => [s.public_ip, s.fixed_ip]}, 
      {for idx, s in huaweicloud_compute_eip_associate.client_associated: "hw-c${idx + 1}" => [s.public_ip, s.fixed_ip]}
    ))})
}

resource "null_resource" "echo_config" {
    depends_on = [local_file.config]
    provisioner "local-exec" {
        command = "cat ${local_file.config.filename}"
    }
}

# ---------- start server & client ---------------------

resource "null_resource" "start-server" {
  /* depends_on = [huaweicloud_compute_eip_associate.server_associated] */
  depends_on = [local_file.config]
  count = var.server_config.node_count

  connection {
    user = "root"
    private_key = file(var.private_key_path)
    host = huaweicloud_vpc_eip.server_eip[count.index].address
  }

  provisioner "remote-exec" {
    script = "./file/server-start.sh"
  }
}

resource "null_resource" "start-client" {
  /* depends_on = [huaweicloud_compute_eip_associate.client_associated] */
  depends_on = [local_file.config]
  count = var.client_config.node_count

  connection {
    user = "root"
    private_key = file(var.private_key_path)
    host = huaweicloud_vpc_eip.client_eip[count.index].address
  }

  provisioner "remote-exec" {
    script = "./file/client-start.sh"
  }

 provisioner "file" {
     source = "~/Documents/work/bench/"
     destination = "/tmp"
 }
}

# -------------- bootstrap -----------------------

/* resource "null_resource" "bootstrap" { */
/*     depends_on = [ */
/*         null_resource.start-client, */
/*         null_resource.start-server */
/*     ] */

/*     provisioner "local-exec" { */
/*         command = "./file/dev-deploy --remote '' simple --config ${local_file.config.filename} --user 'root' --key ${var.private_key_path} start --disable-restart all" */
/*     } */
/* } */

resource "null_resource" "pre_bootstrap" {
    depends_on = [
        null_resource.start-client,
        null_resource.start-server
    ]

    provisioner "local-exec" {
        /* command = "./file/dev-deploy --remote '' simple --config ${local_file.config.filename} --user 'root' --key ${var.private_key_path} start --disable-restart all" */
        command = "cp ${local_file.config.filename} ./file/config"
    }
}


/* # -------------------------------------------------------------------------------- */
/* -------- eip --------- */

resource "huaweicloud_vpc_eip" "server_eip" {
  count = var.server_config.node_count

  publicip {
    type = var.region_network_type
  }

  bandwidth {
    name        = "server-network-${count.index}"
    size        = var.bandwidth_size
    share_type  = var.bandwidth_share_type
    charge_mode = var.bandwidth_charge_mode
  }
}

resource "huaweicloud_compute_eip_associate" "server_associated" {
  count = var.server_config.node_count

  public_ip   = huaweicloud_vpc_eip.server_eip[count.index].address
  instance_id = huaweicloud_compute_instance.server[count.index].id
}

resource "huaweicloud_vpc_eip" "client_eip" {
  count = var.client_config.node_count

  publicip {
    type = var.region_network_type
  }

  bandwidth {
    name        = "server-network-${count.index}"
    size        = var.bandwidth_size
    share_type  = var.bandwidth_share_type
    charge_mode = var.bandwidth_charge_mode
  }
}

resource "huaweicloud_compute_eip_associate" "client_associated" {
  count = var.client_config.node_count

  public_ip   = huaweicloud_vpc_eip.client_eip[count.index].address
  instance_id = huaweicloud_compute_instance.client[count.index].id
}

/* # -------------------------------------------------------------------------------- */

output "server_public_ip" {
  value = huaweicloud_compute_instance.server[*].public_ip
}

output "server_access_ip" {
  value = huaweicloud_compute_instance.server[*].access_ip_v4
}

output "client_public_ip" {
  value = huaweicloud_compute_instance.client[*].public_ip
}

output "client_access_ip" {
  value = huaweicloud_compute_instance.client[*].access_ip_v4
}

