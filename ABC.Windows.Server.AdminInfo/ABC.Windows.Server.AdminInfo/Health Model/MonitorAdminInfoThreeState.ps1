param($MonitorItem,$Threshold,$ComputerName)
$api = New-Object -ComObject 'MOM.ScriptAPI'

$Global:Error.Clear()
$ErrorActionPreference = 'Continue'

$testedAt = "Tested on: $(Get-Date -Format u) / $(([TimeZoneInfo]::Local).DisplayName)"

#$api.LogScriptEvent('Monitor AdminInfo Three State.ps1',9001,4,"MonitorAdminInfoThreeState Computer: $($ComputerName) - MonitorItem $($MonitorItem)")

if ($MonitorItem -eq 'Share') {

	$classAdminInfoShare          = Get-SCOMClass -Name 'ABC.Windows.Server.AdminInfo.Share'
	$classAdminInfoShareInstances = Get-SCOMClassInstance -Class $classAdminInfoShare		
		
	foreach ($adminInfoShare in $classAdminInfoShareInstances) {
		
		$Key              = $adminInfoShare.'[ABC.Windows.Server.AdminInfo.Share].Key'.Value
		$ComputerName     = $adminInfoShare.'[ABC.Windows.Server.AdminInfo.Share].ComputerName'.Value
		$Name             = $adminInfoShare.'[ABC.Windows.Server.AdminInfo.Share].Name'.Value
		$FSPath           = $adminInfoShare.'[ABC.Windows.Server.AdminInfo.Share].FileSystemPath'.Value
		$Description      = $adminInfoShare.'[ABC.Windows.Server.AdminInfo.Share].Description'.Value
		$NTFSPermissions  = $adminInfoShare.'[ABC.Windows.Server.AdminInfo.Share].NTFSPermissions'.Value		
		$sharePermissions = $adminInfoShare.'[ABC.Windows.Server.AdminInfo.Share].SharePermissions'.Value

		$state            = ''		
		$regPat           = '(Everyone|BUILTIN\\Users|Authenticated\sUsers);\s?Allow;[a-zA-Z,\s]{1,}?(Modify|Change|FullControl)'

		if ($NTFSPermissions -match $regPat) {
			$state       = 'Yellow'			
			$alertInfo   = 'Pontential risky permission found. Please correct.'
			if ($sharePermissions -match $regPat) {
				$state     = 'Red'
				$alertInfo = 'Dangerous permission found. Please correct asap.'
			}			
		} else {
			$state = 'Green'
		} #END if ($NTFSPermissions -match $regPat)		

		$supplement = " Share: $($Name) / $($FSPath) `n NTFS Permission: $($NTFSPermissions) `n Share Permissions: $($sharePermissions)`n Alert Info: $($alertInfo)"
		
		$bag = $api.CreatePropertybag()					
		$bag.AddValue("Key",$Key)
		$bag.AddValue("Name",$Name)		
		$bag.AddValue("State",$state)				
		$bag.AddValue("Supplement",$supplement)		
		$bag.AddValue("TestedAt",$testedAt)			
		$bag	

	} #END foreach ($adminInfoShare in $classAdminInfoShareInstances)	
	

}