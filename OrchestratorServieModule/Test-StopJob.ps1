
###################################################################
#    Copyright (c) Microsoft. All rights reserved.
#    This code is licensed under the Microsoft Public License.
#    THIS CODE IS PROVIDED *AS IS* WITHOUT WARRANTY OF
#    ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING ANY
#    IMPLIED WARRANTIES OF FITNESS FOR A PARTICULAR
#    PURPOSE, MERCHANTABILITY, OR NON-INFRINGEMENT.
###################################################################

##################################################
# Test-StopJob
##################################################

begin {
    # import modules
    Import-Module .\OrchestratorServiceModule.psm1
}

process {
    # get credentials (set to $null to UseDefaultCredentials)
    $creds = $null
    #$creds = Get-Credential "DOMAIN\USERNAME"

    # create the base url to the service
    $url = Get-OrchestratorServiceUrl -server "SERVERNAME"

    # Use a running job for test
    $jobid = [guid]"JOBID"
    
    $job = Get-OrchestratorJob -serviceurl $url -jobid $jobid -credentials $creds
        
    if ($job -ne $null) {
        # Stop the job
        $success = Stop-OrchestratorJob -job $job -credentials $creds
        Write-Host "Success = " $success
    }
    else
    {
        Write-Host "No Job"
    }
}

end {
    # remove modules
    Remove-Module OrchestratorServiceModule
}
