
###################################################################
#    Copyright (c) Microsoft. All rights reserved.
#    This code is licensed under the Microsoft Public License.
#    THIS CODE IS PROVIDED *AS IS* WITHOUT WARRANTY OF
#    ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING ANY
#    IMPLIED WARRANTIES OF FITNESS FOR A PARTICULAR
#    PURPOSE, MERCHANTABILITY, OR NON-INFRINGEMENT.
###################################################################

##################################################
# Test-StartRunbookAndGetInstanceDetails
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

    #
    # Start Runbook
    #

    # Define Runbook Id and any params
    $rbid = [guid]"GUID"
    #$param1 = "GUID"
    #$param2 = "GUID"
    
    $runbook = Get-OrchestratorRunbook -serviceurl $url -credentials $creds -runbookid $rbid

    if ($runbook -ne $null) {
        # Start runbook (no params)
        $job = Start-OrchestratorRunbook -runbook $runbook -credentials $creds
        
        # Start runbook with params
        [hashtable] $params = @{
            $param1 = "Hello";
            $param2 = "World"
        }
        #$job = Start-OrchestratorRunbook -runbook $runbook -parameters $params -credentials $creds
        
        # Assure job has been created before continuing
        if ($job -eq $null)
        {
            Write-Host "No job created"
            return $null
        }
        
        # Wait for the Job to finish
        while( ($job.Status -eq "Running") -or ($job.Status -eq "Pending") )
        {
            Start-Sleep -m 500
            $job = Get-OrchestratorJob -jobid $job.Id -serviceurl $job.Url_Service -credentials $creds
        }
        
        #
        # Display Job Info
        #
        Write-Host ""
        Write-Host "JOB INFO"
        Write-Host ""
        Write-Host "Url = " $job.Url
        Write-Host "Url_Service = " $job.Url_Service
        Write-Host 'Url_Runbook' = $job.Url_Runbook
        Write-Host 'Url_RunbookInstances' = $job.Url_RunbookInstances
        Write-Host 'Url_RunbookServer' = $job.Url_RunbookServer
        Write-Host 'Published' = $job.Published
        Write-Host 'Updated' = $job.Updated
        Write-Host "Category = " $job.Category
        Write-Host "Id = " $job.Id
        Write-Host 'RunbookId' = $job.RunbookId
        Write-Host 'RunbookServers' = $job.RunbookServers
        Write-Host 'RunbookServerId' = $job.RunbookServerId
        Write-Host 'Status' = $job.Status
        Write-Host 'ParentId' = $job.ParentId
        Write-Host 'ParentIsWaiting' = $job.ParentIsWaiting
        Write-Host 'CreatedBy' = $job.CreatedBy
        Write-Host 'CreationTime' = $job.CreationTime
        Write-Host 'LastModifiedBy' = $job.LastModifiedBy
        Write-Host 'LastModifiedTime' = $job.LastModifiedTime
        
        $jobparams = $job.Parameters
        if ($jobparams -ne $null)
        {
            Write-Host ""        
            Write-Host 'Parameters'
            foreach ($jobparam in $jobparams)
            {
                Write-Host ""        
                Write-Host 'Name' = $jobparam.Name
                Write-Host 'Id' = $jobparam.Id
                Write-Host 'Value' = $jobparam.Value
            }
        }
        
        #
        # Instance Info
        #
        $instance = Get-OrchestratorRunbookInstance -job $job -credentials $creds

        Write-Host ""
        Write-Host "INSTANCE INFO"
        Write-Host ""
        Write-Host "Url = " $instance.Url
        Write-Host "Url_Service = " $instance.Url_Service
        Write-Host "Url_Runbook = " $instance.Url_Runbook
        Write-Host "Url_Job = " $instance.Url_Job
        Write-Host "Url_Parameters = " $instance.Url_Parameters
        Write-Host "Url_ActivityInstances = " $instance.Url_ActivityInstances
        Write-Host "Url_RunbookServer = " $instance.Url_RunbookServer
        Write-Host "Published = " $instance.Published
        Write-Host "Updated = " $instance.Updated
        Write-Host "Category = " $instance.Category
        Write-Host "Id =  " $instance.Id
        Write-Host "RunbookId = " $instance.RunbookId
        Write-Host "JobId = " $instance.JobId
        Write-Host "RunbookServerId = " $instance.RunbookServerId
        Write-Host "Status = " $instance.Status
        Write-Host "CreationTime = " $instance.CreationTime
        Write-Host "CompletionTime = " $instance.CompletionTime
        
        $instparams = Get-OrchestratorRunbookInstanceParameter -RunbookInstance $instance -Credentials $creds
        if ($instparams -ne $null)
        {
            Write-Host ""
            Write-Host "INSTANCE PARAMS"
            foreach ($instparam in $instparams)
            {
                Write-Host ""
                Write-Host 'Url_Service = ' $instparam.Url_Service
                Write-Host 'Url_RunbookInstance = ' $instparam.Url_RunbookInstance
                Write-Host 'Url_RunbookParameter = ' $instparam.Url_RunbookParameter
                Write-Host 'Url = ' $instparam.Url
                Write-Host 'Updated = ' $instparam.Updated
                Write-Host 'Category = ' $instparam.Category
                Write-Host 'Id = ' $instparam.Id
                Write-Host 'RunbookInstanceId = ' $instparam.RunbookInstanceId
                Write-Host 'RunbookParameterId = ' $instparam.RunbookParameterId
                Write-Host 'Name = ' $instparam.Name
                Write-Host 'Value = ' $instparam.Value
                Write-Host 'Direction = ' $instparam.Direction
                Write-Host 'GroupId = ' $instparam.GroupId
            }
        }
    }
}

end {
    # remove modules
    Remove-Module OrchestratorServiceModule
}
