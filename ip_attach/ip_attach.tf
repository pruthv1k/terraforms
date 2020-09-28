terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "3.8.0"
    }
  }
}

provider "aws" {
  region = "enter_region"
  access_key = "enter_access_key"
  secret_key = "enter_secret_key"
}

resource "aws_eip" "ip" {
  vpc = "true"
}

resource "aws_instance" "ec2" {
  ami = "enter_ami_id"
  instance_type = "enter_flavour"
}

resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.ec2.id      #argument reference + attribute reference
  allocation_id = aws_eip.ip.id            #argument reference + attribute reference
}
