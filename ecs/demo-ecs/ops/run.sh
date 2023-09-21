cd ..
pwd

echo "Setting java home"
export JAVA_HOME=/Users/mitanandeesh/Library/Java/JavaVirtualMachines/corretto-11.0.14/Contents/Home
export PATH=$JAVA_HOME/bin:$PATH

java --version

echo "gradle clean"
./gradlew clean
echo "gradle build"
./gradlew build

echo "docker image remove"
docker image rm -f nandeeshsu/demo-ecs

echo "docker build"
docker build -t nandeeshsu/demo-ecs .

echo "cd ops/terraform"
cd ops/terraform || exit
pwd

echo "terraform destroy"
#terraform destroy -auto-approve

echo "terraform state remove"
#terraform state rm
#rm terraform.tfstate

echo "terraform apply"
terraform apply -auto-approve || exit
ecr_repo_url=$(terraform output -raw ecr_repo_url) || exit

echo "docker tag"
docker tag nandeeshsu/demo-ecs:latest ${ecr_repo_url}:latest

echo "ecr auth"
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ${ecr_repo_url}
echo "ecr image push"
docker push ${ecr_repo_url}:latest || exit
