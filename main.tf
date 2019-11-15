# Terraform state will be stored in S3
terraform {
  backend "s3" {
    bucket = "soumil-test-jenkins"
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}

# Use AWS Terraform provider
provider "aws" {
  region = "us-east-1"
}

resource "tls_private_key" "jenkins" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = "Jenkins-default"
  public_key = "${tls_private_key.jenkins.public_key_openssh}"
    depends_on = ["tls_private_key.jenkins"]
}
# Create elastic-ip
resource "aws_eip" "default1" {
  instance = "${aws_instance.default.id}"
  vpc      = true
# Network lb
resource "aws_lb" "network" {
  name               = "example"
  load_balancer_type = "network"

  subnet_mapping {
    subnet_id     = "${aws_subnet.*.id}"
    allocation_id = "${aws_eip.default1.id}"
  }

}
resource "aws_lb_listener" "listener" {
  load_balancer_arn       = "${aws_lb.network.arn}"
  for_each = "${var.forwarding_config}"
      port                = "each.key"
      protocol            = "each.value"
      default_action {
        target_group_arn = "${aws_lb_target_group.tg[each.key].arn}"
        type             = "forward"
      }
}
resource "aws_lb_target_group" "tg" {
  for_each = "${var.forwarding_config}"
    name                  = "tg"
    port                  = "each.key"
    protocol              = "each.value"
  deregistration_delay    = 90
  target_type             = "instance"
health_check {
    interval            = 60
    port                = "${each.value != "TCP_UDP" ? each.key : 80}"
    protocol            = "TCP"
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
  
}
resource "aws_lb_target_group_attachment" "tga1" {
  for_each = "${var.forwarding_config}"
    target_group_arn  = "${aws_lb_target_group.tg[each.key].arn}"
    port


# Create EC2 instance
resource "aws_instance" "default" {
  ami                    = "${var.ami}"
  count                  = "${var.count}"
  key_name               = "${aws_key_pair.generated_key.key_name}"
  vpc_security_group_ids = ["${aws_security_group.default.id}"]
  source_dest_check      = "false"
  instance_type          = "${var.instance_type}"
  user_data = "${file("permit_root.sh")}"
root_block_device = [
    {
      volume_type = "gp2"
      volume_size = 100
    },
  ]
  tags {
    Name = "terraform-default"
  }
  depends_on = ["aws_instance.default", "aws_key_pair.generated_key"] 
}

# Create Security Group for EC2
resource "aws_security_group" "default" {
  name = "terraform-default-sg"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
  }
resource "null_resource" "Script_provisioner" {
  triggers {
    public_ip = "${aws_eip.default1.public_ip}"
  }

  connection {
    type = "ssh"
    host = "${aws_eip.default1.public_ip}"
    user = "root"
    port = "22"
    private_key = "${tls_private_key.jenkins.private_key_pem}"
    agent = false
  }
  provisioner "local-exec" {
    command = "sleep 240"
  }
provisioner "file" {
    source      = "test.sh"
    destination = "/home/centos/test.sh"
  }
  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/centos/test.sh",
      "sh /home/centos/test.sh ${var.build_number}"
    ]
  }
depends_on = ["aws_instance.default"]
  }
