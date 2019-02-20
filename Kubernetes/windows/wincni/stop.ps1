
taskkill /im kubelet.exe /f
taskkill /im kube-proxy.exe /f

$BaseDir = "c:\k"
$helper = "c:\k\helper.psm1"
ipmo $helper
CleanupContainers