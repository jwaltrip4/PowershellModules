function Set-RegExpandString
{

	<#
	.SYNOPSIS
		Sets or creates a string (REG_EXPAND_SZ) registry value on local or remote computers.

	.DESCRIPTION
		Use Set-RegExpandString to set or create registry string (REG_EXPAND_SZ) value on local or remote computers.
	       
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

	.PARAMETER ExpandEnvironmentNames
		Expands values (from the local environment) containing references to environment variables.

	.PARAMETER Force
		Overrides any confirmations made by the command. Even using the Force parameter, the function cannot override security restrictions.

	.PARAMETER Ping
		Use ping to test if the machine is available before connecting to it. 
		If the machine is not responding to the test a warning message is output.

	.PARAMETER PassThru
		Passes the newly custom object to the pipeline. By default, this function does not generate any output.


	.EXAMPLE
		$Key = "SOFTWARE\MyCompany"
		Set-RegExpandString -ComputerName SERVER1,SERVER2,SERVER3 -Key $Key -Value SystemDir -Data %WinDir%\System32 -Force -PassThru -ExpandEnvironmentNames

		ComputerName Hive            Key                  Value      Data                 Type
		------------ ----            ---                  -----      ----                 ----
		COMPUTER1    LocalMachine    SOFTWARE\MyCompany   SystemDir  C:\Windows\System32  ExpandString
		
		
		Description
		-----------
		The command sets the registry SystemDir ExpandString value on three remote servers.
		The returned value contains an expanded value based on local environment variables.
		When the Switch parameter Ping is specified the command issues a ping test to each computer. 
		If the computer is not responding to the ping request a warning message is written to the console and the computer is not processed.
		By default, the caller is prompted to confirm each action. To override confirmations, the Force Switch parameter is specified.		
		By default, the command doesn't return any objects back. To get the values objects, specify the PassThru Switch parameter.	

	.EXAMPLE
		"SERVER1","SERVER2","SERVER3" | Set-RegExpandString -Key $Key -Value SystemDir -Data %WinDir%\System32 -Ping -Force -PassThru

		ComputerName Hive            Key                  Value      Data              Type
		------------ ----            ---                  -----      ----              ----
		SERVER1      LocalMachine    SOFTWARE\MyCompany   SystemDir  %WinDir%\System32 ExpandString
		SERVER2      LocalMachine    SOFTWARE\MyCompany   SystemDir  %WinDir%\System32 ExpandString
		SERVER3      LocalMachine    SOFTWARE\MyCompany   SystemDir  %WinDir%\System32 ExpandString


		Description
		-----------
		The command sets the registry SystemDir ExpandString value on three remote servers.
		The returned value is not expanded.
		
	.OUTPUTS
		PSFanatic.Registry.RegistryValue (PSCustomObject)

	.NOTES
		Author: Shay Levy
		Blog  : http://blogs.microsoft.co.il/blogs/ScriptFanatic/
		
	.LINK
		http://code.msdn.microsoft.com/PSRemoteRegistry
	
	.LINK
		Get-RegExpandString
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
		[ValidateScript({ [Enum]::GetNames([Microsoft.Win32.RegistryHive]) -contains $_	})]
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

		[Parameter(
			Mandatory=$true,
			Position=4,
			HelpMessage="The data to set the registry value."
		)]
		[string]$Data,
		
		[switch]$ExpandEnvironmentNames,
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
				
				if($Force -or $PSCmdlet.ShouldProcess($c,"Set Registry Expand String Value '$Hive\$Key\$Value'"))
				{
					Write-Verbose "Parameter [ExpandEnvironmentNames] is presnet, expanding value of environamnt strings."
					Write-Verbose "Parameter [Force] or [Confirm:`$False] is presnet, suppressing confirmations."
					Write-Verbose "Setting value name: [$Value]"
					$subKey.SetValue($Value,$Data,[Microsoft.Win32.RegistryValueKind]::ExpandString)
				}	
				
				
				if($PassThru)
				{
					Write-Verbose "Parameter [PassThru] is presnet, creating PSFanatic registry custom objects."
					Write-Verbose "Create PSFanatic registry value custom object."
					
					if($ExpandEnvironmentNames){
						Write-Verbose "Parameter [ExpandEnvironmentNames] is presnet, expanding value of environamnt strings."
						$d = $subKey.GetValue($Value,$Data)
					}
					else
					{
						$d = $subKey.GetValue($Value,$Data,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
					}
					
					$pso = New-Object PSObject -Property @{
						ComputerName=$c
						Hive=$Hive
						Value=$Value					
						Key=$Key
						Data=$d
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