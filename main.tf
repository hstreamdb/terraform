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
  region  = var.region
  # setting `access_key` and `secret_key` via environment
  # variables `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`
}

# --------------------------------------------------------------------------------

resource "aws_vpc" "vpc" {
    cidr_block = var.cidr_block
}

resource "aws_subnet" "net" {
    vpc_id     = aws_vpc.vpc.id
    cidr_block = var.cidr_block
}

resource "aws_internet_gateway" "gateway" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_route_table" "route" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gateway.id
  }
}

resource "aws_route_table_association" "main" {
  subnet_id      = aws_subnet.net.id
  route_table_id = aws_route_table.route.id
}

resource "aws_security_group" "hstream" {
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }
  ingress {
      from_port   = 7070
      to_port     = 7070
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
      from_port   = 7000
      to_port     = 7000
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
      from_port   = 9100
      to_port     = 9100
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
      from_port   = 9090
      to_port     = 9090
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = aws_vpc.vpc.id
  tags = {
      Name = "hstream-cluster"
  }
}

# --------------------------------------------------------------------------------

resource "aws_instance" "server" {
  count                       = var.store_config.node_count
  ami                         = var.image_id
  instance_type               = var.store_config.instance_type
  key_name                    = var.key_pair_name
  vpc_security_group_ids      = [aws_security_group.hstream.id]
  subnet_id                   = aws_subnet.net.id
  associate_public_ip_address = true

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

resource "aws_instance" "client" {
  count                       = var.cal_config.node_count
  ami                         = var.image_id
  instance_type               = var.cal_config.instance_type
  key_name                    = var.key_pair_name
  vpc_security_group_ids      = [aws_security_group.hstream.id]
  subnet_id                   = aws_subnet.net.id
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
}

# ------------ step ------------

# ----------- generate config file -------------------
resource "local_file" "config" {
  depends_on = [aws_instance.server, aws_instance.client]
  filename   = "./file/config.json"
  content    = templatefile("./file/clusterCfg.json.tftpl", {
    server_hosts = jsonencode(
    merge(
      {for idx, s in aws_instance.server.*: "hs-s${idx + 1}" => [s.public_ip, s.private_ip]}, 
      {for idx, s in aws_instance.client.*: "hs-c${idx + 1}" => [s.public_ip, s.private_ip]}
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
  depends_on = [local_file.config]
  count      = var.store_config.node_count

  connection {
    user        = "ubuntu"
    private_key = file(var.private_key_path)
    host        = aws_instance.server[count.index].public_ip
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
    host        = aws_instance.client[count.index].public_ip
  }

  provisioner "remote-exec" {
    script = "./file/client-node-start.sh"
  }

 provisioner "file" {
     source      = "~/Documents/work/bench/"
     destination = "/tmp"
 }
}

# -------------- dump net topology -----------------------

resource "null_resource" "dump_topology" {
    depends_on = [
        aws_instance.server,
        aws_instance.client
    ]

    provisioner "local-exec" {
        command = "terraform output -json > ./file/output"
    }
}

/* # -------------------------------------------------------------------------------- */

output "server_public_ip" {
  value = aws_instance.server[*].public_ip
}

output "server_access_ip" {
  value = aws_instance.server[*].private_ip
}

output "client_public_ip" {
  value = aws_instance.client[*].public_ip
}

output "client_access_ip" {
  value = aws_instance.client[*].private_ip
}

