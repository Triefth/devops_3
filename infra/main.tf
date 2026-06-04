# ==============================================================================
# PROYECTO: DEVOPS - EVALUACIÓN PARCIAL N°2
# ARQUITECTURA SIMPLIFICADA PARA AWS ACADEMY
# ==============================================================================

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# ====== 1. REDES ======
resource "aws_vpc" "devops_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = { Name = "vpc-devops-ep2" }
}

resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.devops_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
  tags = { Name = "subnet-public-devops-1" }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.devops_vpc.id
  cidr_block              = "10.0.3.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1b"
  tags = { Name = "subnet-public-devops-2" }
}

resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.devops_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"
  tags = { Name = "subnet-private-devops-1" }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.devops_vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1b"
  tags = { Name = "subnet-private-devops-2" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.devops_vpc.id
  tags = { Name = "igw-devops" }
}

resource "aws_eip" "nat" {
  domain = "vpc"
  tags = { Name = "eip-nat-devops" }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_subnet_1.id
  depends_on    = [aws_internet_gateway.igw]
  tags = { Name = "nat-devops" }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.devops_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "rt-public-devops" }
}

resource "aws_route_table_association" "public_assoc_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_assoc_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.devops_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = { Name = "rt-private-devops" }
}

resource "aws_route_table_association" "private_assoc_1" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_assoc_2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_rt.id
}

# ====== 2. SEGURIDAD ======
resource "aws_security_group" "alb_sg" {
  name        = "alb-sg-devops"
  description = "Allow HTTP inbound"
  vpc_id      = aws_vpc.devops_vpc.id

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
  tags = { Name = "sg-alb-devops" }
}

resource "aws_security_group" "ecs_tasks_sg" {
  name        = "ecs-tasks-sg-devops"
  description = "ECS tasks SG"
  vpc_id      = aws_vpc.devops_vpc.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  ingress {
    from_port       = 8081
    to_port         = 8081
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  ingress {
    from_port       = 8082
    to_port         = 8082
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "sg-ecs-tasks-devops" }
}

resource "aws_security_group" "mysql_sg" {
  name        = "mysql-sg-devops"
  description = "MySQL access"
  vpc_id      = aws_vpc.devops_vpc.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "sg-mysql-devops" }
}

# ====== 3. ECR ======
resource "aws_ecr_repository" "repo_front" {
  name                 = "devops-frontend"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
  tags = { Name = "ecr-devops-frontend" }
}

resource "aws_ecr_repository" "repo_ventas" {
  name                 = "devops-back-ventas"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
  tags = { Name = "ecr-devops-ventas" }
}

resource "aws_ecr_repository" "repo_despachos" {
  name                 = "devops-back-despachos"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
  tags = { Name = "ecr-devops-despachos" }
}

# ====== 4. ECS CLUSTER ======
resource "aws_ecs_cluster" "devops_cluster" {
  name = "devops-cluster"
  tags = { Name = "ecs-cluster-devops" }
}

# ====== 5. TASK DEFINITIONS ======
# Usamos un rol existente si existe
data "aws_iam_role" "existing_execution_role" {
  name = "LabRole"  # Cambia si tu lab tiene otro nombre
}

