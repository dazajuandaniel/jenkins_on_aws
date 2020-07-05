provider "aws" {
  region     = "ap-southeast-2"
}

resource "aws_instance" "example" {
  ami           = "ami-021acbdb89706aa89"
  instance_type = "t2.micro"
}