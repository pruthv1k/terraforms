/* 
Terraform does not recommend using the version argument in provider configurations. 
In Terraform 0.13 and later, version constraints should always be declared in the required_providers block.
*/

terraform {
  required_version = "~> 0.12"
  required_providers {
    local    = "~> 1.4"
    aws      = "~> 3.0"
    random   = "~> 2.1"
    template = "~> 2.1"
  }
}
#################################

variable "region" {
  default = "ap-south-1"
}

variable "ami_key_pair_name" {
  default = "mumbai07312000"
}

provider "aws" {
  region  = var.region
  profile = "autoid"
}

################################

// Using aliases

provider "aws" {
    region = "us-west-2"
    alias = "west"
}
    resource "aws_instance" "alias-example" {
      ami                         = data.aws_ami.rhel_latest.id
      instance_type               = "t2.micro"
      key_name                    = var.ami_key_pair_name
      security_groups             = [aws_security_group.prod-web.name]
      associate_public_ip_address = true
      source_dest_check           = false
    # The generalized format for provider aliases is <PROVIDER_-NAME>.<ALIAS_NAME>
      provider = aws.west
}

# Random number generator
resource "random_integer" "rand" {
  min = 10000
  max = 99999
}

resource "aws_s3_bucket" "prod-bucket" {
  bucket = "prod-bucket-${random_integer.rand.result}"
  acl    = "private"
  versioning {
    enabled = true
  }
}

// Using default VPC
resource "aws_default_vpc" "default" {}

/* Define Ingress and Egress rules */

resource "aws_security_group" "prod-web" {
  name        = "prod-web"
  description = "This will allow SSH, HTTP/HTTPS access"

  ingress {
    from_port   = "22"
    to_port     = "22"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = "80"
    to_port     = "80"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = "443"
    to_port     = "443"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow http/s and ssh"
  }

}

// Dynamic Block Security Group Example

variable "ingress_rule" {
  type = list (number)
  description = "Ingress ports"
  default = [8443, 8080, 8888]
}

variable "egress_rule" {
  type = list (number)
  description = "Egress ports"
  default = [80, 443]
}

resource "aws_security_group" "websg" {
  name = "websg"
  description = "allow web access"

  dynamic "ingress" {
    for_each = var.ingress_rule
    iterator = port 
    content {
      from_port = port.value 
      to_port = port.value 
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    } 
  }

  dynamic "egress" {
    for_each = var.egress_rule
    iterator = port
    content {
      from_port = port.value 
      to_port = port.value 
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    } 
  } 
}

// Find the latest AMI
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

// Launch Instance
resource "aws_instance" "web-instance" {
  ami                         = data.aws_ami.rhel_latest.id
  instance_type               = "t2.micro"
  key_name                    = var.ami_key_pair_name
  security_groups             = [aws_security_group.prod-web.name]
  associate_public_ip_address = true
  source_dest_check           = false
  # Automatic tainitng is ONLY applicable for provisioners, in case something wrong with user_data block then you will have to manually taint the resource \
  # fix the problem and then re-run the apply.  During apply tainited resource will be recreated.
  user_data = <<-EOF
            #!/bin/bash
            yum install httpd -y
            echo "Terrform deployed" > /var/www/html/index.html
            systemctl start httpd --now
    EOF
	
	provisioner "local-exec" {
    command = "${path.module}/health_check.sh ${self.public_ip}"
    interpreter = ["/bin/bash", "-c"]
  }
  
  tags = {
    Name = "web-instance"
  }
}

resource "aws_eip" "web-instance-eip" {
  instance = aws_instance.web-instance.id

  tags = {
    name = "eip-web-instance"
  }
}

# Workspace with conditional statements example
variable "min" {
  default = 1
}

variable "max" {
  default = 2
}

locals {
  env = "${terraform.workspace}"
}

