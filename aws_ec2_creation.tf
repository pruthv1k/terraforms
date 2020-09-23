#Configure the Cloud Provider [aws]
provider "aws" {
  region = "us-west-2"
  access_key = "<enter aws iam user access key"
  secret_key = "<enter secret key>"
}


#Set the resources you want to create
resource "aws_instance" "<enter-instance-name>" {
  ami = "<enter-instance-ami-id" #mandatory
  instance_type = "<enter-instance-flavour" #example - t2.micro  #mandatory
}
