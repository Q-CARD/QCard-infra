provider "aws" {
  region = "ap-northeast-2"
}

resource "null_resource" "generate_ssh_key" {
  provisioner "local-exec" {
    command = "ssh-keygen -t rsa -b 2048 -f ${path.module}/ssh/id_rsa -N ''"
  }
}

output "public_key" {
  value = file("${path.module}/ssh/id_rsa.pub")
}

output "private_key" {
    value = file("./id_rsa")
}

resource "aws_key_pair" "qcard-keypair" {
  key_name = "qcard-kafka-key"
  public_key = file("${path.module}/ssh/id_rsa.pub")
}

output "key_pair_name" {
    value = aws_key_pair.qcard-keypair.key_name
}

resource "aws_security_group" "kafka-security-group" {
    name = "qcardKafkaSecurityGroup"
    description = "Security Group for Kafka"
    ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9092
    to_port     = 9092
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

resource "aws_instance" "qcard-kafka" {
  ami = "ami-09eb4311cbaecf89d"
  instance_type = "t2.micro"
  key_name = aws_key_pair.qcard-keypair.key_name
  vpc_security_group_ids = [aws_security_group.kafka-security-group.id]
  associate_public_ip_address = true

  root_block_device {
    volume_type = "gp2"
    volume_size = 30
  }

  tags = {
    Name = "qcard-kafka"
  }

  provisioner "remote-exec" {
    inline = [
        "chmod +x ./kafka/install_docker.sh",
        "./kafka/install_docker.sh",
        "sudo docker-compose -f ./kafka/docker-compose.yaml up -d"
    ]

    connection {
      type = "ssh"
      user = "ubuntu"
      private_key = aws_key_pair.qcard-keypair.private_key_pem
      host = aws_instance.qcard-kafka.public_ip
    }
  }
}