resource "aws_instance" "workspace-example" {
                              # If workspace is "default" then create 1 instance else create 2 instances. 
  count                       = terraform.workspace == "default" ? var.min : var.max
  ami                         = data.aws_ami.rhel_latest.id
  instance_type               = "t2.micro"
  key_name                    = var.ami_key_pair_name
  security_groups             = [aws_security_group.prod-web.name]
  associate_public_ip_address = true
  source_dest_check           = false

  tags = {
    Name = "web - ${terraform.workspace}"
  }
}

output "wsout" {
  value = local.env
}

# another way of using locals and lookup fuction. 

locals {
  env1 = "${terraform.workspace}"
  counts = {
    "default"    = 1
    "production" = 3
  }
  instances = {
    "default"    = "t2.micro"
    "production" = "t2.xlarge"
  }
  instance_type = "${lookup(local.instances, local.env1)}"
  count         = "${lookup(local.counts, local.env1)}"
}

resource "aws_instance" "workspace-example1" {
  instance_type               = local.instance_type
  count                       = local.count
  ami                         = data.aws_ami.rhel_latest.id
  key_name                    = var.ami_key_pair_name
  security_groups             = [aws_security_group.prod-web.name]
  associate_public_ip_address = true
  source_dest_check           = false

  tags = {
    Name = "ws-${count.index}"
    WS = "webapp-${terraform.workspace}"
  }
}

# Terraform count

variable "instance_name" {
  type = list
  default = ["nginx", "apache"]
}
resource "aws_instance" "count-example" {
  instance_type               = local.instance_type
  count                       = 2
  ami                         = data.aws_ami.rhel_latest.id
  key_name                    = var.ami_key_pair_name
  security_groups             = [aws_security_group.websg.name]
  associate_public_ip_address = true
  source_dest_check           = false

  tags = {
    Name = var.instance_name[count.index]
  }
}

# Terrform Import
/*  NOTE:  To demo/play with the import command, simply use the terraform state rm command to remove a resource from the state file.
           The physical resource will continue to exist. Then use the terraform import command to import it back into the state file.
*/

/* resource "aws_elb" "tf-elb" {
  name = "tf-elb"
  availability_zones = ["us-west-2a", "us-west-2b", "us-west-2c"]
  listener {
    instance_port = 80
    instance_protocol = "http"
    lb_port = 80
    lb_protocol = "http"
  }
  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    target = "HTTP:80/"
    interval = 30
  }
  instances = ["${aws_instance.web1.id}", "${aws_instance.web2.id}"]
  tags = {
    Name = "tf-elb"
  }
}
*/
#################################

output "pubIP" {
  value       = aws_instance.web-instance.public_ip
  description = "Public IP of instance"
}

output "eip" {
  value       = aws_eip.web-instance-eip.public_ip
  description = "EIP of an EC2 instance web-instance"
}

// Connection and Provisioner blocks. 
// Connection blocks don't take a block label, and can be nested within either a resource or a provisioner.
resource "aws_instance" "random_vm" {
  ami           = data.aws_ami.rhel_latest.id
  instance_type = "t2.micro"
  key_name                    = var.ami_key_pair_name
  security_groups             = [aws_security_group.websg.name]
  associate_public_ip_address = true
  source_dest_check           = false

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("/root/.ssh/pemfile/mumbai07312000.pem")
    host        = self.public_ip
  }

  provisioner "file" {
    content     = "ami used: ${self.ami}"
    destination = "/etc/imageid"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum -y install nginx",
      "sudo systemctl start nginx"
      "sudo setenforce permissive"
    ]
  }
}

// terraform fmt example only
/*
 provider "azurerm" {
 environment = "public"
 }
 module "vnet" {
 source = "Azure/vnet/azurerm"
 resource_group_name = "tacos"
location = "westus"
address_space = "10.0.0.0/16"
subnet_prefixes = ["10.0.1.0/24", "10.0.2.0/24"]
subnet_names = ["cheese","beans"]
}
*/

