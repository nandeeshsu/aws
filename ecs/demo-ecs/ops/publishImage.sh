ecr_repo_url=$(terraform output -raw ecr_repo_url) || exit

echo "docker tag"
docker tag nandeeshsu/demo-ecs:latest ${ecr_repo_url}:latest

echo "ecr auth"
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ${ecr_repo_url}
echo "ecr image push"
docker push ${ecr_repo_url}:latest || exit
