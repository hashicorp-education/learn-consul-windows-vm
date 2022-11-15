variable "hvn_region" {
  default = "us-west-2"
}

variable "vpc_region" {
  default = "us-west-2"
}

variable "name_prefix" {
  default = "learn-consul-windows"
}

variable "consul_base_folders" {
  type        = map(string)
  description = "Consul folders structure"
  default = {
    consul_folder        = "consul"
    consul_config_folder = "config"
    consul_certs_folder  = "certs"
  }
}
variable "consul_url" {
  type        = string
  description = "Consul URL"
  default     = "https://consul-windows-preview.s3.us-west-2.amazonaws.com/consul/consul_1.15.0_windows_amd64.zip"
}

variable "envoy_url" {
  default = "https://consul-windows-preview.s3.us-west-2.amazonaws.com/envoy/v1.23/envoy.exe"
}

variable "fakeservice_url" {
  default = "https://github.com/nicholasjackson/fake-service/releases/download/v0.24.2/fake_service_windows_amd64.zip"
}
