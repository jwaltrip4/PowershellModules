function ConvertToEnum([string]$type, [int]$value)
{
   $sma = [appdomain]::currentdomain.getassemblies() | ? { $_.fullname -match "system.management.automation" }
   $t = $sma.GetType($type, $false, $true)
  
   if ($t)
   {
      [enum]::parse($t, $value)
   }
   else
   {
        $value
   }
}

function DeserializeGuid([byte[]]$data, $indexToStart)
{
   if ($data.count -lt ($indexToStart + 16))
   {
      throw "Not enough data to construct a DeserializeGUID"
   }   
   
   [byte[]]$guidArray = new-object byte[] 16
   for($index = 0; $index -lt 16; $index++)
   {
      $guidArray[$index] = $data[$indexToStart + $index]
   }
   
   new-object guid (,$guidArray)
}

function ConvertTo-BigEndianInteger([byte[]]$data, [int]$offset, [type]$typeOfInteger)
{
	switch ($typeOfInteger.FullName)
	{
		"System.Int16" { $sizeOfIntegerInBits = 16; $convertMethod = "ToInt16" }
		"System.UInt16" { $sizeOfIntegerInBits = 16; $convertMethod = "ToUInt16" }
		"System.Int32" { $sizeOfIntegerInBits = 32; $convertMethod = "ToInt32" }
		"System.UInt32" { $sizeOfIntegerInBits = 32; $convertMethod = "ToUInt32" }
		"System.Int64" { $sizeOfIntegerInBits = 64; $convertMethod = "ToInt64" }
		"System.UInt64" { $sizeOfIntegerInBits = 64; $convertMethod = "ToUInt64" }
	}
	$sizeOfIntegerInBytes = $sizeOfIntegerInBits / 8
	[Array]::Reverse($data, $offset, $sizeOfIntegerInBytes)
	try
	{
		return ([BitConverter].GetMethod($convertMethod).Invoke($null, @($data, $offset)))
	}
	finally
	{
		[Array]::Reverse($data, $offset, $sizeOfIntegerInBytes)
	}
}

function Construct-PSRemoteDataObject(
	[Parameter(ParameterSetName = 'byteArray', Mandatory = $true, Position = 0)]
	[byte[]]$dataInByteArray,

	[Parameter(ParameterSetName = 'eventvwr', Mandatory = $true, Position = 0)]
	[string]$dataFromEventViewer
)
{
	if ($dataFromEventViewer -ne $null)
	{
		if ($dataFromEventViewer.StartsWith("0x"))
		{
			$dataFromEventViewer = $dataFromEventViewer.Substring(2, $dataFromEventViewer.Length - 2)
		}

		$dataInCharArray = $dataFromEventViewer.ToCharArray()
		[byte[]]$dataInByteArray = new-object byte[] ($dataInCharArray.Count/2)
		for([int] $index=0; $index -lt $dataInCharArray.Count; $index = $index + 2)
		{
			$a = [convert]::toint32($dataInCharArray[$index + 0], 16)
			$b = [convert]::toint32($dataInCharArray[$index + 1], 16)
			
			$dataInByteArray[$index/2] = $a * 16 + $b
		}
	}
        
	$dest = [BitConverter]::ToInt32($dataInByteArray, 0)
	$dt = [BitConverter]::ToInt32($dataInByteArray, 4)

	$message = new-object psobject -prop @{
		destination = ConvertToEnum "system.management.automation.RemotingDestination" $dest
		messageType = ConvertToEnum "system.management.automation.RemotingDataType" $dt
		runspaceId = DeserializeGuid $dataInByteArray 8
		pipelineId = DeserializeGuid $dataInByteArray 24
	}
    
	[byte[]]$xmlData = new-object byte[] ($dataInByteArray.count - 40)
	if ($xmlData.count -gt 0)
	{
		[Array]::Copy($dataInByteArray, 40, $xmlData, 0, ($dataInByteArray.count - 40))
		$memStream = new-object system.io.memorystream
		$memstream.Write($xmlData, 0, $xmlData.Count)
		$memstream.Seek(0,"begin") > $null
		$xmlReader = new-object system.io.streamreader $memStream
		add-member -input $message noteproperty data $($xmlReader.ReadToEnd())
	}
	else
	{
		add-member -input $message noteproperty data "<no xml data>"
	}

	return $message
}

