<powershell>
# Configure firewall rules
netsh advfirewall set publicprofile state off

# Install chocolatey and others
[System.Net.ServicePointManager]::SecurityProtocol = 3072

$NODE_NAME="${node_name}"
$CONSUL_PATH="C:\${consul_folder}"
$CONSUL_CONFIG_PATH="C:\${consul_folder}\${consul_config_folder}"
$CONSUL_DATA_PATH="C:\${consul_folder}\data"
$CONSUL_LOG_PATH="C:\${consul_folder}\consul.log"
$CONSUL_CERTS_PATH="C:\${consul_folder}\${consul_certs_folder}"
$ENVOY_PATH="C:\${envoy_folder}"
$HASHICUPS_PATH="C:\${hashicups_folder}"
$FAKESERVICE_PATH="C:\Fake"

New-Item -type directory $CONSUL_PATH
New-Item -type directory $CONSUL_CONFIG_PATH
New-Item -type directory $CONSUL_CERTS_PATH
New-Item -type directory $ENVOY_PATH
New-Item -type directory $HASHICUPS_PATH
New-Item -type directory $CONSUL_DATA_PATH
New-Item -type directory $FAKESERVICE_PATH

# Download Consul    
cd $CONSUL_PATH
Invoke-WebRequest -Uri ${consul_download_url} -OutFile consul.zip
Expand-Archive consul.zip -DestinationPath . 

# Download Envoy
cd $ENVOY_PATH
Invoke-WebRequest -Uri ${envoy_url} -OutFile envoy.exe

# Add Consul and Envoy to path
$env:path =  $env:path + ";" + $CONSUl_PATH + ";" + $ENVOY_PATH
[System.Environment]::SetEnvironmentVariable('Path', $env:path,[System.EnvironmentVariableTarget]::User)
[System.Environment]::SetEnvironmentVariable('Path', $env:path,[System.EnvironmentVariableTarget]::Machine)

# Download the service definitions from KV store
cd $CONSUL_CONFIG_PATH

# Create Consul client configuration file
@"
${config_file}
"@ | Set-Content consul.json -Force

# Create Consul service definitions
@"
${service_definition}
"@ | Set-Content service.json -Force

# Copy certificate authority files
@"
${consul_ca} 
"@ | Out-File ca.pem -NoNewline -Encoding utf8

# Add ACL token and grpc and change path to ca.pem
$consulJsonConfig = Get-Content .\consul.json -Raw | ConvertFrom-Json
$tokenConfig = @{"agent"="${consul_token}"}
$grpcConfig = @{"grpc"= 8502}
$consulJsonConfig | Add-Member -Type NoteProperty -Name 'ports' -value $grpcConfig
$consulJsonConfig.Acl | Add-Member -Type NoteProperty -Name 'tokens' -value $tokenConfig
$consulJsonConfig.ca_file = $CONSUL_CONFIG_PATH + "\ca.pem"
$consulJsonConfig | ConvertTo-Json -Depth 6 | Set-Content consul.json

$serviceJson = Get-Content .\service.json -Raw | ConvertFrom-Json
$serviceJson.service | Add-Member -Type NoteProperty -Name 'token' -value "${consul_token}"
$serviceJson | ConvertTo-Json -Depth 6 | Set-Content service.json

# Start Consul
$consulservice = @{
  Name = "consul"
  BinaryPathName = "c:\consul\consul.exe agent -node " + $NODE_NAME + " -config-dir=$CONSUL_CONFIG_PATH -log-file=$CONSUL_LOG_PATH -data-dir=$CONSUL_DATA_PATH"
  DisplayName = "Consul"
  StartupType = "Automatic"
  Description = "The consul service"
}
New-Service @consulservice
Start-Service "consul"

## Set up fakeservice
# Download fakeservice
cd $FAKESERVICE_PATH
Invoke-WebRequest -Uri ${fakeservice_url} -OutFile fakeservice.zip
Expand-Archive fakeservice.zip -DestinationPath . 

# Add fakeservice to path
$env:path =  $env:path + ";" + $FAKESERVICE_PATH
[System.Environment]::SetEnvironmentVariable('Path', $env:path,[System.EnvironmentVariableTarget]::User)
[System.Environment]::SetEnvironmentVariable('Path', $env:path,[System.EnvironmentVariableTarget]::Machine)

# Set up fakeservice env variables
$env:LISTEN_ADDR="0.0.0.0:9090"
if ($NODE_NAME -eq "fakeservice-frontend") {
  $env:UPSTREAM_URIS="http://localhost:8080"
}
$env:NAME=$NODE_NAME

# Start fakeservice and envoy
Start-Process fake-service -RedirectStandardOutput .\console.out -RedirectStandardError .\console.err
consul.exe connect envoy -sidecar-for=${node_name} -token=${consul_token} -admin-access-log-path="C:\/envoy\/back.log" -bootstrap | Set-Content c:\envoy\envoy.json -Force
Start-Process envoy.exe -ArgumentList '-c','c:\envoy\envoy.json' -RedirectStandardOutput c:\envoy\console.out -RedirectStandardError c:\envoy\console.err

</powershell>