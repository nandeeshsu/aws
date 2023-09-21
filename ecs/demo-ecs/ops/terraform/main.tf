terraform {

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  //required_version = ">= 1.2.0"
}
locals {
  bucket_name     = "120191-test-ecs-trigger-120191"
  event_bus_name  = "default"
  vpc_id = "vpc-0d5dbae97d80196c1"
  //ecs_subnet_id = "subnet-0ab147cdcf766a9b1,subnet-0878bc7463b0e7054,subnet-0bc6e9e83b364a7e4,subnet-0cc6ed973b4be3fa7,subnet-0e53dbc2c3a74105f,subnet-0c54afd2dfd23c130"
}

provider "aws" {
  profile = "default"
  region  = "us-east-1"
  //either hardcode or externalize via variable
  //access_key = var.access_key
  //secret_key = var.secret_key
}

data "aws_subnets" "my_subnets" {
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }
}

data "aws_subnet" "my_subnet" {
  for_each = toset(data.aws_subnets.my_subnets.ids)
  id       = each.value
}

resource "aws_ecr_repository" "demo_ecs" {
  name                 = "demo_ecs"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

/*resource "aws_vpc" "ecs-cluster-vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
}*/

resource "aws_ecs_cluster" "test" {
  name = "test"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

data "aws_ecr_image" "demo_ecs" {
  repository_name = aws_ecr_repository.demo_ecs.name
  image_tag       = "latest"
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "demo-ecs-ecs-task-execution-role"
  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": "sts:AssumeRole",
     "Principal": {
       "Service": "ecs-tasks.amazonaws.com"
     },
     "Effect": "Allow",
     "Sid": ""
   }
 ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy_attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_cloudwatch_log_group" "logs" {
  name              = var.cloudwatch_group
  retention_in_days = var.logs_retention_in_days
}

resource "aws_ecs_task_definition" "demo_ecs" {
  family = "demo_ecs"
  requires_compatibilities = ["FARGATE"]
  network_mode = "awsvpc"
  cpu = "1024"
  memory = "2048"
  //Error: failed creating ECS Task Definition (demo_ecs): ClientException:
  //Fargate requires task definition to have execution role ARN to support log driver awslogs.
  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  container_definitions = jsonencode([
    {
      name      = "demo_ecs"
      image     = "${aws_ecr_repository.demo_ecs.repository_url}:latest"
      essential = true

      logConfiguration = {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": var.cloudwatch_group,
          "awslogs-region": var.region,
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ])
}

# Create new SNS topic
resource "aws_sns_topic" "s3_event_trigger_sns_topic" {
  name = "s3-event-trigger-sns-topic"
}

resource "aws_sqs_queue" "s3_event_trigger_sqs_queue" {
  name = "s3-event-trigger-sqs-queue"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": "*",
      "Action": "sqs:*",
      "Resource": "*"
    }
  ]
}
EOF
}

### S3 Resource Configuration ###
resource "aws_s3_bucket" "my-bucket" {
  bucket = local.bucket_name
}

resource "aws_s3_bucket_notification" "bucket-notification" {
  bucket      = aws_s3_bucket.my-bucket.id
  eventbridge = true
}

resource "aws_cloudwatch_event_rule" "trigger-ecs-for-s3-event-rule" {
  name        = "trigger-ecs-for-s3-event-rule"
  description = "Capture S3 events on uploads and delete objects from bucket"
  event_bus_name = local.event_bus_name
  event_pattern = <<EOF
{
  "source": ["aws.s3"],
  "detail-type": ["Object Created", "Object Deleted"],
  "detail": {
    "bucket": {
      "name": ["${local.bucket_name}"]
    }
  }
}
EOF
}

### Eventbridge Event Target ###
# The target is the glue between the event rule and the ECS task
# definition. This instructs Cloudwatch to run the ECS job when the # rule matches an event.
resource "aws_cloudwatch_event_target" "s3-event-ecs-target" {
  target_id = "s3-event-ecs-target"
  arn       = aws_ecs_cluster.test.id
  rule      = aws_cloudwatch_event_rule.trigger-ecs-for-s3-event-rule.name
  role_arn  = aws_iam_role.eventbridge-invoke-ecs-task-role.arn
  event_bus_name = local.event_bus_name

  ecs_target  {
    launch_type = "FARGATE"
    task_count          = 1 # Launch one container / event
    task_definition_arn = aws_ecs_task_definition.demo_ecs.arn
    # This is up to you, but FARGATE jobs need a public IP afaik
    network_configuration  {
      //subnets          = [ local.ecs_subnet_id ]
      subnets          =  data.aws_subnets.my_subnets.ids
      assign_public_ip = true
    }
  }
  input_transformer  {
    # This section plucks the values we need from the event
    input_paths = {
      s3_bucket_name   = "$.detail.bucket.name",
      s3_object_key    = "$.detail.object.key"
    }
    # This is the input template for the ECS task. The variables
    # defined in input_path above are available. This passes the
    # bucket name and object key as environment variables to the
    # task. The name has to match the containerDefinition of ecs task - refer above ecs task definition
    input_template = <<EOF
{
  "containerOverrides": [
    {
      "name": "demo_ecs",
      "environment" : [
        {
          "name" : "S3_BUCKET_NAME",
          "value" : <s3_bucket_name>
        },
        {
          "name" : "S3_OBJECT_KEY",
          "value" : <s3_object_key>
        },
#        {
#          "name" : "DETAIL_OBJECT",
#          "value" : { "detail": $.detail }
#        }
      ]
    }
  ]
}
EOF
  }
}

resource "aws_cloudwatch_event_target" "s3-event-sqs-target" {
  rule     = aws_cloudwatch_event_rule.trigger-ecs-for-s3-event-rule.name
  arn      = aws_sqs_queue.s3_event_trigger_sqs_queue.arn
}

### ECS Eventbridge Invocation Role ###
resource "aws_iam_role" "eventbridge-invoke-ecs-task-role" {
  name                = "eventbridge-invoke-ecs-task-role"
  managed_policy_arns = [aws_iam_policy.eventbridge-invoke-ecs-task-policy.arn]

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_policy" "eventbridge-invoke-ecs-task-policy" {
  name = "eventbridge-invoke-ecs-task-policy"

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "*"
        ],
        "Resource": [
          "${aws_ecs_task_definition.demo_ecs.arn}:*",
          "${aws_ecs_task_definition.demo_ecs.arn}"
        ],
        "Condition": {
          "ArnLike": {
            "ecs:cluster": "${aws_ecs_cluster.test.arn}"
          }
        }
      },
      {
        "Effect": "Allow",
        "Action": "iam:PassRole",
        "Resource": [
          "*"
        ],
        "Condition": {
          "StringLike": {
            "iam:PassedToService": "ecs-tasks.amazonaws.com"
          }
        }
      }
    ]
  })
}
