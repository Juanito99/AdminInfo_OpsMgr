param($sourceId,$managedEntityId,$discoveryItem,$ComputerName)

$api           = New-Object -ComObject 'MOM.ScriptAPI'
$discoveryData = $api.CreateDiscoveryData(0, $sourceId, $managedEntityId)

if ($discoveryItem -eq 'Share') {

	$shares    = Get-WmiObject -Class Win32_Share 	
	$shareList = New-Object -TypeName System.Collections.ArrayList

	foreach ($share in $shares) {
  
		if (($share.Name -notmatch '(?im)^[a-z]{1,1}\$') -and ($share.Name -notmatch '(?im)^[admin]{5,5}\$') -and ($share.Name -notmatch '(?im)^[ipc]{3,3}\$') -and `
			($share.Name -notmatch '(?im)^SMS{3,8}\$?|^print\$|(?im)SCCMContentLib\$'))  {      
			
			If (($share.Path -notmatch '(?i)DFSRoots\$?') -and ($share.Path -notmatch '(?i)SMSPKG[a-z]\$') -and ($share.Path -notmatch '(?i)SYSVOL')) { 

				$shareAccessInfo = ''
				$ntfsAccessInfo  = ''    
	
				$fileAccessControlList = Get-Acl -Path $($share.Path) | Select-Object -ExpandProperty Access | Select-Object -Property FileSystemRights, AccessControlType, IdentityReference    
	
				foreach ($fileAccessControlEntry in $fileAccessControlList) {
					if (($fileAccessControlEntry.FileSystemRights -notmatch '\d') -and ($fileAccessControlEntry.IdentityReference -notmatch '(?i)Builtin\\Administrators|NT\sAUTHORITY\\SYSTEM|NT\sSERVICE\\TrustedInstaller')) {      
						$ntfsAccessInfo += "$($fileAccessControlEntry.IdentityReference); $($fileAccessControlEntry.AccessControlType); $($fileAccessControlEntry.FileSystemRights)" + ' | '  
					}
				} #END foreach ($fileAccessControlEntry in $fileAccessControlList)

				$ntfsAccessInfo = $ntfsAccessInfo.Substring(0,$ntfsAccessInfo.Length - 3)
				$ntfsAccessInfo = $ntfsAccessInfo -replace ',\s?Synchronize',''   
	
				$permissionStringTest = $ntfsAccessInfo -replace ';',''
				$permissionStringTest = $permissionStringTest -replace ' ',''			
	   
				$shareSecuritySetting    = Get-WmiObject -Class Win32_LogicalShareSecuritySetting -Filter "Name='$($share.Name)'"               
				$shareSecurityDescriptor = $shareSecuritySetting.GetSecurityDescriptor()
				$shareAcccessControlList = $shareSecurityDescriptor.Descriptor.DACL          
	
				foreach($shareAccessControlEntry in $shareAcccessControlList) {
	
					$trustee    = $($shareAccessControlEntry.Trustee).Name      
					$accessMask = $shareAccessControlEntry.AccessMask
	  
					if($shareAccessControlEntry.AceType -eq 0) {
						$accessType = 'Allow'
					} else {
						$accessType = 'Deny'
					}
		
					if ($accessMask -match '2032127|1245631|1179817') {          
						if ($accessMask -eq 2032127) {
							$accessMaskInfo = 'FullControl'
						} elseif ($accessMask -eq 1179817) {
							$accessMaskInfo = 'Read'
						} elseif ($accessMask -eq 1245631) {
							$accessMaskInfo = 'Change'
						} else {
							$accessMaskInfo = 'Unknown'
						}
						$shareAccessInfo += "$trustee; $accessType; $accessMaskInfo" + ' | '
					}            
	
				} #END foreach($shareAccessControlEntry in $shareAcccessControlList)
		   
				if ($shareAccessInfo -match '|') {
					$shareAccessInfo = $shareAccessInfo.Substring(0,$shareAccessInfo.Length - 3)
				}               
	
				if ($permissionStringTest) {    
					$myShareHash = @{'Name'=$share.Name}
					$myShareHash.Add('FileSystemPath',$share.Path )       
					$myShareHash.Add('Description',$share.Description)        
					$myShareHash.Add('NTFSPermissions',$ntfsAccessInfo)
					$myShareHash.Add('SharePermissions',$shareAccessInfo)
					$myShareObject = New-Object -TypeName PSObject -Property $myShareHash
					$myShareObject.PSObject.TypeNames.Insert(0,'MyShareObject')  
		
					$null = $shareList.Add($myShareObject)
				}

			} #END If (($share.Path -notmatch '(?i)DFSRoots\$?') -and ($share.Path -notmatch '(?i)SMSPKG[a-z]\$') -and ($share.Path -notmatch '(?i)SYSVOL'))

		} #END if (($share.Name -notmatch '(?im)^[a-z]{1,1}\$') -and ($share.Name -notmatch '(?im)^[admin]{5,5}\$') -and ($share.Name -notmatch '(?im)^[ipc]{3,3}\$') )

	} #END foreach ($share in $shares)

	if ($shareList.Count -gt 0) {
	
		foreach ($shareItem in $shareList) {
	
			$Key         = $ComputerName + '-' + $($shareItem.Name)
			$displayName = 'Share ' + $($shareItem.Name) + ' On ' + $ComputerName

			$instance = $discoveryData.CreateClassInstance("$MPElement[Name='ABC.Windows.Server.AdminInfo.Share']$")
			$instance.AddProperty("$MPElement[Name='ABC.Windows.Server.AdminInfo.Share']/ComputerName$",$ComputerName)
			$instance.AddProperty("$MPElement[Name='ABC.Windows.Server.AdminInfo.Share']/Key$",$Key)	
			$instance.AddProperty("$MPElement[Name='ABC.Windows.Server.AdminInfo.Share']/Name$",$shareItem.Name)
			$instance.AddProperty("$MPElement[Name='ABC.Windows.Server.AdminInfo.Share']/FileSystemPath$",$shareItem.FileSystemPath)		
			$instance.AddProperty("$MPElement[Name='ABC.Windows.Server.AdminInfo.Share']/Description$",$shareItem.Description)				
			$instance.AddProperty("$MPElement[Name='ABC.Windows.Server.AdminInfo.Share']/NTFSPermissions$",$shareItem.NTFSPermissions)							
			$instance.AddProperty("$MPElement[Name='ABC.Windows.Server.AdminInfo.Share']/SharePermissions$",$shareItem.SharePermissions)
			$instance.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", $displayName)
			$discoveryData.AddInstance($instance)	
	
		} #END foreach ($shareItem in $shareList)
			
	} else {		

		$myShareHash = @{'Name'='No custom share found.'}
		$myShareHash.Add('FileSystemPath','Na')       
		$myShareHash.Add('Description','Na')        
		$myShareHash.Add('NTFSPermissions','Na')
		$myShareHash.Add('SharePermissions','Na')
		$shareItem = New-Object -TypeName PSObject -Property $myShareHash
		$shareItem.PSObject.TypeNames.Insert(0,'MyShareObject')  

		$Key         = $ComputerName + '-' + $($shareItem.Name)
		$displayName = 'Share ' + $($shareItem.Name) + ' On ' + $ComputerName

		$instance = $discoveryData.CreateClassInstance("$MPElement[Name='ABC.Windows.Server.AdminInfo.Share']$")
		$instance.AddProperty("$MPElement[Name='ABC.Windows.Server.AdminInfo.Share']/ComputerName$",$ComputerName)
		$instance.AddProperty("$MPElement[Name='ABC.Windows.Server.AdminInfo.Share']/Key$",$Key)	
		$instance.AddProperty("$MPElement[Name='ABC.Windows.Server.AdminInfo.Share']/Name$",$shareItem.Name)
		$instance.AddProperty("$MPElement[Name='ABC.Windows.Server.AdminInfo.Share']/FileSystemPath$",$shareItem.FileSystemPath)		
		$instance.AddProperty("$MPElement[Name='ABC.Windows.Server.AdminInfo.Share']/Description$",$shareItem.Description)				
		$instance.AddProperty("$MPElement[Name='ABC.Windows.Server.AdminInfo.Share']/NTFSPermissions$",$shareItem.NTFSPermissions)						
		$instance.AddProperty("$MPElement[Name='ABC.Windows.Server.AdminInfo.Share']/SharePermissions$",$shareItem.SharePermissions)
		$instance.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", $displayName)
		$discoveryData.AddInstance($instance)	

	}	

}

$discoveryData