# --- FRONTEND ---
resource "aws_ecs_task_definition" "frontend_task" {
  family                   = "devops-frontend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = try(data.aws_iam_role.existing_execution_role.arn, null)

  container_definitions = jsonencode([{
    name      = "frontend"
    image     = "${aws_ecr_repository.repo_front.repository_url}:latest"
    essential = true
    portMappings = [{
      containerPort = 80
      hostPort      = 80
      protocol      = "tcp"
    }]
    environment = [
      { name = "BACKEND_DESPACHOS_URL", value = "http://localhost:8081" },
      { name = "BACKEND_VENTAS_URL", value = "http://localhost:8082" }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/devops-frontend"
        "awslogs-region"        = "us-east-1"
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
  tags = { Name = "task-def-devops-frontend" }
}

# --- BACKEND DESPACHOS ---
resource "aws_ecs_task_definition" "backend_despachos_task" {
  family                   = "devops-backend-despachos"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = try(data.aws_iam_role.existing_execution_role.arn, null)

  container_definitions = jsonencode([{
    name      = "backend-despachos"
    image     = "${aws_ecr_repository.repo_despachos.repository_url}:latest"
    essential = true
    portMappings = [{
      containerPort = 8081
      hostPort      = 8081
      protocol      = "tcp"
    }]
    environment = [
      { name = "SPRING_DATASOURCE_URL", value = "jdbc:mysql://${aws_instance.mysql_srv.private_ip}:3306/despachosdb?useSSL=false&allowPublicKeyRetrieval=true" },
      { name = "SPRING_DATASOURCE_USERNAME", value = "userdb" },
      { name = "SPRING_DATASOURCE_PASSWORD", value = "passdb" }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/devops-backend-despachos"
        "awslogs-region"        = "us-east-1"
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
  tags = { Name = "task-def-devops-despachos" }
}

# --- BACKEND VENTAS ---
resource "aws_ecs_task_definition" "backend_ventas_task" {
  family                   = "devops-backend-ventas"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = try(data.aws_iam_role.existing_execution_role.arn, null)

  container_definitions = jsonencode([{
    name      = "backend-ventas"
    image     = "${aws_ecr_repository.repo_ventas.repository_url}:latest"
    essential = true
    portMappings = [{
      containerPort = 8082
      hostPort      = 8082
      protocol      = "tcp"
    }]
    environment = [
      { name = "SPRING_DATASOURCE_URL", value = "jdbc:mysql://${aws_instance.mysql_srv.private_ip}:3306/ventasdb?useSSL=false&allowPublicKeyRetrieval=true" },
      { name = "SPRING_DATASOURCE_USERNAME", value = "userdb" },
      { name = "SPRING_DATASOURCE_PASSWORD", value = "passdb" }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/devops-backend-ventas"
        "awslogs-region"        = "us-east-1"
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
  tags = { Name = "task-def-devops-ventas" }
}

# ====== 6. ALB ======
resource "aws_lb" "front_alb" {
  name               = "devops-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
  tags = { Name = "alb-devops" }
}

resource "aws_lb_target_group" "frontend_tg" {
  name        = "frontend-tg-devops"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.devops_vpc.id
  target_type = "ip"
  tags = { Name = "tg-devops-frontend" }
}

resource "aws_lb_target_group" "despachos_tg" {
  name        = "despachos-tg-devops"
  port        = 8081
  protocol    = "HTTP"
  vpc_id      = aws_vpc.devops_vpc.id
  target_type = "ip"
  health_check {
    path = "/actuator/health"
    matcher = "200"
  }
  tags = { Name = "tg-devops-despachos" }
}

resource "aws_lb_target_group" "ventas_tg" {
  name        = "ventas-tg-devops"
  port        = 8082
  protocol    = "HTTP"
  vpc_id      = aws_vpc.devops_vpc.id
  target_type = "ip"
  health_check {
    path = "/actuator/health"
    matcher = "200"
  }
  tags = { Name = "tg-devops-ventas" }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.front_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_tg.arn
  }
  tags = { Name = "listener-devops-http" }
}

resource "aws_lb_listener_rule" "despachos_rule" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.despachos_tg.arn
  }

  condition {
    path_pattern {
      values = ["/api/v1/despachos*"]
    }
  }
}

resource "aws_lb_listener_rule" "ventas_rule" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ventas_tg.arn
  }

  condition {
    path_pattern {
      values = ["/api/v1/ventas*"]
    }
  }
}

# ====== 7. ECS SERVICES ======
resource "aws_ecs_service" "frontend_service" {
  name            = "devops-frontend-service"
  cluster         = aws_ecs_cluster.devops_cluster.id
  task_definition = aws_ecs_task_definition.frontend_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
    security_groups  = [aws_security_group.ecs_tasks_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend_tg.arn
    container_name   = "frontend"
    container_port   = 80
  }

  depends_on = [aws_lb_listener.http]
  tags = { Name = "ecs-svc-devops-frontend" }
}

resource "aws_ecs_service" "backend_despachos_service" {
  name            = "devops-backend-despachos-service"
  cluster         = aws_ecs_cluster.devops_cluster.id
  task_definition = aws_ecs_task_definition.backend_despachos_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
    security_groups  = [aws_security_group.ecs_tasks_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.despachos_tg.arn
    container_name   = "backend-despachos"
    container_port   = 8081
  }

  depends_on = [aws_lb_listener_rule.despachos_rule]
  tags = { Name = "ecs-svc-devops-despachos" }
}

resource "aws_ecs_service" "backend_ventas_service" {
  name            = "devops-backend-ventas-service"
  cluster         = aws_ecs_cluster.devops_cluster.id
  task_definition = aws_ecs_task_definition.backend_ventas_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
    security_groups  = [aws_security_group.ecs_tasks_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ventas_tg.arn
    container_name   = "backend-ventas"
    container_port   = 8082
  }

  depends_on = [aws_lb_listener_rule.ventas_rule]
  tags = { Name = "ecs-svc-devops-ventas" }
}

# ====== 8. EC2 PARA MYSQL ======
variable "ami_id" {
  description = "Amazon Linux 2023 AMI ID"
  type        = string
  default     = "ami-0c7217cdde317cfec"  # AMI correcto para AWS Academy en us-east-1
}

variable "key_name" {
  description = "Nombre del par de llaves SSH"
  type        = string
  default     = "vockey"
}

resource "aws_instance" "mysql_srv" {
  ami                    = var.ami_id
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.private_subnet_1.id
  vpc_security_group_ids = [aws_security_group.mysql_sg.id]
  key_name               = var.key_name
  root_block_device {
    volume_type = "gp3"        # Tipo de volumen (gp3 es más barato y rápido que gp2)
    volume_size = 20           # Tamaño en GB
    delete_on_termination = true  # Se elimina al destruir la instancia (opcional)
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    sudo apt-get update -y
    sudo apt-get install -y docker.io
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -aG docker ubuntu

    mkdir -p /opt/mysql-init
    cat > /opt/mysql-init/init.sql <<SQL
    CREATE DATABASE IF NOT EXISTS despachosdb;
    CREATE DATABASE IF NOT EXISTS ventasdb;
    GRANT ALL PRIVILEGES ON despachosdb.* TO 'userdb'@'%';
    GRANT ALL PRIVILEGES ON ventasdb.* TO 'userdb'@'%';
    FLUSH PRIVILEGES;
    SQL

    docker run -d \
      --name mysql_db \
      --restart always \
      -p 3306:3306 \
      -v mysql_data:/var/lib/mysql \
      -v /opt/mysql-init:/docker-entrypoint-initdb.d \
      -e MYSQL_ROOT_PASSWORD=rootpassword \
      -e MYSQL_USER=userdb \
      -e MYSQL_PASSWORD=passdb \
      mysql:8.0
  EOF
  )

  tags = { Name = "EC2-MySQL-DevOps" }
}

# ====== 9. CLOUDWATCH LOGS ======
resource "aws_cloudwatch_log_group" "ecs_frontend" {
  name = "/ecs/devops-frontend"
  tags = { Name = "log-devops-frontend" }
}

resource "aws_cloudwatch_log_group" "ecs_backend_despachos" {
  name = "/ecs/devops-backend-despachos"
  tags = { Name = "log-devops-despachos" }
}

resource "aws_cloudwatch_log_group" "ecs_backend_ventas" {
  name = "/ecs/devops-backend-ventas"
  tags = { Name = "log-devops-ventas" }
}

# ====== 10. OUTPUTS ======
output "alb_dns_name" {
  value       = aws_lb.front_alb.dns_name
  description = "DNS del ALB para acceder al Frontend"
}

output "mysql_private_ip" {
  value       = aws_instance.mysql_srv.private_ip
  description = "IP privada de MySQL"
}

output "ecr_repository_urls" {
  value = {
    frontend  = aws_ecr_repository.repo_front.repository_url
    ventas    = aws_ecr_repository.repo_ventas.repository_url
    despachos = aws_ecr_repository.repo_despachos.repository_url
  }
  description = "URLs de los repositorios ECR"
}