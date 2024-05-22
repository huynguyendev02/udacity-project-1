variable "resource_group_name" {
  type = string
}
variable "subscription_id" {
  type = string
}
variable "location" {
  type = string
}

variable "vm_count" {
  type = number
}

variable "image_id" {
  type = string
}

variable "admin_password" {
  description = "The password for the admin account"
  sensitive   = true
}
