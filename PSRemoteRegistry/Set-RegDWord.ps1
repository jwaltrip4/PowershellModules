function Set-RegDWord
{

	<#
	.SYNOPSIS
	       Sets or creates a 32-bit binary number (REG_DWORD) on local or remote computers.

	.DESCRIPTION
	       Use Set-RegDWord to set or create a 32-bit binary number (REG_DWORD) on local or remote computers.
	       
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

	.PARAMETER Value
	       The name of the registry value.

	.PARAMETER Data
	       The data to set the registry value.

	.PARAMETER Force
	       Overrides any confirmations made by the command. Even using the Force parameter, the function cannot override security restrictions.

	.PARAMETER Ping
	       Use ping to test if the machine is available before connecting to it. 
	       If the machine is not responding to the test a warning message is output.

	.PARAMETER PassThru
	       Passes the newly custom object to the pipeline. By default, this function does not generate any output.
		
	.EXAMPLE
		$Key = "SYSTEM\CurrentControlSet\Control\Terminal Server"	
		Get-RegDWord -ComputerName "SERVER1","SERVER1","SERVER3" -Key $Key -Value fDenyTSConnections -Ping
				
		Description
		-----------
		The command gets the registry fDenyTSConnections Dword value from three remote computers.		
		When the Switch parameter Ping is specified the command issues a ping test to each computer. 
		If the computer is not responding to the ping request a warning message is written to the console and the computer is not processed.

	.EXAMPLE
		Get-RegDWord -ComputerName "SERVER1","SERVER1","SERVER3" -Key $Key -Value fDenyTSConnections -Ping | Where-Object {$_.Data -eq 1} | Set-RegDWord -Data 0 -Force -PassThru
				
		Description
		-----------
		The command gets the registry fDenyTSConnections Dword value from three remote computers. 
		The result is piped to the Where-Object cmdlet and filters the computers that have Rempote Desktop disabled.
		The Results of Where-Object are piped to Set-RegDWord which sets the Dword value to 1 (Enable Rempote Desktop connections).
		
		When the Switch parameter Ping is specified the command issues a ping test to each computer. 
		If the computer is not responding to the ping request a warning message is written to the console and the computer is not processed.
		By default, the caller is prompted to confirm each action. To override confirmations, the Force Switch parameter is specified.		
		By default, the command doesn't return any objects back. To get the values objects, specify the PassThru Switch parameter.				

	.EXAMPLE
		$Key = "SOFTWARE\Microsoft\Windows\CurrentVersion\policies\Explorer"
		Get-Contebt server.txt | Set-RegDWord -Key $Key -Value NoDriveTypeAutorun -Data 0xFF -Force -PassThru -Ping
				
		Description
		-----------
		The command disables Autoplay for all drives on all server names defined in servers.txt with a HEX value of 0xFF (Decimal 255). 
		When the Switch parameter Ping is specified the command issues a ping test to each computer. 
		If the computer is not responding to the ping request a warning message is written to the console and the computer is not processed.
		By default, the caller is prompted to confirm each action. To override confirmations, the Force Switch parameter is specified.		
		By default, the command doesn't return any objects back. To get the values objects, specify the PassThru Switch parameter.

	.OUTPUTS
		PSFanatic.Registry.RegistryValue (PSCustomObject)

	.NOTES
		Author: Shay Levy
		Blog  : http://blogs.microsoft.co.il/blogs/ScriptFanatic/

	.LINK
		http://code.msdn.microsoft.com/PSRemoteRegistry

	.LINK
		Get-RegDWord
		Get-RegValue
		Remove-RegValue
		Test-RegValue
	#>
	
	
	[OutputType('PSFanatic.Registry.RegistryValue')]
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
			HelpMessage="The path of the subkey to open or create."
		)]
		[string]$Key,

		[Parameter(
			Mandatory=$true,
			Position=3,
			ValueFromPipelineByPropertyName=$true,
			HelpMessage="The name of the value to set."
		)]
		[string]$Value,

		[Parameter(Mandatory=$true,Position=4)]
		[int]$Data,
		
		[switch]$Force,
		[switch]$Ping,
		[switch]$PassThru
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
				
				Write-Verbose "Open remote subkey: [$Key] with write access."
				$subKey = $reg.OpenSubKey($Key,$true)
				
				if(!$subKey)
				{
					Throw "Key '$Key' doesn't exist."
				}				

				if($Force -or $PSCmdlet.ShouldProcess($c,"Set Registry DWord Value '$Hive\$Key\$Value'"))
				{					
					Write-Verbose "Parameter [Force] or [Confirm:`$False] is presnet, suppressing confirmations."
					Write-Verbose "Setting value name: [$Value]"
					$subKey.SetValue($Value,$Data,[Microsoft.Win32.RegistryValueKind]::DWord)
				}	
				
				
				if($PassThru)
				{
					Write-Verbose "Parameter [PassThru] is presnet, creating PSFanatic registry custom objects."
					Write-Verbose "Create PSFanatic registry value custom object."
					
					$pso = New-Object PSObject -Property @{
						ComputerName=$c
						Hive=$Hive
						Value=$Value
						Key=$Key
						Data=$subKey.GetValue($Value)
						Type=$subKey.GetValueKind($Value)
					}

					Write-Verbose "Adding format type name to custom object."
					$pso.PSTypeNames.Clear()
					$pso.PSTypeNames.Add('PSFanatic.Registry.RegistryValue')
					$pso				
				}
				
				Write-Verbose "Closing remote registry connection on: [$c]."
				$subKey.close()
			}
			catch
			{
				Write-Error $_
			}
		} 
		
		Write-Verbose "Exit process block..."
	}
}