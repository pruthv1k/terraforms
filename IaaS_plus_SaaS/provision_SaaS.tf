#To provision SaaS with IaC using Terraform

provider "aws" {
  region     = "Enter Value"
  access_key = "Enter Value"
  secret_key = "Enter Value"
}

resource "aws_eip" "ipaddr" {
  vpc = "true"
}

resource "aws_instance" "ectwo" {
  ami           = "Enter Value"
  instance_type = "Enter Value"
  key_name = "pruthvi-terraform"
}

resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.ectwo.id
  allocation_id = aws_eip.ipaddr.id

  provisioner "remote-exec" {
    inline = [
      "sudo amazon-linux-extras enable nginx1.12",
      "sudo amazon-linux-extras install -y nginx1.12",
      "sudo systemctl start nginx"
    ]
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("Enter Path/pruthvi-terraform.pem")
      host        = self.public_ip
    }
  }
}