function Construct-Fragment([string]$data = $(throw "data has to be base64 encoded fragment"))
{
	$dataInByteArray = [Convert]::FromBase64String($data)
	while ($dataInByteArray.Count -gt 0)
	{
		$fragment = New-Object PSObject -Prop @{
			wholeFragment = $dataInByteArray
			
			objectId = ConvertTo-BigEndianInteger $dataInByteArray 0 ([uint64])
			fragmentId = ConvertTo-BigEndianInteger $dataInByteArray 8 ([uint64])
			isStart = 0 -ne ($dataInByteArray[16] -band 1)
			isEnd = 0 -ne ($dataInByteArray[16] -band 1)
			blobLength = ConvertTo-BigEndianInteger $dataInByteArray 17 ([uint32])
		}

		Add-Member -Input $fragment NoteProperty blob $(new-object byte[] ($fragment.blobLength))
		[Array]::Copy($dataInByteArray, 21, $fragment.blob, 0, $fragment.blobLength)

		if ($fragment.isStart -and $fragment.isEnd)
		{
			try
			{
				Add-Member -Input $fragment NoteProperty psrpMsg $(Construct-PSRemoteDataObject -dataInByteArray ($fragment.blob))
			}
			catch {}
		}
	    
		# TODO - this is broken - can include multiple fragments: $fragment.wholeFragment = 
		Write-Output $fragment

		$totalFragmentLength = 8 + 8 + 1 + 4 + $fragment.blobLength
		$newArray = new-object byte[] ($dataInByteArray.Count - $totalFragmentLength)
		[Array]::Copy($dataInByteArray, $totalFragmentLength, $newArray, 0, $newArray.Count)
		$dataInByteArray = $newArray
	}
}

function Format-XML
{
	param(
		[Parameter(ValueFromPipeline = $true, Mandatory = $true, Position = 0)]
		[xml]
		$xd
	)

Process
{
	$sw = New-Object IO.StringWriter

	$xws = New-Object Xml.XmlWriterSettings
	# $xws.NewLineOnAttributes = $true
	$xws.Indent = $true
	$xws.NewLineHandling = 'Replace'

	$xw = [Xml.XmlTextWriter]::Create($sw, $xws)
	$xd.WriteContentTo($xw);
	$xw.Flush()

	echo ($sw.ToString())
}
}

Function ToInt( [Byte[]] $Buffer)
{
    [int] $Result = 0;
    $Result += $Buffer[0]
    $Result += $Buffer[1] * (0xFF + 1)
    $Result += $Buffer[2] * (0xFFFF + 1)
    $Result += $Buffer[3] * (0xFFFFFF + 1)
    
    return $Result
}

# based on http://www.tellingmachine.com/post/2009/04/Extreme-Mesh-Up-using-NUnit2c-PSExec2c-PowerShell-and-NetMon-32-to-automate-http-traffic-monitoring.aspx
function Get-Frames
{
	param(
		[Parameter(Mandatory = $true)]
		[string] 
		$Path
	)

	$Buffer = Get-Content -Encoding Byte -Path $Path
	$FrameTableOffset = ToInt $Buffer[24..27]
	$FrameTableLength = ToInt $Buffer[28..31]
	$NumberOfFrames = $FrameTableLength / 4
	$FrameTable = $Buffer[$FrameTableOffset .. ($FrameTableOffset + $FrameTableLength)]

	$FrameOffsets = 1..$NumberOfFrames | %{
		$FrameNumber = $_ - 1
		$FrameOffset = ToInt $FrameTable[($FrameNumber * 4) .. ($FrameNumber * 4 + 4)]
		$FrameOffset
	}
	$FrameOffsets += @($Buffer.Length)

	1..$NumberOfFrames | %{
		$Start = $FrameOffsets[$_ - 1]
		$End = $FrameOffsets[$_] - 1
		$Frame = New-Object PSObject -Prop @{
			FrameNumber = $_
			FrameContent = $Buffer[$Start .. $End]
		}
		$Frame
	}
}

function Get-Fragments
{
	param(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[xml]
		$soapContent
	)

	$namespaces = @{
		s = "http://www.w3.org/2003/05/soap-envelope"
		a = "http://schemas.xmlsoap.org/ws/2004/08/addressing"
		w = "http://schemas.dmtf.org/wbem/wsman/1/wsman.xsd"
		p = "http://schemas.microsoft.com/wbem/wsman/1/wsman.xsd"
		r = "http://schemas.microsoft.com/wbem/wsman/1/windows/shell"
		c = "http://schemas.microsoft.com/powershell"
	}

	$fragments = @()
	$fragments += @(Select-Xml -Xml $soapContent -Namespace $namespaces -XPath "/s:Envelope/s:Body/r:Shell/c:creationXml" | %{ $_.Node.InnerText })
	$fragments += @(Select-Xml -Xml $soapContent -Namespace $namespaces -XPath "/s:Envelope/s:Body/r:CommandLine/r:Arguments" | %{ $_.Node.InnerText })
	$fragments += @(Select-Xml -Xml $soapContent -Namespace $namespaces -XPath "/s:Envelope/s:Body/r:Send/r:Stream" | %{ $_.Node.InnerText })
	$fragments += @(Select-Xml -Xml $soapContent -Namespace $namespaces -XPath "/s:Envelope/s:Body/r:ReceiveResponse/r:Stream" | %{ $_.Node.InnerText })

	$fragments | %{ Construct-Fragment $_ }
}

