Param(
    [ValidateSet("l2bridge", "overlay",IgnoreCase = $true)] [parameter(Mandatory = $true)] $NetworkMode,
    [parameter(Mandatory = $false)] $KubeDnsServiceIP="10.96.0.10",
    [parameter(Mandatory = $false)] $BaseDir = "C:\k",
    [parameter(Mandatory = $false)] $KubeletFeatureGates = "",
    [switch] $RegisterOnly
)

$Global:BaseDir = $BaseDir

$GithubSDNRepository = 'Microsoft/SDN'
if ((Test-Path env:GITHUB_SDN_REPOSITORY) -and ($env:GITHUB_SDN_REPOSITORY -ne ''))
{
    $GithubSDNRepository = $env:GITHUB_SDN_REPOSITORY
}

$helper = [io.Path]::Join($Global:BaseDir, "helper.psm1")
if (!(Test-Path $helper))
{
    Start-BitsTransfer "https://raw.githubusercontent.com/$GithubSDNRepository/master/Kubernetes/windows/helper.psm1" -Destination c:\k\helper.psm1
}
ipmo $helper

if ($RegisterOnly.IsPresent)
{
    RegisterNode
    exit
}

StartKubelet -KubeConfig $(GetKubeConfig) `
            -CniDir $(GetCniPath) -CniConf $(GetCniConfPath) `
            -KubeDnsServiceIp $KubeDnsServiceIp -NodeIp $(Get-MgmtIpAddress) `
            -KubeletFeatureGates $KubeletFeatureGates
