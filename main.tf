locals {
    ssh_user = "ubuntu"
    key_name = "study"
    private_key_path = "~/.ssh/study.pem"
}


provider "aws" {
    region = "us-east-2"
    access_key = var.aws_access_key
    secret_key = var.aws_secret_key

}


resource "aws_vpc" "dev-vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
      Name = "dev-vpc"
  }
}



resource "aws_internet_gateway" "dev-gw" {
  vpc_id = aws_vpc.dev-vpc.id

  tags = {
    Name = "dev-gw"
  }
}


resource "aws_route_table" "dev-route" {
  vpc_id = aws_vpc.dev-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dev-gw.id
  }

  tags = {
    Name = "dev-route"
  }
}

resource "aws_subnet" "dev-subnet" {
  vpc_id     = aws_vpc.dev-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-2a"

  tags = {
    Name = "dev-subnet"
  }
}

resource "aws_route_table_association" "dev-table-assoc"{
    subnet_id      = aws_subnet.dev-subnet.id
    route_table_id = aws_route_table.dev-route.id
}

resource "aws_security_group" "nginx" {
    name = "nginx_acess"
    vpc_id = aws_vpc.dev-vpc.id

    ingress{
    description = "SSH"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    }

    ingress{
    description = "HTTP"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    }

    ingress{
    description = "HTTPS"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_network_interface" "test" {
    
    depends_on = [aws_internet_gateway.dev-gw]
    subnet_id       = aws_subnet.dev-subnet.id
    private_ips     = ["10.0.1.50"]
    security_groups = [aws_security_group.nginx.id]

  attachment {
    instance     = aws_instance.nginx.id
    device_index = 1
  }
}

resource "aws_instance" "nginx" {
    ami = "ami-0aeb7c931a5a61206"
    subnet_id = aws_subnet.dev-subnet.id
    instance_type = "t2.micro"
    associate_public_ip_address = true
    vpc_security_group_ids = [aws_security_group.nginx.id]
    key_name = local.key_name
    tags = {
        Name = "Nginx"

    }

    provisioner "remote-exec" {
        inline = [
          "echo 'Wait until SSH is ready'"
        ]

        connection {
          type = "ssh"
          user = local.ssh_user
          private_key = file(local.private_key_path)
          host = aws_instance.nginx.public_ip
        }
      
    }
    provisioner "local-exec" {
      command = "ansible-playbook -i ${aws_instance.nginx.public_ip}, --private-key ${local.private_key_path} nginx.yaml"
    }
}


output "nginx_ip" {
        value = aws_instance.nginx.public_ip
    }