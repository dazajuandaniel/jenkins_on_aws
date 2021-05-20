terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  required_version = ">= 0.14.9"
}

provider "aws" {
  profile = "default"
  region  = "ap-southeast-2"
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "jenkins_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "jenkins_vpc"
  }
}

resource "aws_subnet" "jenkins_public_subnet_1" {
  vpc_id     = aws_vpc.jenkins_vpc.id
  map_public_ip_on_launch = true
  availability_zone = data.aws_availability_zones.available.names[0]
  cidr_block = "10.0.0.0/24"
  tags = {
    Name = "jenkins_public_subnet_1"
  }
}

resource "aws_subnet" "jenkins_public_subnet_2" {
  vpc_id     = aws_vpc.jenkins_vpc.id
  map_public_ip_on_launch = true
  availability_zone = data.aws_availability_zones.available.names[1]
  cidr_block = "10.0.1.0/24"
  tags = {
    Name = "jenkins_public_subnet_2"
  }
}

resource "aws_subnet" "jenkins_private_subnet_1" {
  vpc_id     = aws_vpc.jenkins_vpc.id
  availability_zone = data.aws_availability_zones.available.names[0]
  cidr_block = "10.0.2.0/24"
  tags = {
    Name = "jenkins_private_subnet_1"
  }
}

resource "aws_subnet" "jenkins_private_subnet_2" {
  vpc_id     = aws_vpc.jenkins_vpc.id
  availability_zone = data.aws_availability_zones.available.names[1]
  cidr_block = "10.0.3.0/24"
  tags = {
    Name = "jenkins_private_subnet_2"
  }
}

resource "aws_internet_gateway" "jenkins_internet_gateway" {
  vpc_id = aws_vpc.jenkins_vpc.id
  tags = {
    Name = "jenkins_internet_gateway"
  }
}

resource "aws_eip" "jenkins_elastic_ip_1" {
  vpc      = true
  tags = {
    Name = "jenkins_elastic_ip_1"
  }
}

resource "aws_eip" "jenkins_elastic_ip_2" {
  vpc      = true
  tags = {
    Name = "jenkins_elastic_ip_2"
  }
}

# resource "aws_eip_association" "jenkins_elastic_ip_1_association" {
#   network_interface_id   = aws_nat_gateway.jenkins_nat_gateway_1.network_interface_id
#   allocation_id = aws_eip.jenkins_elastic_ip_1.id
# }

# resource "aws_eip_association" "jenkins_elastic_ip_2_association" {
#   network_interface_id   = aws_nat_gateway.jenkins_nat_gateway_2.network_interface_id
#   allocation_id = aws_eip.jenkins_elastic_ip_2.id
# }

resource "aws_nat_gateway" "jenkins_nat_gateway_1" {
  allocation_id = aws_eip.jenkins_elastic_ip_1.id
  subnet_id     = aws_subnet.jenkins_public_subnet_1.id

  tags = {
    Name = "jenkins_nat_gateway_1"
  }
}

resource "aws_nat_gateway" "jenkins_nat_gateway_2" {
  allocation_id = aws_eip.jenkins_elastic_ip_2.id
  subnet_id     = aws_subnet.jenkins_public_subnet_2.id

  tags = {
    Name = "jenkins_nat_gateway_2"
  }
}

resource "aws_route_table" "jenkins_public_route_table" {
  vpc_id = aws_vpc.jenkins_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.jenkins_internet_gateway.id
  }
  tags = {
    Name = "jenkins_public_route_table"
  }
}

resource "aws_route_table_association" "jenkins_public_subnet_association_1" {
  subnet_id      = aws_subnet.jenkins_public_subnet_1.id
  route_table_id = aws_route_table.jenkins_public_route_table.id
}

resource "aws_route_table_association" "jenkins_public_subnet_association_2" {
  subnet_id      = aws_subnet.jenkins_public_subnet_2.id
  route_table_id = aws_route_table.jenkins_public_route_table.id
}

resource "aws_route_table" "jenkins_private_route_table_1" {
  vpc_id = aws_vpc.jenkins_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.jenkins_nat_gateway_1.id
  }
  tags = {
    Name = "jenkins_private_route_table_1"
  }
}

resource "aws_route_table_association" "jenkins_private_subnet_association_1" {
  subnet_id      = aws_subnet.jenkins_private_subnet_1.id
  route_table_id = aws_route_table.jenkins_private_route_table_1.id
}

resource "aws_route_table" "jenkins_private_route_table_2" {
  vpc_id = aws_vpc.jenkins_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.jenkins_nat_gateway_2.id
  }
  tags = {
    Name = "jenkins_private_route_table_2"
  }
}

