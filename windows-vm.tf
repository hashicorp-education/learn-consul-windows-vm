data "template_file" "consul_setup" {
  template = <<EOF
  <powershell>
<powershell>
netsh advfirewall set publicprofile state off
mkdir C:\Consul
mkdir C:\Consul\config
mkdir C:\Consul\certs

# install Consul binary
cd C:\Consul
Invoke-WebRequest -Uri https://releases.hashicorp.com/consul/1.12.0/consul_1.12.0_windows_amd64.zip -OutFile consul_1.12.0_windows_amd64.zip
Expand-Archive consul_1.12.0_windows_amd64.zip
Move-Item -Path C:\Consul\consul_1.12.0_windows_amd64\consul.exe -Destination C:\Consul

## Set to path
# setx requires admin permissions
setx /M PATH "$env:path;C:\Consul"
$ENV:PATH="$ENV:PATH;C:\Consul"

## Install Docker for envoy
Invoke-WebRequest -UseBasicParsing "https://raw.githubusercontent.com/microsoft/Windows-Containers/Main/helpful_tools/Install-DockerCE/install-docker-ce.ps1" -o install-docker-ce.ps1
.\install-docker-ce.ps1
</powershell>
EOF
}

data "aws_ami" "windows_2019" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["Windows_Server-2019-English-Full-Base*"]
  }
}

# Create EC2 Instance
resource "aws_instance" "consul_server_windows" {
  ami                         = data.aws_ami.windows_2019.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.allow_all_traffic.id]
  associate_public_ip_address = var.associate_public_ip_address
  source_dest_check           = false
  key_name                    = aws_key_pair.ssh.key_name
  user_data                   = data.template_file.consul_setup.rendered

  # root disk
  root_block_device {
    volume_size           = var.windows_root_volume_size
    volume_type           = var.windows_root_volume_type
    delete_on_termination = true
    encrypted             = true
  }

  # extra disk
  ebs_block_device {
    device_name           = "/dev/xvda"
    volume_size           = var.windows_data_volume_size
    volume_type           = var.windows_data_volume_type
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name = "${local.name}-consul-server-windows"
  }
}

resource "aws_eip" "consul_server_windows" {
  vpc = true
  tags = {
    Name = "${local.name}-eip"
  }
}

resource "aws_eip_association" "windows_eip_association" {
  instance_id   = aws_instance.consul_server_windows.id
  allocation_id = aws_eip.consul_server_windows.id
}
