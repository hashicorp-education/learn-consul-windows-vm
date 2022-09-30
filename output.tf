output "password_data" {
  value = {
    for service, resource in aws_instance.fakeservice : service => rsadecrypt(resource.password_data, tls_private_key.instance_key.private_key_pem)
  }
  sensitive = true
}

output "fakeservice_addresses" {
  value = {
    for service, resource in aws_instance.fakeservice : service => "http://${resource.public_ip}:9090"
  }
}

output "consul_url" {
  value = hcp_consul_cluster.main.consul_public_endpoint_url
}

output "consul_root_token" {
  value     = hcp_consul_cluster_root_token.token.secret_id
  sensitive = true
}

# output "helm_values" {
#   value = module.eks_consul_client.helm_values
# }
