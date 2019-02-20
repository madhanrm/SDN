
Param(
    [ValidateSet("l2bridge", "overlay",IgnoreCase = $true)] [parameter(Mandatory = $false)] $NetworkMode="l2bridge",
    [ValidateSet("1.14.0-beta.1", "1.13.0")] [parameter(Mandatory = $true)] $KubernetesRelease = "1.13.0",
    [parameter(Mandatory = $true)] $ClusterCIDR,
    [parameter(Mandatory = $true)] $KubeDnsServiceIP,
    [parameter(Mandatory = $true)] $ServiceCIDR,
    [parameter(Mandatory = $true)] $InterfaceName,
    [parameter(Mandatory = $false)] $BaseDir = "C:\k",
    [parameter(Mandatory = $false)] $KubeletFeatureGates = ""
)

function DownloadWindowsKubernetesScripts()
{
    Write-Host "Downloading Windows Kubernetes scripts"
    DownloadFile -Url "https://github.com/$Global:GithubSDNRepository/raw/master/Kubernetes/windows/hns.psm1" -Destination $BaseDir\hns.psm1
    DownloadFile -Url "https://github.com/$Global:GithubSDNRepository/raw/master/Kubernetes/windows/InstallImages.ps1" -Destination $BaseDir\InstallImages.ps1
    DownloadFile -Url "https://github.com/$Global:GithubSDNRepository/raw/master/Kubernetes/windows/Dockerfile" -Destination $BaseDir\Dockerfile
    DownloadFile -Url "https://github.com/$Global:GithubSDNRepository/raw/master/Kubernetes/windows/wincni/stop.ps1" -Destination $BaseDir\stop.ps1
    DownloadFile -Url "https://github.com/$Global:GithubSDNRepository/raw/master/Kubernetes/windows/wincni/start-kubelet.ps1" -Destination $BaseDir\start-kubelet.ps1
    DownloadFile -Url "https://github.com/$Global:GithubSDNRepository/raw/master/Kubernetes/windows/start-kubeproxy.ps1" -Destination $BaseDir\start-Kubeproxy.ps1
    DownloadFile -Url "https://github.com/$Global:GithubSDNRepository/raw/master/Kubernetes/windows/wincni/AddRoutes.ps1" -Destination $BaseDir\AddRoutes.ps1
}

function InstallKubenetBinaries()
{
    DownloadCniBinaries
    DownloadWindowsKubernetesScripts
}

############################################################
md $BaseDir -ErrorAction Ignore

$_GithubSDNRepository = 'Microsoft/SDN'
if ((Test-Path env:GITHUB_SDN_REPOSITORY) -and ($env:GITHUB_SDN_REPOSITORY -ne ''))
{
    $_GithubSDNRepository = $env:GITHUB_SDN_REPOSITORY
}

$helper = "$BaseDir\helper.psm1"
if (!(Test-Path $helper))
{
    Start-BitsTransfer "https://raw.githubusercontent.com/$Global:GithubSDNRepository/master/Kubernetes/windows/helper.psm1" -Destination $BaseDir\helper.psm1
}
ipmo $helper -DisableNameChecking
$Global:GithubSDNRepository = $_GithubSDNRepository
$Global:BaseDir = $Destination

###############################################################
$masterIp = ""

# Install kubenet binaries
InstallKubenetBinaries

# Prepare POD infra Images
InstallPauseImage

# Prepare Network & Start Infra services
if ($NetworkMode -eq "overlay")
{
    throw "Overlay not supported for Kubenet. Use Flannel"
}

# WinCni needs the networkType and network name to be the same
$NetworkName = "l2bridge"

CleanupOldNetwork $NetworkName

Start powershell -ArgumentList "-File $BaseDir\start-kubelet.ps1 -clusterCIDR $clusterCIDR -NetworkName $NetworkName -BaseDir $Global:BaseDir"

WaitForNetwork $NetworkName

start powershell -ArgumentList " -File $BaseDir\start-kubeproxy.ps1 -NetworkName $NetworkName"

powershell -File $BaseDir\AddRoutes.ps1 -masterIp $masterIp