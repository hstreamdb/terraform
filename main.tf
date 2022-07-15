terraform {
  required_providers {
    alicloud = {
      source  = "aliyun/alicloud"
      version = "~> 1.167.0"
    }
  }
}

# --------------------------------------------------------------------------------

provider "alicloud" {
  secret_key = var.secret_key
  access_key = var.access_key
  region     = var.region
}

# --------------------------------------------------------------------------------

resource "alicloud_vpc" "vpc" {
  cidr_block = "172.16.0.0/12"
}

resource "alicloud_vswitch" "vsw" {
  vpc_id            = alicloud_vpc.vpc.id
  cidr_block        = "172.16.0.0/21"
  availability_zone = var.zone
}


resource "alicloud_route_table" "route" {
  vpc_id = alicloud_vpc.vpc.id
}

resource "alicloud_route_table_attachment" "attachment" {
  vswitch_id     = alicloud_vswitch.vsw.id
  route_table_id = alicloud_route_table.route.id
}

resource "alicloud_security_group" "hstream" {


  vpc_id = alicloud_vpc.vpc.id
  tags = {
    Name = "hstream-cluster"
  }
}

# --------------------------------------------------------------------------------

resource "null_resource" "before_sleep" {
  depends_on = [
    alicloud_vswitch.vsw
  ]
}

resource "time_sleep" "wait_60_seconds" {
  depends_on = [null_resource.before_sleep]

  create_duration = "60s"
}

resource "null_resource" "after_sleep" {
  depends_on = [
    time_sleep.wait_60_seconds
  ]
}

resource "alicloud_instance" "server" {
  count = var.store_config.node_count
  depends_on = [
    null_resource.after_sleep
  ]

  availability_zone = var.zone
  vswitch_id        = alicloud_vswitch.vsw.id
  image_id          = var.image_id
  instance_type     = var.store_config.instance_type
  security_groups   = [alicloud_security_group.hstream.id]
  # user_data         = <<-EOF
  #   #!/bin/bash
  #   echo "==== mount disks ===="
  #   sudo mkdir /data
  #   sudo mkdir /mnt/data{0,1}
  #   sudo mkfs -t ext4 /dev/nvme1n1
  #   sudo mkfs -t ext4 /dev/nvme2n1
  #   sudo mount /dev/nvme1n1 /mnt/data0
  #   sudo mount /dev/nvme2n1 /mnt/data1
  #   sudo chown -R ubuntu /data
  #   sudo chown -R ubuntu /mnt
  # EOF



  tags = {
    Name = "hserver-${count.index}"
  }
}

resource "alicloud_instance" "client" {
  count = var.cal_config.node_count
  depends_on = [
    null_resource.after_sleep
  ]

  availability_zone = var.zone
  vswitch_id        = alicloud_vswitch.vsw.id
  image_id          = var.image_id
  instance_type     = var.cal_config.instance_type
  security_groups   = [alicloud_security_group.hstream.id]

  tags = {
    Name = "hclient-${count.index}"
  }
}

# ------------ step ------------

# ----------- generate config file -------------------
resource "local_file" "config" {
  depends_on = [alicloud_instance.server, alicloud_instance.client]
  filename   = "./file/config.json"
  content = templatefile("./file/clusterCfg.json.tftpl", {
    server_hosts = jsonencode(
      merge(
        { for idx, s in alicloud_instance.server.* : "hs-s${idx + 1}" => [s.public_ip, s.private_ip] },
        { for idx, s in alicloud_instance.client.* : "hs-c${idx + 1}" => [s.public_ip, s.private_ip] }
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
  count      = var.store_config.node_count

  connection {
    user        = "ubuntu"
    private_key = file(var.private_key_path)
    host        = alicloud_instance.server[count.index].public_ip
  }

  provisioner "remote-exec" {
    script = "./file/server-node-start.sh"
  }
}

resource "null_resource" "start-client" {
  depends_on = [local_file.config]
  count      = var.cal_config.node_count

  connection {
    user        = "ubuntu"
    private_key = file(var.private_key_path)
    host        = alicloud_instance.client[count.index].public_ip
  }

  provisioner "remote-exec" {
    script = "./file/client-node-start.sh"
  }
}

# -------------- dump net topology -----------------------

resource "null_resource" "dump_topology" {
  depends_on = [
    alicloud_instance.server,
    alicloud_instance.client
  ]

  provisioner "local-exec" {
    command = "terraform output -json > ./file/topology"
  }
}

/* # -------------------------------------------------------------------------------- */

output "server_public_ip" {
  value = alicloud_instance.server[*].public_ip
}

output "server_access_ip" {
  value = alicloud_instance.server[*].private_ip
}

output "client_public_ip" {
  value = alicloud_instance.client[*].public_ip
}

output "client_access_ip" {
  value = alicloud_instance.client[*].private_ip
}

