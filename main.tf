provider "aws" {
  region = "us-east-1"
  access_key = "AKIASMX4MJGA6KA4KJF6"
  secret_key = "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"
}

resource "aws_instance" "web" {
  ami           = "ami-0261755bbcb8c4a84"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"


  key_name = "terraform"
  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.web-server-nic.id
    
  }

  user_data = <<-EOF
                #!/bin/bash
                sudo apt update -y
                sudo apt install apache2 -y
                sudo systemctl start apache2
                sudo bash -c 'echo your first terraform web server > /var/www/html/index.html'
                EOF 

#     provisioner "remote-exec" {
#     inline = [
#       "sudo apt update -y",
#       "sudo apt install apache2 -y",
#       "sudo systemctl start apache2",
#       "sudo bash -c 'echo your first terraform web server > /var/www/html/index.html'",
#     ]
#   }
    tags = {
        Name="web-server"
    }
}


resource "aws_vpc" "prod-vpc" {
  cidr_block = "10.0.0.0/16"
  tags={
    Name="production"
  }

}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod-vpc.id

}

resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "prod"
  }
}

resource "aws_subnet" "subnet-1" {
  vpc_id     = aws_vpc.prod-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "prod-subnet"
  }
}

resource "aws_subnet" "subnet-2" {
  vpc_id     = aws_vpc.prod-vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "prod-subnet-2"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.prod-route-table.id
}

resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.prod-vpc.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH"
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
    Name = "allow_web"
  }
}

resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]

}

resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.gw]
}


# resource "aws_lb" "web_lb" {
#   name               = "web-lb"
#   internal           = false
#   load_balancer_type = "application"
#   subnets            = [aws_subnet.subnet-1.id,aws_subnet.subnet-2.id]
#   #yessecurity_groups = [aws_security_group.allow_web.id]

# }

# resource "aws_lb_target_group" "web_target_group" {
#   name     = "web-target-group"
#   port     = 80
#   protocol = "HTTP"
#   vpc_id   = aws_vpc.prod-vpc.id
# }

# resource "aws_lb_listener" "web_listener" {
#   load_balancer_arn = aws_lb.web_lb.arn
#   port              = 80
#   protocol          = "HTTP"

#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.web_target_group.arn
#   }
# }
# resource "aws_lb_target_group_attachment" "web_attachment" {
#   target_group_arn = aws_lb_target_group.web_target_group.arn
#   target_id        = aws_instance.web.id
#   port             = 80
# }

# resource "aws_db_instance" "rds" {
#   allocated_storage    = 10
#   db_name              = "mydb"
#   engine               = "mysql"
#   engine_version       = "5.7"
#   instance_class       = "db.t3.micro"
#   username             = "admin"
#   password             = "admin0?123"
#   parameter_group_name = "default.mysql5.7"
#   skip_final_snapshot  = true
# }

# resource "aws_route53_zone" "easy_aws" {
#   name = "easy_aws.in"

#   tags = {
#     Environment = "dev"
#   }
# }
# resource "aws_route53_record" "www" {
#   zone_id = aws_route53_zone.main.zone_id
#   name    = "easy_aws.in"
#   type    = "A"
#   ttl     = "300"
#   #records = aws_route53_zone.dev.name_servers
#   records = [aws_eip.eip.public_ip]
# }

# output "name_server" {
#     value = aws_route53_record.easy_aws.name_servers
  
# }