function Get-SoapMessages
{
	param(
		[Parameter(Mandatory = $True)]
		$Frames
	)

	$InsideSoap = $false
	$Iteration = 0
	$Frames | %{
			write-verbose $_.FrameNumber
		
		$Iteration = $Iteration + 1
		if (($Iteration % 10) -eq 0)
		{
			Write-Progress "Extracting Soap frames..." "Procesing frame $Iteration / $($Frames.Count)"
		}

		$b = $_.FrameContent

		if ($InsideSoap)
		{
			# Find the first N ANSI characters and treat that as a continuation of a soap message

			$Start = 2
			do
			{
				$Start++

				$startReached1 = (  @($b[$Start .. ($Start+10)] | ?{ ($_ -lt 0x20) -or ($_ -gt 0x80) }).Count -eq 0  )
			}
			while ((-not $startReached1) -and ($Start -lt 203) -and ($Start -lt ($b.Length - 10)))
			if ($startReached1) { $Start = $Start } else { return }
		}
		else
		{	
			# Find "Env" string and treat that as a beginning of a soap message

			$Start = 2
			do
			{
				$Start++
				$m1 = $b[$Start]
				$m2 = $b[$Start + 1]
				$m3 = $b[$Start + 2]

				$startReached1 = ($m1 -eq 0x45) -and ($m2 -eq 0x6e) -and ($m3 -eq 0x76)
			}
			while ((-not $startReached1) -and ($Start -lt 403))
			if ($Start -lt 400) { 
				while ($b[$Start] -ne ([int][char]'<')) { $Start-- }
			} else { $Start = $b.Length }
		}

		$End = 1
		do
		{
			# find where soap content ends in a frame
			# this is based on the magic content I found in actual network captures
			# this can be probably made much cleaner (if only I understood the binary format of the frames)

			$End++
			
			$m0 = $b[$b.Length - $End - 3]
			$m1 = $b[$b.Length - $End - 2]
			$m2 = $b[$b.Length - $End - 1]
			$m3 = $b[$b.Length - $End - 0]

			$endReached1 = ($m1 -eq 0) -and ($m2 -eq 6)
			$endReached2 = ($m1 -eq 1) -and ($m2 -eq 2) -and ($m3 -eq 3)
			$endReached3 = ($m1 -eq 1) -and ($m2 -eq 2) -and ($m3 -eq 2)
			$endReached4 = ($m1 -eq 1) -and ($m2 -eq 1) -and ($m3 -eq 6)
			$endReached5 = ($m1 -eq 1) -and ($m2 -eq 0) -and ($m3 -eq 1)

			if (($m0 -lt 0x20) -or ($m0 -gt 0x80)) { $endReached1 = $endReached2 = $endReached3 = $endReached4 = $endReached5 = $false }
		}
		while (
			(-not $endReached1) -and (-not $endReached2) -and (-not $endReached3) -and (-not $endReached4) -and  (-not $endReached5) -and 
			($End -lt 40) -and ($End -lt ($b.Length - 10)))
		if ($endReached1 -or $endReached2 -or $endReached3 -or $endReached4 -or $endReached5) { $End = $End + 2 } else { return } 

		write-verbose "start = $start; end = $end"

		# do we have something that looks like content of a soap message?
		if ($b.Length -gt ($Start + $End))
		{
			$s = [Text.Encoding]::UTF8.GetString($b, $Start, $b.Length - $Start - $End)
			try { write-verbose "s = $($s.substring(0,15)) ... $($s.substring($s.length-15, 15))" } catch {}
			if ($s -match '^<[a-zA-Z]{1,5}:Envelope')
			{
				Write-verbose BEGIN
				$InsideSoap = $true
				$SoapMessage = New-Object PSObject -Prop @{ 
					FirstFrame = $_.FrameNumber
					LastFrame = -1
					SoapContent = "" 
				}
			}
			if ($InsideSoap)
			{
				Write-verbose INSIDE
				$SoapMessage.SoapContent = $SoapMessage.SoapContent + $s
			}
			if ($InsideSoap -and ($SoapMessage.SoapContent -match "</[a-zA-Z]{1,5}:Envelope>$"))
			{
				Write-verbose END
				$SoapMessage.LastFrame = $_.FrameNumber
				try { Add-Member -Input $SoapMessage NoteProperty Fragments $(@(Get-Fragments ([xml]($SoapMessage.SoapContent)))) } catch {}
				try { Add-Member -Input $SoapMessage NoteProperty WsmvCode $( 
					# "$(([xml]($SoapMessage.SoapContent)).Envelope.Body.PSBase.ChildNodes | %{ $_.Name })"
					$action = ([xml]($SoapMessage.soapcontent)).envelope.header.action
					if (-not ($action -is [string]))
					{
						$action = $action.psbase.innertext
					}
					"$([io.path]::GetFileName(([uri]($action)).LocalPath))"
				) } catch {}
				try { Add-Member -Input $SoapMessage NoteProperty PsrpCode $( 
					"$($SoapMessage.Fragments | %{$_.psrpmsg.messageType})"
				) } catch {}
				Write-Output $SoapMessage
				$InsideSoap = $false
			}
		}		
	}

	Write-Progress "Extracting Soap frames..." "Done" -Completed
}

function Format-SoapMessage
{
	param(
		[Parameter(ValueFromPipeline = $true)]
		$soapMessage
	)

Process {
	Write-Host ("-" * 70) -fore yellow
	Write-Host "Frames $($soapMessage.FirstFrame) - $($soapMessage.LastFrame) :"
	Format-Xml ($soapMessage.SoapContent)
}
}