##################################################
/*
# Configure the Microsoft Azure Provider
provider "azurerm" {
    # The "feature" block is required for AzureRM provider 2.x.
    # If you're using version 1.x, the "features" block is not allowed.
    version = "~>2.0"
    features {}
}
# Create a resource group if it doesn't exist
resource "azurerm_resource_group" "myterraformgroup" {
    name     = "myResourceGroup"
    location = "eastus"
    tags = {
        environment = "Terraform Demo"
    }
}
# Create virtual network
resource "azurerm_virtual_network" "myterraformnetwork" {
    name                = "myVnet"
    address_space       = ["10.0.0.0/16"]
    location            = "eastus"
    resource_group_name = azurerm_resource_group.myterraformgroup.name
    tags = {
        environment = "Terraform Demo"
    }
}
# Create subnet
resource "azurerm_subnet" "myterraformsubnet" {
    name                 = "mySubnet"
    resource_group_name  = azurerm_resource_group.myterraformgroup.name
    virtual_network_name = azurerm_virtual_network.myterraformnetwork.name
    address_prefixes       = ["10.0.1.0/24"]
}
# Create public IPs
resource "azurerm_public_ip" "myterraformpublicip" {
    name                         = "myPublicIP"
    location                     = "eastus"
    resource_group_name          = azurerm_resource_group.myterraformgroup.name
    allocation_method            = "Dynamic"
    tags = {
        environment = "Terraform Demo"
    }
}
# Create Network Security Group and rule
resource "azurerm_network_security_group" "myterraformnsg" {
    name                = "myNetworkSecurityGroup"
    location            = "eastus"
    resource_group_name = azurerm_resource_group.myterraformgroup.name
    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }
    tags = {
        environment = "Terraform Demo"
    }
}
# Create network interface
resource "azurerm_network_interface" "myterraformnic" {
    name                      = "myNIC"
    location                  = "eastus"
    resource_group_name       = azurerm_resource_group.myterraformgroup.name
    ip_configuration {
        name                          = "myNicConfiguration"
        subnet_id                     = azurerm_subnet.myterraformsubnet.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.myterraformpublicip.id
    }
    tags = {
        environment = "Terraform Demo"
    }
}
# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "example" {
    network_interface_id      = azurerm_network_interface.myterraformnic.id
    network_security_group_id = azurerm_network_security_group.myterraformnsg.id
}
# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = azurerm_resource_group.myterraformgroup.name
    }
    byte_length = 8
}
# Create storage account for boot diagnostics
resource "azurerm_storage_account" "mystorageaccount" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = azurerm_resource_group.myterraformgroup.name
    location                    = "eastus"
    account_tier                = "Standard"
    account_replication_type    = "LRS"
    tags = {
        environment = "Terraform Demo"
    }
}
# Create (and display) an SSH key
resource "tls_private_key" "example_ssh" {
  algorithm = "RSA"
  rsa_bits = 4096
}
output "tls_private_key" { value = "${tls_private_key.example_ssh.private_key_pem}" }
# Create virtual machine
resource "azurerm_linux_virtual_machine" "myterraformvm" {
    name                  = "myVM"
    location              = "eastus"
    resource_group_name   = azurerm_resource_group.myterraformgroup.name
    network_interface_ids = [azurerm_network_interface.myterraformnic.id]
    size                  = "Standard_DS1_v2"
    os_disk {
        name              = "myOsDisk"
        caching           = "ReadWrite"
        storage_account_type = "Premium_LRS"
    }
    source_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "16.04.0-LTS"
        version   = "latest"
    }
    computer_name  = "myvm"
    admin_username = "azureuser"
    disable_password_authentication = true
    admin_ssh_key {
        username       = "azureuser"
        public_key     = tls_private_key.example_ssh.public_key_openssh
    }
    boot_diagnostics {
        storage_account_uri = azurerm_storage_account.mystorageaccount.primary_blob_endpoint
    }
    tags = {
        environment = "Terraform Demo"
    }
}
*/
