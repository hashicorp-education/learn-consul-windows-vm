
output "consul_server_public_ip" {
  value = aws_eip.consul_server_windows.public_ip
}

output "consul_server_private_ip" {
  value = aws_instance.consul_server_windows.private_ip
}