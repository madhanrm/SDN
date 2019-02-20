Param(
    $clusterCIDR="192.168.0.0/16",
    $NetworkMode = "L2Bridge",
    $NetworkName = "l2bridge",
    [ValidateSet("process", "hyperv")]
    $IsolationType = "process",
    [parameter(Mandatory = $false)] $InterfaceName="Ethernet",
    [parameter(Mandatory = $false)] $BaseDir = "C:\k",
)

##############################################################################################
# Todo : Get these values using kubectl
$KubeDnsSuffix ="svc.cluster.local"
$KubeDnsServiceIp="11.0.0.10"
$serviceCIDR="11.0.0.0/8"

$WorkingDir = "c:\k"
$CNIPath = [Io.path]::Combine($WorkingDir , "cni")
$CNIConfig = [Io.path]::Combine($CNIPath, "config", "$NetworkMode.conf")

$endpointName = "cbr0"
$vnicName = "vEthernet ($endpointName)"

ipmo $WorkingDir\helper.psm1
$Global:BaseDir = $BaseDir

##############################################################################################

# Main

RegisterNode
$podCIDR = Get-PodCIDR

# startup the service
$podGW = Get-PodGateway $podCIDR
ipmo C:\k\hns.psm1

# Create a L2Bridge to trigger a vSwitch creation. Do this only once
if(!(Get-HnsNetwork | ? Name -EQ "External"))
{
    New-HNSNetwork -Type $NetworkMode -AddressPrefix "192.168.255.0/30" -Gateway "192.168.255.1" -Name "External" -Verbose
}

$hnsNetwork = Get-HnsNetwork | ? Name -EQ $NetworkName.ToLower()
if( !$hnsNetwork )
{
    $hnsNetwork = New-HNSNetwork -Type $NetworkMode -AddressPrefix $podCIDR -Gateway $podGW -Name $NetworkName.ToLower() -Verbose
}

$mgmtIp = ${hnsNetwork}.ManagementIp
$podEndpointGW = Get-PodEndpointGateway $podCIDR
$hnsEndpoint = New-HnsEndpoint -NetworkId $hnsNetwork.Id -Name $endpointName -IPAddress $podEndpointGW -Gateway "0.0.0.0" -Verbose
Attach-HnsHostEndpoint -EndpointID $hnsEndpoint.Id -CompartmentID 1

netsh int ipv4 set int "$vnicName" for=en
#netsh int ipv4 set add "vEthernet (cbr0)" static $podGW 255.255.255.0
Update-CNIConfig -podCIDR $podCIDR -CNIConfig  $CNIConfig `
                -clusterCIDR $clusterCIDR -KubeDnsServiceIP $KubeDnsServiceIP `
                -serviceCIDR $serviceCIDR -InterfaceName $InterfaceName -NetworkName $NetworkName

$KubeletFeatureGates = ""

if ($IsolationType -ieq "hyperv")
{
  $KubeletFeatureGates = "HyperVContainer=true"
}

StartKubelet -KubeConfig $(GetKubeConfig) `
            -CniDir $(GetCniPath) -CniConf $(GetCniConfPath) `
            -KubeDnsServiceIp $KubeDnsServiceIp -NodeIp $mgmtIp `
            -KubeletFeatureGates $KubeletFeatureGates
