terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.46.0"
    }
  }
}

provider "aws" {
    region = "ca-central-1"
}



resource "aws_vpc" "demo-vpc" {
  cidr_block       = "10.1.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "demo-vpc"
  }
}


resource "aws_subnet" "public-alb-sn1" {
  vpc_id            = aws_vpc.demo-vpc.id
  cidr_block        = "10.1.0.0/20"
  availability_zone = "ca-central-1a"

  tags = {
    Name = "public-alb-sn1"
  }
}

resource "aws_subnet" "public-alb-sn2" {
  vpc_id            = aws_vpc.demo-vpc.id
  cidr_block        = "10.1.32.0/20"
  availability_zone = "ca-central-1b"

  tags = {
    Name = "public-alb-sn2"
  }
}

resource "aws_subnet" "private-app-sn1" {
  vpc_id            = aws_vpc.demo-vpc.id
  cidr_block        = "10.1.64.0/20"
  availability_zone = "ca-central-1a"

  tags = {
    Name = "private-app-sn1"
  }
}

resource "aws_subnet" "private-app-sn2" {
  vpc_id            = aws_vpc.demo-vpc.id
  cidr_block        = "10.1.96.0/20"
  availability_zone = "ca-central-1b"

  tags = {
    Name = "private-app-sn2"
  }
}

resource "aws_subnet" "private-db-sn1" {
  vpc_id            = aws_vpc.demo-vpc.id
  cidr_block        = "10.1.128.0/20"
  availability_zone = "ca-central-1a"

  tags = {
    Name = "private-db-sn1"
  }
}

resource "aws_subnet" "private-db-sn2" {
  vpc_id            = aws_vpc.demo-vpc.id
  cidr_block        = "10.1.160.0/20"
  availability_zone = "ca-central-1b"

  tags = {
    Name = "private-db-sn2"
  }
}

resource "aws_internet_gateway" "demo-igw" {
  vpc_id = aws_vpc.demo-vpc.id

  tags = {
    Name = "demo-igw"
  }
}

resource "aws_nat_gateway" "demo-nat-gw" {
  vpc_id         = aws_vpc.demo-vpc.id
  availability_mode = "regional"

  tags = {
    Name = "demo-regionalnat-gw"
  }
}

resource "aws_route_table" "demo-public-rt" {
  vpc_id = aws_vpc.demo-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.demo-igw.id
  }

  tags = {
    Name = "demo-public-rt"
  }
}

resource "aws_route_table" "demo-private-rt" {
  vpc_id = aws_vpc.demo-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.demo-nat-gw.id
  }

  tags = {
    Name = "demo-private-rt"
  }
}

resource "aws_route_table_association" "rt-association-public-alb-sn1" {
  subnet_id      = aws_subnet.public-alb-sn1.id
  route_table_id = aws_route_table.demo-public-rt.id
}
resource "aws_route_table_association" "rt-association-public-alb-sn2" {
  subnet_id      = aws_subnet.public-alb-sn2.id
  route_table_id = aws_route_table.demo-public-rt.id
}

resource "aws_route_table_association" "rt-association-private-app-sn1" {
  subnet_id      = aws_subnet.private-app-sn1.id
  route_table_id = aws_route_table.demo-private-rt.id
}
resource "aws_route_table_association" "rt-association-private-app-sn2" {
  subnet_id      = aws_subnet.private-app-sn2.id
  route_table_id = aws_route_table.demo-private-rt.id
}
resource "aws_route_table_association" "rt-association-private-db-sn1" {
  subnet_id      = aws_subnet.private-db-sn1.id
  route_table_id = aws_route_table.demo-private-rt.id
}
resource "aws_route_table_association" "rt-association-private-db-sn2" {
  subnet_id      = aws_subnet.private-db-sn2.id
  route_table_id = aws_route_table.demo-private-rt.id
}   

resource "aws_security_group" "alb-sg" {
  name        = "alb-sg"
  description = "Security group for ALB allowing HTTP traffic and allowing all outbound traffic"
  vpc_id      = aws_vpc.demo-vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
}

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}   

resource "aws_security_group" "app-sg" {
  name        = "app-sg"
  description = "Security group for application servers"
  vpc_id      = aws_vpc.demo-vpc.id

  ingress {
    security_groups = [aws_security_group.alb-sg.id]
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "db-sg" {
  name        = "db-sg"
  description = "Security group for database servers"
  vpc_id      = aws_vpc.demo-vpc.id

  ingress {
    security_groups = [aws_security_group.app-sg.id]
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_launch_template" "webserver-lt" {
  name    = "webserver-lt"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = "t3.micro"
  key_name      = data.aws_key_pair.demo-key.key_name
  network_interfaces {
    security_groups = [aws_security_group.app-sg.id]
associate_public_ip_address = false

  }

  lifecycle {
    create_before_destroy = true
  }
  user_data = base64encode(<<-EOF
#!/bin/bash
dnf update -y
dnf install -y httpd
systemctl start httpd
systemctl enable httpd
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
echo "Je suis le serveur Instance ID: $INSTANCE_ID" | sudo tee /var/www/html/index.html > /dev/null
systemctl reload httpd
EOF
  )
}


resource "aws_lb" "demo-alb" {
  name               = "demo-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb-sg.id]
  subnets            = [aws_subnet.public-alb-sn1.id, aws_subnet.public-alb-sn2.id]
  enable_deletion_protection = false

  tags = {
    Name = "demo-alb"
  }
}

resource "aws_lb_target_group" "demo-tg" {
  name     = "alb-tg"
  target_type = "instance"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.demo-vpc.id

  tags = {
    Name = "demo-tg"
  }
}

resource "aws_lb_listener" "demo-listener" {
  load_balancer_arn = aws_lb.demo-alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.demo-tg.arn
  }
}

resource "aws_autoscaling_group" "webserver-asg" {
  name                      = "webserver-asg"
  max_size                  = 4
  min_size                  = 1
  desired_capacity          = 2
  vpc_zone_identifier       = [aws_subnet.private-app-sn1.id, aws_subnet.private-app-sn2.id]
  target_group_arns         = [aws_lb_target_group.demo-tg.arn]
  health_check_grace_period = 60
  launch_template {
    id      = aws_launch_template.webserver-lt.id
    version = "$Latest"
  }
  tag {
    key                 = "Name"
    value               = "webserver"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}