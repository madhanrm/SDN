Param(
    $NetworkName = "cbr0",
    [parameter(Mandatory = $false)] $BaseDir = "C:\k",
    [parameter(Mandatory = $false)] $clusterCIDR="192.168.0.0/16",
    [parameter(Mandatory = $false)] $ProxyFeatureGates = ""
)

$helper = [io.Path]::Join($Global:BaseDir, "helper.psm1")
ipmo $helper

CleanupPolicyList

$networkName = $NetworkName.ToLower()

$featureGates = "WinDSR=false"
StartKubeProxy -KubeConfig $(GetKubeConfig) `
            -NetworkName $networkName -ClusterCIDR  $clusterCIDR `
            -ProxyFeatureGates $featureGates -IsDsr:$IsDsr.IsPresent