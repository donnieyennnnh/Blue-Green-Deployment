# variables.tf — all inputs. Defaults are chosen so you only need to set
# the ones unique to you (your IP, your SSH key path).

variable "aws_profile" {
  description = "Named AWS CLI profile with the terraform-blue-green credentials."
  type        = string
  default     = "blue-green"
}

variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "Prefix for resource names and value of the Project tag."
  type        = string
  default     = "bobross-gallery"
}

variable "environment" {
  description = "Value of the Environment tag."
  type        = string
  default     = "dev"
}

variable "my_ip_cidr" {
  description = <<-EOT
    Your public IP in CIDR form, used to lock SSH ingress to just you.
    Find it with:  curl ifconfig.me   then append /32.
    Must be set in terraform.tfvars — no default so you can't forget.
  EOT
  type = string

  validation {
    condition     = can(regex("^(\\d{1,3}\\.){3}\\d{1,3}/\\d{1,2}$", var.my_ip_cidr))
    error_message = "my_ip_cidr must look like 203.0.113.42/32"
  }
}

variable "instance_type" {
  description = "EC2 instance type. t3.micro is free-tier eligible for 12 months."
  type        = string
  default     = "t3.micro"
}

variable "ssh_public_key_path" {
  description = <<-EOT
    Path to the SSH *public* key to register with AWS. Generate the pair with:
      ssh-keygen -t ed25519 -f ~/.ssh/bobross-gallery
    Tilde expansion is handled automatically.
  EOT
  type    = string
  default = "~/.ssh/bobross-gallery.pub"
}
