output "ecr_repo_url" {
  description = "ECR Repository URL"
  value = aws_ecr_repository.demo_ecs.repository_url
}