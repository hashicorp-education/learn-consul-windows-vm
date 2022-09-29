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

# Run Consul server
$serverConfigFile = "C:\Consul\config\server.json"
New-Item $serverConfigFile -ItemType File
$serverConfigContent = @"
{
  "datacenter": "dc1",
  "data_dir": "C:\\Consul",
  "log_level": "INFO",
  "node_name": "server-1",
  "server": true,
  "bootstrap_expect": 1,
  "client_addr": "0.0.0.0",
  "bootstrap": true,
  "ui": true,
  "connect": {
    "enabled": true
  },
  "log_file" : "C:\\Consul\\consul.log" 
}
"@
Add-Content $serverConfigFile $serverConfigContent
# Start-Job -ScriptBlock{ consul agent -config-dir="C:\Consul\config" }
Start-Process -NoNewWindow -FilePath "C:\Consul\consul" -ArgumentList "agent -config-dir=`"C:\Consul\config`""

## Install Docker for Envoy
# Invoke-WebRequest -UseBasicParsing "https://raw.githubusercontent.com/microsoft/Windows-Containers/Main/helpful_tools/Install-DockerCE/install-docker-ce.ps1" -o install-docker-ce.ps1
# .\install-docker-ce.ps1
# Install-Module -Name DockerMsftProvider -Repository PSGallery -Force
# Install-Package -Name docker -ProviderName DockerMsftProvider -Force
# Restart-Computer -Force

## Start Envoy
# docker pull envoyproxy/envoy-windows-dev:63f27a6b6de0b2172f4721c31c69a050713c4c56
# docker run --rm envoyproxy/envoy-windows-dev:63f27a6b6de0b2172f4721c31c69a050713c4c56 --version

# # Install Git
# # https://stackoverflow.com/questions/46731433/how-to-download-and-install-git-client-for-window-using-powershell
# $git_url = "https://api.github.com/repos/git-for-windows/git/releases/latest"
# $asset = Invoke-RestMethod -Method Get -Uri $git_url | % assets | where name -like "*64-bit.exe"
# # download installer
# $installer = "$env:temp\$($asset.name)"
# Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $installer
# # run installer
# $git_install_inf = "<install inf file>"
# $install_args = "/SP- /VERYSILENT /SUPPRESSMSGBOXES /NOCANCEL /NORESTART /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS /LOADINF=""$git_install_inf"""
# Start-Process -FilePath $installer -ArgumentList $install_args -Wait

# # Clone Envoy repo
# cd C:\
# git clone https://github.com/envoyproxy/envoy

# # Install Bazel (Bazelisk)
# mkdir C:\bazel
# Invoke-WebRequest https://github.com/bazelbuild/bazelisk/releases/latest/download/bazelisk-windows-amd64.exe -OutFile C:\bazel\bazel.exe
# setx /M PATH "$env:path;C:\bazel"
# $ENV:PATH="$ENV:PATH;C:\bazel"

# # Build Envoy
# cd C:\envoy
# bazel build -c opt envoy
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
