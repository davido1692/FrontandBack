variable "cluster_id" {}
variable "service_name" {}
variable "container_image" {}
variable "container_port" { type = number }
variable "private_subnets" { type = list(string) }
variable "task_execution_role_arn" {}
variable "target_group_arn" {}
variable "security_group_ids" { type = list(string) }
variable "listener_arn" { type = string }
variable "environment" {
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}
