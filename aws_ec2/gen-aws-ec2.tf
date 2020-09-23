#Configure the Cloud Provider [aws]
provider "aws" {
  region = "us-west-2"
  access_key = "Enter access key"
  secret_key = "Enter Secret Key"
}


#Set the resources you want to create
resource "aws_instance" "Enter Instance Name" {
  ami = "Enter AMI ID"
  instance_type = "Enter flavour"   #ex - t2.micro 
}
