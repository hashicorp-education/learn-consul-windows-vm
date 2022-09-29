variable "region" {
  default = "us-west-2"
}

variable "name" {
  default = "learn-consul-windows-vm"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "subnet_cidr" {
  default = "10.0.1.0/24"
}

variable "instance_type" {
  default = "t2.micro"
}

variable "associate_public_ip_address" {
  default = "true"
}

variable "windows_root_volume_size" {
  default = "30"
}

variable "windows_data_volume_size" {
  default = "10"
}

variable "windows_root_volume_type" {
  default = "gp2"
}

variable "windows_data_volume_type" {
  default = "gp2"
}