terraform {
  required_providers {
    digitalocean = {
      source = "digitalocean/digitalocean"
      version = "1.22.2"
    }
  }
}

#Configuring authentication
provider "digitalocean" {
  token = "Enter_token_here"
}

#Configuring resources to deploy on Digital Ocean using terraform
resource "digitalocean_droplet" "Enter_Suitable_Name" {
    image = "ubuntu/fedora/freebsd/windows"   #ex - ubuntu-18-04-x64
    name = "Anyname"                          #ex - pru30
    region = "cloud region"                   #ex - nyc2
    size = "sys_config"                       #ex - s-1vcpu-1gb
}