resource "aws_route_table_association" "jenkins_private_subnet_association_2" {
  subnet_id      = aws_subnet.jenkins_private_subnet_2.id
  route_table_id = aws_route_table.jenkins_private_route_table_2.id
}

resource "aws_security_group" "jenkins_load_balancer_sg" {
  name        = "jenkins_load_balancer_sg"
  description = "Security group for load balancer"
  vpc_id      = aws_vpc.jenkins_vpc.id

  ingress {
    description      = "TCP"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    security_groups  = [aws_security_group.jenkins_sg.id]
  }

  tags = {
    Name = "load_balancer_sg"
  }
}

resource "aws_security_group" "jenkins_sg" {
  name        = "jenkins_sg"
  description = "Security group for Jenkins"
  vpc_id      = aws_vpc.jenkins_vpc.id

  tags = {
    Name = "jenkins_sg"
  }
}

resource "aws_security_group_rule" "ingress_rule_for_jenkins_sg" {
  type              = "ingress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  source_security_group_id = aws_security_group.jenkins_load_balancer_sg.id
  security_group_id = aws_security_group.jenkins_sg.id
}

resource "aws_security_group_rule" "egress_rule_for_jenkins_sg" {
  type              = "egress"
  to_port           = 0
  protocol          = "-1"
  from_port         = 0
  cidr_blocks      = ["0.0.0.0/0"]
  security_group_id = aws_security_group.jenkins_sg.id
}

resource "aws_security_group" "jenkins_efs_sg" {
  name        = "jenkins_efs_sg"
  description = "Security group for EFS"
  vpc_id      = aws_vpc.jenkins_vpc.id

  ingress {
    description      = "TCP"
    from_port        = 2049
    to_port          = 2049
    protocol         = "tcp"
    security_groups  = [aws_security_group.jenkins_sg.id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "jenkins_efs_sg"
  }
}

resource "aws_lb" "jenkins_load_balancer" {
  name               = "jenkinsLoadBalancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.jenkins_load_balancer_sg.id]
  subnets            = [aws_subnet.jenkins_public_subnet_1.id,aws_subnet.jenkins_public_subnet_2.id]

  tags = {
    Environment = "production"
  }
}

resource "aws_lb_target_group" "jenkins_load_balancer_target_group" {
  name     = "jenkinsLoadBalancerTargetGroup"
  port     = 8080
  protocol = "HTTP"
  target_type = "ip"
  vpc_id   = aws_vpc.jenkins_vpc.id
  deregistration_delay = 10

  health_check {
    path = "/login"
    port = 8080
  }
}

resource "aws_lb_listener" "jenkins_load_balancer_listener" {
  load_balancer_arn = aws_lb.jenkins_load_balancer.arn
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = "arn:aws:acm:ap-southeast-2:024277711153:certificate/338dde1f-0edc-4c11-8bca-00e8bd95dbd9"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jenkins_load_balancer_target_group.arn
  }
}

resource "aws_efs_file_system" "jenkins_efs" {

  tags = {
    Name = "jenkins_efs"
  }
}

resource "aws_efs_mount_target" "jenkins_efs_mount_target_private_1" {
  file_system_id = aws_efs_file_system.jenkins_efs.id
  subnet_id      = aws_subnet.jenkins_private_subnet_1.id
  security_groups = [ aws_security_group.jenkins_efs_sg.id ]
}

resource "aws_efs_mount_target" "jenkins_efs_mount_target_private_2" {
  file_system_id = aws_efs_file_system.jenkins_efs.id
  subnet_id      = aws_subnet.jenkins_private_subnet_2.id
  security_groups = [ aws_security_group.jenkins_efs_sg.id ]
}

resource "aws_efs_access_point" "test" {
  file_system_id = aws_efs_file_system.jenkins_efs.id
  posix_user {
    uid = 1000
    gid = 1000
  }
  root_directory {
    creation_info {
      owner_gid = 1000
      owner_uid = 1000
      permissions = 755
    }
    path = "/jenkins-home"
  }

}

resource "aws_ecs_cluster" "jenkins_ecs_cluster" {
  name = "jenkins_ecs_cluster"
  capacity_providers = [ "FARGATE" ]
}

resource "aws_iam_role" "jenkins_execution_role" {
  name = "jenkins_execution_role"
  path = "/"
  managed_policy_arns = [ "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy" ]

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })

}

resource "aws_iam_role" "jenkins_role" {
  name = "jenkins_role"
  path = "/"
  managed_policy_arns = [ "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy" ]

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })

  inline_policy  {
    name = "jenkins_role_inline_policy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action   = ["elasticfilesystem:ClientMount", "elasticfilesystem:ClientWrite"]
          Effect   = "Allow"
          Resource = "*"
        },
      ]
    })
  }
}

