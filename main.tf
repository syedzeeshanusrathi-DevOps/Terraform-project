resource "aws_vpc" "mytfvpc" {
  cidr_block = var.cidr

}

resource "aws_subnet" "sub1" {
  vpc_id                  = aws_vpc.mytfvpc.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

}

resource "aws_subnet" "sub2" {
  vpc_id                  = aws_vpc.mytfvpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.mytfvpc.id

}

resource "aws_route_table" "tfRT" {
  vpc_id = aws_vpc.mytfvpc.id


  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

}

resource "aws_route_table_association" "rta1" {
  subnet_id      = aws_subnet.sub1.id
  route_table_id = aws_route_table.tfRT.id

}


resource "aws_route_table_association" "rta2" {
  subnet_id      = aws_subnet.sub2.id
  route_table_id = aws_route_table.tfRT.id

}

resource "aws_security_group" "mysgtf" {
  name   = "web_sgtf"
  vpc_id = aws_vpc.mytfvpc.id

  ingress {
    description = "HTTP from vpc"
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
    Name = "Web_sgtf"
  }
}

resource "aws_s3_bucket" "ex" {
  bucket = "nusrathimalkantf"
}

resource "aws_s3_bucket_ownership_controls" "ex" {
  bucket = aws_s3_bucket.ex.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "ex" {
  bucket = aws_s3_bucket.ex.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_acl" "ex" {
  depends_on = [
    aws_s3_bucket_ownership_controls.ex,
    aws_s3_bucket_public_access_block.ex,
  ]

  bucket = aws_s3_bucket.ex.id
  acl    = "public-read"
}

resource "aws_instance" "Webserver1" {
  ami                    = "ami-0c02fb55956c7d316"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.mysgtf.id]
  subnet_id              = aws_subnet.sub1.id
  key_name               = "key pair"
  user_data              = file("userdata.mk")
}

resource "aws_instance" "Webserver2" {
  ami                    = "ami-0c02fb55956c7d316"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.mysgtf.id]
  subnet_id              = aws_subnet.sub1.id
  key_name               = "key pair"
  user_data              = file("userdata.mk")
}

#Create ALB

resource "aws_lb" "mylbtf" {
  name               = "mylbtf"
  internal           = false
  load_balancer_type = "application"

  security_groups = [aws_security_group.mysgtf.id]
  subnets         = [aws_subnet.sub1.id, aws_subnet.sub2.id]

  tags = {
    Name = "web"
  }
}




resource "aws_lb_target_group" "tg" {
  name     = "myTG"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.mytfvpc.id


  health_check {
    path = "/"
    port = "traffic-port"
  }



}

resource "aws_lb_target_group_attachment" "attach1" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.Webserver1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "attach2" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.Webserver2.id
  port             = 80
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.mylbtf.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

output "load_balancerdns" {
  value = aws_lb.mylbtf.dns_name



}


