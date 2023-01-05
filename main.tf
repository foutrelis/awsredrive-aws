provider "aws" {
  region = var.awsredrive_region
}

resource "aws_sns_topic" "awsredrive" {
  name = "awsredriveExampleTopic"
}

resource "aws_sqs_queue" "awsredrive" {
  name = "awsredriveExampleQueue"
}

resource "aws_sns_topic_subscription" "awsredrive" {
  topic_arn = aws_sns_topic.awsredrive.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.awsredrive.arn
}

resource "aws_sqs_queue_policy" "awsredrive_allow_sns" {
  queue_url = aws_sqs_queue.awsredrive.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.awsredrive.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" : aws_sns_topic.awsredrive.arn
          }
        }
      },
    ]
  })
}

resource "aws_iam_role" "ec2_sqs_consumer" {
  name = "EC2SQSConsumerRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      },
    ]
  })
}

resource "aws_iam_policy" "ec2_sqs_consumer" {
  name = "EC2SQSConsumerPolicy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
        ]
        Effect   = "Allow"
        Resource = aws_sqs_queue.awsredrive.arn
      },
    ]
  })
}

resource "aws_iam_policy_attachment" "ec2_sqs_consumer" {
  name       = "EC2SQSConsumerPolicyAttachment"
  policy_arn = aws_iam_policy.ec2_sqs_consumer.arn
  roles      = [aws_iam_role.ec2_sqs_consumer.name]
}

resource "aws_iam_instance_profile" "ec2_sqs_consumer" {
  name = "EC2SQSConsumerInstanceProfile"
  role = aws_iam_role.ec2_sqs_consumer.name
}

resource "aws_security_group" "ssh_access" {
  name        = "SSHAccess"
  description = "Allow inbound SSH"

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
}

data "aws_ami" "debian11" {
  most_recent = true
  owners      = ["136693071363"]
  filter {
    name   = "name"
    values = ["debian-11-amd64-*"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "awsredrive" {
  ami                  = data.aws_ami.debian11.id
  instance_type        = "t2.micro"
  iam_instance_profile = aws_iam_instance_profile.ec2_sqs_consumer.name
  security_groups      = [aws_security_group.ssh_access.name]
  key_name             = var.awsredrive_key_pair_name

  user_data = templatefile("init.tftpl", {
    region    = var.awsredrive_region,
    queue_url = aws_sqs_queue.awsredrive.url,
    version   = var.awsredrive_version
  })
  user_data_replace_on_change = true

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "awsredrive"
  }
}

output "public_ip" {
  value = aws_instance.awsredrive.public_ip
}
