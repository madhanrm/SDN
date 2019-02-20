Param(
    [ValidateSet("l2bridge", "overlay",IgnoreCase = $true)] [parameter(Mandatory = $true)] $NetworkMode,
    [parameter(Mandatory = $true)] $NetworkName,  
    [parameter(Mandatory = $false)] [Switch]  $IsDsr,
    [parameter(Mandatory = $false)] $clusterCIDR="10.244.0.0/16",  
    [parameter(Mandatory = $false)] $BaseDir = "C:\k"
)
$Global:BaseDir = $BaseDir

$networkName = $NetworkName.ToLower()
$networkMode = $NetworkMode.ToLower()

$helper = [io.Path]::Join($Global:BaseDir, "helper.psm1")
ipmo $helper

CleanupPolicyList

if ($NetworkMode -eq "l2bridge")
{
    $env:KUBE_NETWORK=$networkName

    StartKubeProxy -KubeConfig $(GetKubeConfig) `
            -NetworkName $networkName -ClusterCIDR  $clusterCIDR `
            -IsDsr:$IsDsr.IsPresent
}
elseif ($NetworkMode -eq "overlay")
{
    $sourceVipJsonPath = [io.Path]::Join($Global:BaseDir, "sourceVip.json")
    if((Test-Path $sourceVipJsonPath)) 
    {
        $sourceVipJSON = Get-Content $sourceVipJsonPath | ConvertFrom-Json 
        $sourceVip = $sourceVipJSON.ip4.ip.Split("/")[0]
    }

    StartKubeProxy -KubeConfig $(GetKubeConfig) `
            -NetworkName $networkName -ClusterCIDR  $clusterCIDR `
            -SourceVip $sourceVip `
            -ProxyFeatureGates "WinOverlay=true" -IsDsr:$IsDsr.IsPresent
}