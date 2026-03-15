variable "cluster_name" {}

resource "aws_ecs_cluster" "main" {
  name = var.cluster_name
}

resource "aws_iam_role" "task_execution" {
  name = "${var.cluster_name}-task-exec"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "task_exec_attach" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

output "cluster_id" { value = aws_ecs_cluster.main.id }
output "task_execution_role_arn" { value = aws_iam_role.task_execution.arn }
