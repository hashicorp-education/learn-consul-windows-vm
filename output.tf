output "password_data_backend" {
  value = rsadecrypt(aws_instance.fakeservice[0].password_data, tls_private_key.instance_key
  .private_key_pem)
  sensitive = true
}

output "password_data_frontend" {
  value = rsadecrypt(aws_instance.fakeservice[1].password_data, tls_private_key.instance_key
  .private_key_pem)
  sensitive = true
}

output "fs_backend_public_ip" {
  value = aws_instance.fakeservice[0].public_ip
}

output "fs_frontend_public_ip" {
  value = aws_instance.fakeservice[1].public_ip
}

output "consul_url" {
  value = hcp_consul_cluster.main.consul_public_endpoint_url
}

output "consul_token" {
  value     = hcp_consul_cluster_root_token.token.secret_id
  sensitive = true
}

# output "helm_values" {
#   value = module.eks_consul_client.helm_values
# }
