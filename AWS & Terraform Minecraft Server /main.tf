provider "aws" {
  region = "us-east-1"
}

# Define a VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "minecraft-vpc"
  }
}

# Create a public subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  tags = {
    Name = "minecraft-public-subnet"
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "minecraft-igw"
  }
}

# Create a route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = {
    Name = "minecraft-route-table"
  }
}

# Associate the route table with the public subnet
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Create a security group for the EC2 instance
resource "aws_security_group" "minecraft_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 19132
    to_port     = 19132
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
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
    Name = "minecraft-sg"
  }
}

# Key pair for SSH access
resource "aws_key_pair" "minecraft_key" {
  key_name   = "minecraft-key"
  public_key = file("~/.ssh/id_rsa.pub")
}

# Create an EC2 instance
resource "aws_instance" "minecraft_server" {
  ami                    = "ami-08c40ec9ead489470" # Amazon Linux 2 AMI
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.minecraft_sg.id] # Use the security group ID
  key_name               = aws_key_pair.minecraft_key.key_name

  tags = {
    Name = "minecraft-server"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y",
      "sudo yum install -y wget unzip",
      "wget https://minecraft.azureedge.net/bin-linux/bedrock-server-1.20.30.01.zip",
      "unzip bedrock-server-1.20.30.01.zip -d bedrock",
      "cd bedrock",
      "./bedrock_server &"
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("~/.ssh/id_rsa")
      host        = self.public_ip
    }
  }
}
