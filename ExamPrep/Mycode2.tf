/*
provider "aws" {
  version = "~> 3.0"
  region  = "ap-south-1"
}
*/

/*
Terraform does not recommend using the version argument in provider configurations.
In Terraform 0.13 and later, version constraints should always be declared in the required_providers block.
*/

terraform {
  required_providers {
    aws    = "~> 3.0"
  }
}

provider "aws" {
  region  = var.region
  profile = "autoid"
}


variable "region" {
  default = "ap-south-1"
}

variable "user_names" {
  description = "Create IAM users"
  type        = list(string)
  default     = ["h1-a", "h2-u", "h3-d"]
}

variable "ami_key_pair_name" {
  default = "mumbai07312000"
}

variable "instance_name" {
  description = "The Name tag to set for the EC2 Instance."
  type        = string
  default     = "terra-random"
}

variable "ingress_rule" {
  type        = list(number)
  description = "Ingress ports"
  default     = [22, 8443, 8080, 80]
}

variable "egress_rule" {
  type        = list(number)
  description = "Egress ports"
  default     = [80, 443]
}
####################################################
resource "aws_iam_user" "user" {
  count = length(var.user_names)
  name  = var.user_names[count.index]
}

resource "aws_security_group" "websg" {
  name        = "websg"
  description = "allow web access"

  dynamic "ingress" {
    for_each = var.ingress_rule
    iterator = port
    content {
      from_port   = port.value
      to_port     = port.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  dynamic "egress" {
    for_each = var.egress_rule
    iterator = port
    content {
      from_port   = port.value
      to_port     = port.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
}

resource "aws_instance" "random_vm" {
  ami                         = data.aws_ami.rhel_latest.id
  instance_type               = "t2.micro"
  security_groups             = [aws_security_group.websg.name]
  key_name                    = var.ami_key_pair_name
  associate_public_ip_address = true
  source_dest_check           = false

  tags = {
    Name = "${var.instance_name}-public"
  }

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("/root/.ssh/pemfile/mumbai07312000.pem")
    host        = self.public_ip
  }

  provisioner "file" {
    content     = "ami used: ${self.ami}"
    destination = "/tmp/imageid"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum -y install nginx",
      "sudo systemctl start nginx",
      "sudo setenforce permissive",
      "sudo mv /tmp/imageid /etc/imageid",
    ]
  }
}
############################################################

data "aws_ami" "rhel_latest" {
  owners      = ["309956199498"]
  most_recent = true

  filter {
    name   = "name"
    values = ["RHEL-8.*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}
############################################################

output "vm_name" {
  value = aws_instance.random_vm.public_ip
}

output "users" {
  value = ["${aws_iam_user.user.*.arn}"]
}
