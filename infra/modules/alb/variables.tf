variable "vpc_id" {}
variable "public_subnets" { type = list(string) }
variable "security_group_ids" { type = list(string) }
variable "name" { default = "app-alb" }