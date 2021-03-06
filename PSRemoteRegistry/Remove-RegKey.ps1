function Remove-RegKey
{

	<#
	.SYNOPSIS
	       Deletes the specified registry key from local or remote computers.

	.DESCRIPTION
	       Use Remove-RegKey to delete the specified registry key from local or remote computers.
	       
	.PARAMETER ComputerName
	    	An array of computer names. The default is the local computer.

	.PARAMETER Hive
	   	The HKEY to open, from the RegistryHive enumeration. The default is 'LocalMachine'.
	   	Possible values:
	   	
		- ClassesRoot
		- CurrentUser
		- LocalMachine
		- Users
		- PerformanceData
		- CurrentConfig
		- DynData	   	

	.PARAMETER Key
	       The path of the registry key to open.  

	.PARAMETER Force
	       Overrides any confirmations made by the command. Even using the Force parameter, the function cannot override security restrictions.

	.PARAMETER Ping
	       Use ping to test if the machine is available before connecting to it. 
	       If the machine is not responding to the test a warning message is output.

	   .PARAMETER Recurse
	       Deletes the specified subkey and any child subkeys recursively.

	.EXAMPLE
		$Key= "SOFTWARE\MyCompany\NewSubKey"
		Test-RegKey -Key $Key -ComputerName SERVER1,SERVER2 -PassThru | Remove-RegKey -Force
		
		Description
		-----------
		The command checks if the NewSubKey key exists on SERVER1 and SERVER2. When using the PassThru parameter, each key, if found, it emitted to the pipeline.
		Each key found that is piped into Remove-RegKey is deleted whether it it empty or has any subkeys or values.		

	.NOTES
		Author: Shay Levy
		Blog  : http://blogs.microsoft.co.il/blogs/ScriptFanatic/
	
	.LINK
		http://code.msdn.microsoft.com/PSRemoteRegistry

	.LINK
		Get-RegKey
		New-RegKey
		Test-RegKey
		
	#>
	

	[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High',DefaultParameterSetName="__AllParameterSets")]
	
	param( 
		[Parameter(
			Position=0,
			ValueFromPipeline=$true,
			ValueFromPipelineByPropertyName=$true,
			HelpMessage="An array of computer names. The default is the local computer."
		)]		
		[Alias("CN","__SERVER","IPAddress")]
		[string[]]$ComputerName="",		
		
		[Parameter(
			Position=1,
			ValueFromPipelineByPropertyName=$true,
			HelpMessage="The HKEY to open, from the RegistryHive enumeration. The default is 'LocalMachine'."
		)]
		[ValidateSet("ClassesRoot","CurrentUser","LocalMachine","Users","PerformanceData","CurrentConfig","DynData")]
		[string]$Hive="LocalMachine",
		
		[Parameter(
			Mandatory=$true,
			Position=2,
			ValueFromPipelineByPropertyName=$true,
			HelpMessage="The path of the subkey to remove."
		)]
		[string]$Key,
		
		[switch]$Ping,
		[switch]$Force,
		[switch]$Recurse
	) 
	

	process
	{
	    	
	    	Write-Verbose "Enter process block..."
		
		foreach($c in $ComputerName)
		{	
			try
			{				
				if($c -eq "")
				{
					$c=$env:COMPUTERNAME
					Write-Verbose "Parameter [ComputerName] is not presnet, setting its value to local computer name: [$c]."
					
				}
				
				if($Ping)
				{
					Write-Verbose "Parameter [Ping] is presnet, initiating Ping test"
					
					if( !(Test-Connection -ComputerName $c -Count 1 -Quiet))
					{
						Write-Warning "[$c] doesn't respond to ping."
						return
					}
				}

				
				Write-Verbose "Starting remote registry connection against: [$c]."
				Write-Verbose "Registry Hive is: [$Hive]."
				$reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey([Microsoft.Win32.RegistryHive]$Hive,$c)		
				
				if($Force -or $PSCmdlet.ShouldProcess($c,"Remove Registry Key '$Hive\$Key'"))
				{		

					Write-Verbose "Parameter [Force] or [Confirm:`$False] is presnet, suppressing confirmations."
					Write-Verbose "Setting value name: [$Value]"

					if($Recurse)
					{
						Write-Verbose "Parameter [Recurse] is presnet, deleting key and sub items."
						$reg.DeleteSubKeyTree($Key)
					}
					else
					{
						Write-Verbose "Parameter [Recurse] is not presnet, deleting key."
						$reg.DeleteSubKey($Key,$True)
					}
				}			
				
				Write-Verbose "Closing remote registry connection on: [$c]."
				$reg.close()
			}
			catch
			{
				Write-Error $_
			}
		} 
		
		Write-Verbose "Exit process block..."
	}
}