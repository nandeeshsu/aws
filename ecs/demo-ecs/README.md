
docker build -t nandeeshsu/demo-ecs .
docker tag nandeeshsu/demo-ecs:latest 522911216413.dkr.ecr.us-east-1.amazonaws.com/demo_ecs

aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 522911216413.dkr.ecr.us-east-1.amazonaws.com/demo_ecs
docker push 522911216413.dkr.ecr.us-east-1.amazonaws.com/demo_ecs:latest

remove the images without tag
docker rmi $(docker images -f dangling=true -q)


terraform import aws_cloudwatch_event_rule.import_example_rule test
terraform import aws_cloudwatch_event_rule.import_example_rule <EVENTBUSNAME>/<RULENAME>

git clone https://github.com/aws-samples/serverless-patterns/
cd serverless-patterns/s3-eventbridge-ecs