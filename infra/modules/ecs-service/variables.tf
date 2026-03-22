variable "cluster_id" {}
variable "service_name" {}
variable "container_image" {}
variable "container_port" { type = number }
variable "private_subnets" { type = list(string) }
variable "task_execution_role_arn" {}
variable "target_group_arn" {
  default = null
}
variable "security_group_ids" { type = list(string) }
variable "listener_arn" {
  type    = string
  default = null
}
variable "environment" {
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}
