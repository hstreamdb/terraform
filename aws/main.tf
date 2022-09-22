terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  required_version = ">= 0.14.9"
}

# --------------------------------------------------------------------------------

provider "aws" {
  /* profile = "default" */
  region = var.region
  # setting `access_key` and `secret_key` via environment
  # variables `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`
}

# --------------------------------------------------------------------------------

module "aws_vpc" {
  source            = "./modules/vpc"
  vpc_name          = var.vpc_name
  vpc_cidr_block    = var.vpc_cidr_block
  subnet_cidr_block = var.subnet_cidr_block
  zone              = var.zone
}

module "aws_sec_group" {
  source        = "./modules/security_group"
  vpc_id        = module.aws_vpc.vpc_id
  sg_name       = "hstream"
  ingress_rules = var.ingress_rules
  egress_rules  = var.egress_rules
}

# --------------------------------------------------------------------------------

resource "aws_instance" "storage_instance" {
  count                       = var.store_config.node_count
  ami                         = var.image_id
  instance_type               = var.store_config.instance_type
  key_name                    = var.key_pair_name
  vpc_security_group_ids      = [module.aws_sec_group.sec_group_id]
  subnet_id                   = module.aws_vpc.subnet_id
  associate_public_ip_address = true
  user_data                   = <<-EOF
    #!/bin/bash
    echo "==== mount disks ===="
    sudo mkdir /data
    sudo mkdir /mnt/data{0,1}
    sudo mkfs -t ext4 /dev/nvme1n1
    sudo mkfs -t ext4 /dev/nvme2n1
    sudo mount /dev/nvme1n1 /mnt/data0
    sudo mount /dev/nvme2n1 /mnt/data1
    sudo chown -R ubuntu /data
    sudo chown -R ubuntu /mnt
  EOF

  root_block_device {
    volume_size           = var.store_config.volume_size
    delete_on_termination = var.delete_block_on_termination
    volume_type           = var.store_config.volume_type
    iops                  = var.store_config.iops
    throughput            = var.store_config.throughput
  }

  tags = {
    Name = "hserver-${count.index}"
  }
}

resource "aws_instance" "calculate_instance" {
  count                       = var.cal_config.node_count
  ami                         = var.image_id
  instance_type               = var.cal_config.instance_type
  key_name                    = var.key_pair_name
  vpc_security_group_ids      = [module.aws_sec_group.sec_group_id]
  subnet_id                   = module.aws_vpc.subnet_id
  associate_public_ip_address = true

  root_block_device {
    volume_size           = var.cal_config.volume_size
    delete_on_termination = var.delete_block_on_termination
    volume_type           = var.cal_config.volume_type
    iops                  = var.cal_config.iops
    throughput            = var.cal_config.throughput
  }

  tags = {
    Name = "hclient-${count.index}"
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file(var.private_key_path)
    host        = self.public_ip
  }

  provisioner "file" {
    source      = var.private_key_path
    destination = "/home/ubuntu/.ssh/id_rsa"
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
  depends_on = [aws_instance.storage_instance]
  count      = var.store_config.node_count

  connection {
    user        = "ubuntu"
    private_key = file(var.private_key_path)
    host        = aws_instance.storage_instance[count.index].public_ip
  }

  provisioner "remote-exec" {
    script = "./script/store-node-start.sh"
  }
}

resource "null_resource" "start-client" {
  depends_on = [aws_instance.calculate_instance]
  count      = var.cal_config.node_count

  connection {
    user        = "ubuntu"
    private_key = file(var.private_key_path)
    host        = aws_instance.calculate_instance[count.index].public_ip
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

