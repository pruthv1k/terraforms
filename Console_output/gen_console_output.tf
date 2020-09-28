#Provider Configuration 
provider "Provider_Name" {
 region = "<ENTER_HERE"
 access_key = "<ENTER_HERE>"
 secret_key = "<ENTER_HERE>"
 }
 

#Create a Elastic IP resource in AWS
resource "aws_eip" "<ENTER_HERE>" {

}

#Output the attribute of EIP in AWS using terraform
output "eip" {
  value = "aws_eip.pru.public_ip"
}
