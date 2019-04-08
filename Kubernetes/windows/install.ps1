Param(
    [ValidateSet("l2bridge", "overlay",IgnoreCase = $true)] [parameter(Mandatory = $true)] $NetworkMode,
    [parameter(Mandatory = $false)] $clusterCIDR="10.244.0.0/16",
    [parameter(Mandatory = $false)] $KubeDnsServiceIP="10.96.0.10",
    [parameter(Mandatory = $false)] $serviceCIDR="10.96.0.0/12",
    [parameter(Mandatory = $false)] $InterfaceName="Ethernet",
    [parameter(Mandatory = $false)] $LogDir = "C:\k"
)

$GithubSDNRepository = 'Microsoft/SDN'
if ((Test-Path env:GITHUB_SDN_REPOSITORY) -and ($env:GITHUB_SDN_REPOSITORY -ne ''))
{
    $GithubSDNRepository = $env:GITHUB_SDN_REPOSITORY
}

$NetworkName = "cbr0"
if ($NetworkMode -eq "overlay")
{
    $NetworkName = "vxlan0"
}

function SetupDirectories($LogDir)
{
    Write-Host "Creating Kubernetes directories"
    md $BaseDir -ErrorAction Ignore
    md $LogDir -ErrorAction Ignore
    md c:\flannel -ErrorAction Ignore
    md $BaseDir\cni\config -ErrorAction Ignore
    md C:\etc\kube-flannel -ErrorAction Ignore
}

function CopyFiles()
{
    Write-Host "Copying Flannel setup files"
    cp $BaseDir\flanneld.exe c:\flannel\flanneld.exe
    cp $BaseDir\net-conf.json C:\etc\kube-flannel\net-conf.json
}

function DownloadWindowsKubernetesScripts
{
    Write-Host "Downloading Windows Kubernetes scripts"
    DownloadFile -Url "https://github.com/$GithubSDNRepository/raw/master/Kubernetes/windows/hns.psm1" -Destination $BaseDir\hns.psm1
    DownloadFile -Url "https://github.com/$GithubSDNRepository/raw/master/Kubernetes/windows/InstallImages.ps1" -Destination $BaseDir\InstallImages.ps1
    DownloadFile -Url "https://github.com/$GithubSDNRepository/raw/master/Kubernetes/windows/Dockerfile" -Destination $BaseDir\Dockerfile
    DownloadFile -Url "https://github.com/$GithubSDNRepository/raw/master/Kubernetes/flannel/stop.ps1" -Destination $BaseDir\stop.ps1
    DownloadFile -Url "https://github.com/$GithubSDNRepository/raw/master/Kubernetes/flannel/start-kubelet.ps1" -Destination $BaseDir\start-kubelet.ps1
    DownloadFile -Url "https://github.com/$GithubSDNRepository/raw/master/Kubernetes/flannel/start-kubeproxy.ps1" -Destination $BaseDir\start-Kubeproxy.ps1
}

function DownloadAllFiles($NetworkMode)
{
    DownloadWindowsKubernetesScripts
    DownloadFlannelBinaries
    DownloadCniBinaries($NetworkMode)
}

# Setup directories
$BaseDir = "c:\k"
$NetworkMode = $NetworkMode.ToLower()
$helper = "c:\k\helper.psm1"

if (!(Test-Path $helper))
{
    Start-BitsTransfer "https://raw.githubusercontent.com/$GithubSDNRepository/master/Kubernetes/windows/helper.psm1" -Destination c:\k\helper.psm1
}
ipmo $helper

SetupDirectories($LogDir)

# Download files into Kubernetes base directory
DownloadAllFiles($NetworkMode)

# Copy files into runtime directories
CopyFiles

# Prepare POD infra Images
start powershell $BaseDir\InstallImages.ps1

# Prepare Network
ipmo C:\k\hns.psm1
CleanupOldNetwork $NetworkName
CreateExternalNetwork $NetworkMode
Start-Sleep 10

# Update CNI config files
# Todo : Get these values using kubectl
$WorkingDir = "c:\k"
$CNIPath = [Io.path]::Combine($WorkingDir , "cni")
$CNIConfig = [Io.path]::Combine($CNIPath, "config", "cni.conf")
$NetConfig = [Io.path]::Combine($WorkingDir , "net-conf.json")
Update-CNIConfig $CNIConfig $clusterCIDR $KubeDnsServiceIP $serviceCIDR $InterfaceName $NetworkName $NetworkMode
Update-NetConfig $NetConfig $clusterCIDR $NetworkName $NetworkMode