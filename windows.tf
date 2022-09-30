data "aws_ssm_parameter" "agent_windows_ami" {
  name = "/aws/service/ami-windows-latest/Windows_Server-2019-English-Full-Base"
}

resource "aws_security_group" "hcp_consul_ec2" {
  name_prefix = "hcp_consul_ec2"
  description = "HCP Consul security group"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow RDP inbound"
  }

  ingress {
    from_port   = 21000
    to_port     = 21000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP inbound on port 21000 (Consul sidecar listening)"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP inbound on port 80"
  }

  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP inbound on port 9090 (fakeservice)"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow outgoing traffic"
  }
}

resource "tls_private_key" "instance_key" {
  algorithm = "RSA"
}

resource "aws_key_pair" "instance_key_pair" {
  key_name   = "${local.name}-instance-key"
  public_key = tls_private_key.instance_key.public_key_openssh
}

resource "aws_instance" "fakeservice" {
  for_each        = toset([
    for s in fileset(path.module, "services/*.json"): 
      trimsuffix(replace(s, "services/", ""), ".json")
  ])
  ami           = nonsensitive(data.aws_ssm_parameter.agent_windows_ami.value)
  instance_type = "t2.medium"

  subnet_id              = module.vpc.public_subnets[0]
  vpc_security_group_ids = [module.aws_hcp_consul.security_group_id, aws_security_group.hcp_consul_ec2.id]
  key_name               = aws_key_pair.instance_key_pair.key_name
  get_password_data      = true
  user_data = templatefile("${path.module}/templates/consul-client-agent.tpl",
    merge(var.consul_base_folders, {
      envoy_folder        = "envoy"
      hashicups_folder    = "hashicups"
      consul_download_url = var.consul_url
      node_name           = each.key
      service_definition  = file("${path.module}/services/${each.key}.json")
      fakeservice_url     = var.fakeservice_url
      consul_token        = hcp_consul_cluster_root_token.token.secret_id
      consul_ca           = base64decode(hcp_consul_cluster.main.consul_ca_file)
      config_file         = base64decode(hcp_consul_cluster.main.consul_config_file)
      envoy_url           = var.envoy_url
    })
  )
  tags = {
    Name = "fakeservice-${each.key}"
  }
}