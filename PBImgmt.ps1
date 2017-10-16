# This sample script calls the Power BI API to perform different mangement tasks on a Power BI environment.
# TARGET report in the Power BI service. The clone can either be based off of the same dataset or a new dataset

# For full API documentation, please see:
# https://msdn.microsoft.com/en-us/library/mt147898.aspx


# Instructions:
# 1. Install PowerShell (https://msdn.microsoft.com/en-us/powershell/scripting/setup/installing-windows-powershell) and the Azure PowerShell cmdlets (https://aka.ms/webpi-azps)
# 2. Fill in the parameters below
# 3. Run the PowerShell script

# Parameters - fill these in before running the script!

# =====================================================

# AAD Client ID
# To get this, go to the following page and follow the steps to provision an app
# https://dev.powerbi.com/apps
# To get the sample to work, ensure that you have the following fields:
# App Type: Native app
# Redirect URL: urn:ietf:wg:oauth:2.0:oob
#  Level of access: all dataset APIs

$clientId = "ca67d3ba-5357-4ef5-8afe-153d9d1f4a7c" 

IF ([string]::IsNullOrWhitespace($clientId))
{
    write-host "Please update the script with a valid clientId"
    return;
}

$apiPrefix="https://api.powerbi.com/v1.0"

# End Parameters =======================================

# Calls the Active Directory Authentication Library (ADAL) to authenticate against AAD

function GetAuthToken
{
       $adal = "${env:ProgramFiles(x86)}\Microsoft SDKs\Azure\PowerShell\ServiceManagement\Azure\Services\Microsoft.IdentityModel.Clients.ActiveDirectory.dll"
       $adalforms = "${env:ProgramFiles(x86)}\Microsoft SDKs\Azure\PowerShell\ServiceManagement\Azure\Services\Microsoft.IdentityModel.Clients.ActiveDirectory.WindowsForms.dll"
       [System.Reflection.Assembly]::LoadFrom($adal) | Out-Null
       [System.Reflection.Assembly]::LoadFrom($adalforms) | Out-Null
       $redirectUri = "urn:ietf:wg:oauth:2.0:oob"
       $resourceAppIdURI = "https://analysis.windows.net/powerbi/api"
       $authority = "https://login.microsoftonline.com/common/oauth2/authorize";
       $authContext = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext" -ArgumentList $authority
       $authResult = $authContext.AcquireToken($resourceAppIdURI, $clientId, $redirectUri, "Auto") #"Auto" could be replaced with "Always" if you switch between accounts, to alter the prompt
       return $authResult
}

# Lists the groups (App Workspaces)
function getGroupsData($at, $groupId)
{
    # Get the auth token from AAD
    $token = $at

    # Building Rest API header with authorization token
    $authHeader = @{
       'Content-Type'='application/json'
       'Authorization'=$token.CreateAuthorizationHeader()
    }

    # properly format groups path
    $sourceGroupsPath = ""
    if ($sourceReportGroupId -eq "me") {
        $sourceGroupsPath = "myorg"
    } else {
        $sourceGroupsPath = "myorg/groups/$sourceReportGroupId"
    }

    $getGroupsUri = "$apiPrefix/myorg/groups"
     IF ([string]::IsNullOrWhitespace($groupId))
    {
        (Invoke-RestMethod -Uri $getGroupsUri -Headers $authHeader -Method GET).value
    }
    else
    {
        #Write-Output $groupId
        (Invoke-RestMethod -Uri $getGroupsUri -Headers $authHeader -Method GET).value | Where-Object {$_.id -eq $groupId}
    }
}

# List all the reports or the reports for a certain group
function listReports($at, $groupId)
{
    # Get the auth token from AAD
    $token = $at

    # Building Rest API header with authorization token
    $authHeader = @{
       'Content-Type'='application/json'
       'Authorization'=$token.CreateAuthorizationHeader()
    }

    # properly format groups path
    $sourceGroupsPath = ""
    if ($sourceReportGroupId -eq "me") {
        $sourceGroupsPath = "myorg"
    } else {
        $sourceGroupsPath = "myorg/groups/$sourceReportGroupId"
    }
    
    $groups = getGroupsData -groupId $groupId -at $at
    $outputObject = @()
    foreach ($grp in $groups)
    {    
        $groupId=$grp.id
        $getReportsUri = "$apiPrefix/myorg/groups/$groupId/reports"
        $reports=(Invoke-RestMethod -Uri $getReportsUri -Headers $authHeader -Method GET).value
        foreach ($report in $reports)
        {
            $dsId = $report.datasetId
            $getDSUri = "$apiPrefix/myorg/groups/$groupId/datasets/$dsId"
            #$getDSUri
            try
            {
                $dsName=(Invoke-RestMethod -Uri $getDSUri -Headers $authHeader -Method GET).name
            }
            catch
            {
                $dsName = "";
            }
            
            $report | Add-Member -type NoteProperty -Name "groupId" -Value $groupId
            $report | Add-Member -type NoteProperty -Name "groupName" -Value $grp.name
            $report | Add-Member -type NoteProperty -Name "datasetName" -Value $dsName
            $outputObject +=$report
        }
    }
    $outputObject

}

# List all the datasets or the datasets for a certain group

function listDatasets($at, $groupId)
{
    # Get the auth token from AAD
    $token = $at

    # Building Rest API header with authorization token
    $authHeader = @{
       'Content-Type'='application/json'
       'Authorization'=$token.CreateAuthorizationHeader()
    }

    # properly format groups path
    $sourceGroupsPath = ""
    IF ([string]::IsNullOrWhitespace($groupId))
    {
        $sourceGroupsPath = "myorg"
    } else {
        $sourceGroupsPath = "myorg/groups/$groupId"
    }
    
    $getDatasetsUri = "$apiPrefix/$sourceGroupsPath/datasets"
    write-host $getDatasetsUri 
    $datasets=(Invoke-RestMethod -Uri $getDatasetsUri  -Headers $authHeader -Method GET).value
    return $datasets    

    #$outputObject

}

# Returns a list of ids for all reports or by group
function getReportGUIDList($at, $groupId)
{
    # Get the auth token from AAD
    $token = $at

    # Building Rest API header with authorization token
    $authHeader = @{
       'Content-Type'='application/json'
       'Authorization'=$token.CreateAuthorizationHeader()
    }

    # properly format groups path
    $sourceGroupsPath = ""
    if ($sourceReportGroupId -eq "me") {
        $sourceGroupsPath = "myorg"
    } else {
        $sourceGroupsPath = "myorg/groups/$sourceReportGroupId"
    }
    
    $groups = getGroupsData -groupId $groupId -at $at
    $outputObject = @()
    foreach ($grp in $groups)
    {    
        $groupId=$grp.id
        $getReportsUri = "$apiPrefix/myorg/groups/$groupId/reports"
        $reports=(Invoke-RestMethod -Uri $getReportsUri -Headers $authHeader -Method GET).value
        foreach ($report in $reports)
        {
            $outputObject +=$report.id
        }
    }

    $outputObject

}

# Clones one report between groups
#
# SOURCE report info
# An easy way to get this is to navigate to the report in the Power BI service
# The URL will contain the group and report IDs with the following format:
# app.powerbi.com/groups/{groupID}/report/{reportID} 
#
#
# TARGET report info
# An easy way to get group and dataset ID is to go to dataset settings and click on the dataset
# that you'd like to refresh. Once you do, the URL in the address bar will show the group ID and 
# dataset ID, in the format: 
# app.powerbi.com/groups/{groupID}/settings/datasets/{datasetID} 

function cloneSingleReport(
        $at
        , $sourceReportGroupId # the ID of the group (workspace) that hosts the source report. Use "me" if this is your My Workspace
        , $sourceReportId # the ID of the source report
        , $targetReportName # what you'd like to name the target report
        , $targetGroupId # the ID of the group (workspace) that you'd like to move the report to. Leave this blank if you'd like to clone to the same workspace. Use "me" if this is your My Workspace
        , $targetDatasetId # the ID of the dataset that you'd like to rebind the target report to. Leave this blank to have the target report use the same dataset
        )
{
    write-host ""
    IF ([string]::IsNullOrWhitespace($sourceReportGroupId))
    { 
        getGroupsData -at $at | Format-Table -AutoSize | Out-String -Width 4096 | write-host;
        write-host ""
        $sourceReportGroupId = read-host -prompt "Please select the SOURCE APP WORKSPACE: " 
       
    }
    
    IF ([string]::IsNullOrWhitespace($sourceReportId))
    {
        listReports -at $at -groupId $sourceReportGroupId | Format-Table -AutoSize | Out-String -Width 4096 | write-host ;
        $sourceReportId = read-host -prompt "Please select the SOURCE REPORT ID: " 
    }

    
    IF ([string]::IsNullOrWhitespace($targetReportName))
    {
        
        $targetReportName = (listReports -groupId $sourceReportGroupId  -at $at | Where-Object {$_.id -eq $sourceReportId}).name
    }


    write-host ""
    IF ([string]::IsNullOrWhitespace($targetGroupId))
    { 
        getGroupsData -at $at | Format-Table -AutoSize | Out-String -Width 4096 | write-host;
        write-host ""
        $targetGroupId = read-host -prompt "Please select the TARGET APP WORKSPACE: " 
       
    }
    

    IF ([string]::IsNullOrWhitespace($targetDatasetId))
    {
        $datasets = listDatasets -at $at -groupId $targetGroupId | Format-Table -AutoSize | Out-String -Width 4096 | write-host;
        $targetDatasetId = read-host -prompt "Please select the TARGET DATASET ID: " 
        
    }

    # Get the auth token from AAD
    $token = $at

    # Building Rest API header with authorization token
    $authHeader = @{
       'Content-Type'='application/json'
       'Authorization'=$token.CreateAuthorizationHeader()
    }

    # properly format groups path
    $sourceGroupsPath = ""
    if ($sourceReportGroupId -eq "me") {
        $sourceGroupsPath = "myorg"
    } else {
        $sourceGroupsPath = "myorg/groups/$sourceReportGroupId"
    }

    # POST body 
    $postParams = @{
        "Name" = "$targetReportName"
        "TargetWorkspaceId" = "$targetGroupId"
        "TargetModelId" = "$targetDatasetId"
    }

    $jsonPostBody = $postParams | ConvertTo-JSON

    # Get reports in the new group
    $existingReports=listReports -at $at -groupId $targetGroupId
    
    foreach ($id in ($existingReports | Where-Object {$_.name -eq $targetReportName}).id)
    {
        Write-Output "Deleting: "  $id
        deleteReport -at $at -groupId $targetGroupId -reportId $id
    } 
    
    
    # Make the request to clone the report    
    $uri = "$apiPrefix/$sourceGroupsPath/reports/$sourceReportId/clone"    
    Invoke-RestMethod -Uri $uri -Headers $authHeader -Method POST -Body $jsonPostBody -Verbose
}

# Deletes a single report
function deleteReport(
        $at
        , $groupId
        , $reportId
        )
{
    write-host ""
    IF ([string]::IsNullOrWhitespace($groupId))
    { 
        getGroupsData -at $at | Format-Table -AutoSize | Out-String -Width 4096 | write-host;
        write-host ""
        $groupId = read-host -prompt "Please select the APP WORKSPACE: "        
    }

    IF ([string]::IsNullOrWhitespace($reportId))
    {
        listReports -groupId $groupId  -at $at | Format-Table -AutoSize | Out-String -Width 4096 | write-host;
        $reportId = read-host -prompt "Please select the  REPORT ID: " 
    }

    # Get the auth token from AAD
    $token = $at

    # Building Rest API header with authorization token
    $authHeader = @{
       'Content-Type'='application/json'
       'Authorization'=$token.CreateAuthorizationHeader()
    }

    # properly format groups path
    $sourceGroupsPath = ""
    if ($sourceReportGroupId -eq "me") {
        $sourceGroupsPath = "myorg"
    } else {
        $sourceGroupsPath = "myorg/groups/$sourceReportGroupId"
    }

   
    $deleteReportUri = "$apiPrefix/myorg/groups/$groupId/reports/$reportId"
    
    Invoke-RestMethod -Uri $deleteReportUri -Headers $authHeader -Method DELETE -Verbose    
}

# Rebinds a report to a differnt dataset
function rebindReport(
        $at
        , $groupId
        , $reportId
        , $targetDatasetId
        )
{
   
    write-host ""
    IF ([string]::IsNullOrWhitespace($groupId))
    { 
        getGroupsData -at $at | Format-Table -AutoSize | Out-String -Width 4096 | write-host;
        write-host ""
        $groupId = read-host -prompt "Please select the APP WORKSPACE: " 
       
    }

    IF ([string]::IsNullOrWhitespace($reportId))
    {
        listReports -groupId $groupId  -at $at | Format-Table -AutoSize | Out-String -Width 4096 | write-host;
        $reportId = read-host -prompt "Please select the  REPORT ID: " 
    }

    IF ([string]::IsNullOrWhitespace($targetDatasetId))
    {
        listDatasets -groupId $groupId  -at $at | Format-Table -AutoSize | Out-String -Width 4096 | write-host;
        $targetDatasetId = read-host -prompt "Please select the TARGET DATASET ID: " 
    }

    # Get the auth token from AAD
    $token = $at

    # Building Rest API header with authorization token
    $authHeader = @{
       'Content-Type'='application/json'
       'Authorization'=$token.CreateAuthorizationHeader()
    }

    # properly format groups path
    $sourceGroupsPath = ""
    if ($sourceReportGroupId -eq "me") {
        $sourceGroupsPath = "myorg"
    } else {
        $sourceGroupsPath = "myorg/groups/$sourceReportGroupId"
    }
   
    # POST body 
    $postParams = @{
        "datasetId" = "$targetDatasetId"
    }

    $jsonPostBody = $postParams | ConvertTo-JSON

    $rebindReportUri = "$apiPrefix/myorg/groups/$groupId/reports/$reportId/Rebind"
    
    Invoke-RestMethod -Uri $rebindReportUri -Headers $authHeader -Body $jsonPostBody -Method POST -Verbose
        
}

# Change a dataset's connection string
function rebindDataset(
        $at
        , $groupId
        , $targetDatasetId
        , $targetConnectionString
        )
{
   
    write-host ""
    IF ([string]::IsNullOrWhitespace($groupId))
    { 
        getGroupsData -at $at | Format-Table -AutoSize | Out-String -Width 4096 | write-host;
        write-host ""
        $groupId = read-host -prompt "Please select the APP WORKSPACE: "       
    }

    IF ([string]::IsNullOrWhitespace($targetDatasetId))
    {
        listDatasets -at $at -groupId $groupId | Format-Table -AutoSize | Out-String -Width 4096 | write-host;
        $targetDatasetId = read-host -prompt "Please select the TARGET DATASET ID: " 
    }

    IF ([string]::IsNullOrWhitespace($targetConnectionString))
    {
        $targetConnectionString = read-host -prompt "Please select the TARGET CONN STRING: " 
    }
    # Get the auth token from AAD
    $token = $at

    # Building Rest API header with authorization token
    $authHeader = @{
       'Content-Type'='application/json'
       'Authorization'=$token.CreateAuthorizationHeader()
    }

    # properly format groups path
    $sourceGroupsPath = ""
    if ($sourceReportGroupId -eq "me") {
        $sourceGroupsPath = "myorg"
    } else {
        $sourceGroupsPath = "myorg/groups/$groupId"
    }

    # POST body 
    $postParams = @{
        "connectionString" = "$targetConnectionString"
    }

    $jsonPostBody = $postParams | ConvertTo-JSON

    $rebindDatasetUri = "$apiPrefix/$sourceGroupsPath/datasets/$targetDatasetId/Default.SetAllConnections"
    $jsonPostBody

    Invoke-RestMethod -Uri $rebindDatasetUri -Headers $authHeader -Body $jsonPostBody -Method POST -Verbose
        
}


# Clones all reports from a certain group to a different one (and rebinds to a different dataset)
function cloneAllGroupReports(
        $at
        , $sourceGroupId # the ID of the group (workspace) that hosts the source report. Use "me" if this is your My Workspace
        , $sourceDatasetId
        , $targetGroupId # the ID of the group (workspace) that you'd like to move the report to. Leave this blank if you'd like to clone to the same workspace. Use "me" if this is your My Workspace
        , $targetDatasetId # the ID of the dataset that you'd like to rebind the target report to. Leave this blank to have the target report use the same dataset
        )
{
 
    write-host ""
    IF ([string]::IsNullOrWhitespace($sourceGroupId))
    { 
        getGroupsData -at $at | Format-Table -AutoSize | Out-String -Width 4096 | write-host;
        write-host ""
        $sourceGroupId = read-host -prompt "Please select the SOURCE APP WORKSPACE: "        
    }

    IF ([string]::IsNullOrWhitespace($sourceDatasetId))
    {
        listDatasets -at $at -groupId $sourceGroupId | Format-Table -AutoSize | Out-String -Width 4096 | write-host;
        $sourceDatasetId = read-host -prompt "Please select the SOURCE DATASET ID: " 
    }

    IF ([string]::IsNullOrWhitespace($targetGroupId))
    { 
        getGroupsData -at $at | Format-Table -AutoSize | Out-String -Width 4096 | write-host;
        write-host ""
        $targetGroupId = read-host -prompt "Please select the TARGET APP WORKSPACE: " 
       
    }
    
    IF ([string]::IsNullOrWhitespace($targetDatasetId))
    {
        listDatasets -at $at -groupId $targetGroupId | Format-Table -AutoSize | Out-String -Width 4096 | write-host
        $targetDatasetId = read-host -prompt "Please select the TARGET DATASET ID: " 
    }

    foreach ($report in ((listReports -at $at -groupId $sourceGroupId) | Where-Object {$_.datasetId -eq $sourceDatasetId}))
    {
        cloneSingleReport -at $at -sourceReportGroupId $sourceGroupId -sourceReportId $report.id -targetGroupId $targetGroupId -targetDatasetId $targetDatasetId
    }
    
}


# List all the dashboards or the dashboards for a certain group
function listDashboards($at, $groupId)
{
    # Get the auth token from AAD
    $token = $at

    # Building Rest API header with authorization token
    $authHeader = @{
       'Content-Type'='application/json'
       'Authorization'=$token.CreateAuthorizationHeader()
    }

    # properly format groups path
    $sourceGroupsPath = ""
    IF ([string]::IsNullOrWhitespace($groupId))
    {
        $sourceGroupsPath = "myorg"
    } else {
        $sourceGroupsPath = "myorg/groups/$groupId"
    }
    
    $getDashboardsUri = "$apiPrefix/$sourceGroupsPath/dashboards"
    write-host $getDatasetsUri 
    $dashboards=(Invoke-RestMethod -Uri $getDashboardsUri  -Headers $authHeader -Method GET).value
    return $dashboards    
    #$outputObject

}

# List all tiles for a certain dashboard
function listTiles($at, $groupId, $dashboardId)
{

    IF ([string]::IsNullOrWhitespace($groupId))
    {
        getGroupsData -at $at | Format-Table -AutoSize | Out-String -Width 4096 | write-host;
        $groupId = read-host -prompt "Please select the GROUP ID: " 
    }

    IF ([string]::IsNullOrWhitespace($dashboardId))
    {
        listDashboards -at $at -groupId $groupId | Format-Table -AutoSize | Out-String -Width 4096 | write-host;
        $dashboardId = read-host -prompt "Please select the DASHBOARD ID: " 
    }

    # Get the auth token from AAD
    $token = $at

    # Building Rest API header with authorization token
    $authHeader = @{
       'Content-Type'='application/json'
       'Authorization'=$token.CreateAuthorizationHeader()
    }

    # properly format groups path
    $sourceGroupsPath = ""
    IF ([string]::IsNullOrWhitespace($groupId))
    {
        $sourceGroupsPath = "myorg"
    } else {
        $sourceGroupsPath = "myorg/groups/$groupId"
    }
    
    $getTilesUri = "$apiPrefix/$sourceGroupsPath/dashboards/$dashboardId/tiles"
    write-host $getTilesUri  
    $tiles=(Invoke-RestMethod -Uri $getTilesUri   -Headers $authHeader -Method GET).value
    return $tiles

    #$outputObject

}

# Flow controller
function mainControlFlow($at)
{
    $title = "Action Menu"
    $message = "What would you like to do?"

    $opt1 = New-Object System.Management.Automation.Host.ChoiceDescription "&0 List Groups", `
        "Lists all App Workspaces."

    $opt2 = New-Object System.Management.Automation.Host.ChoiceDescription "&1 List Reports", `
        "List all reports or per specific group."
    
    $opt3 = New-Object System.Management.Automation.Host.ChoiceDescription "&2 List Datasets", `
        "List all datasets or per specific group."
    
    $opt4 = New-Object System.Management.Automation.Host.ChoiceDescription "&3 Clone Single Report", `
        "Clones a selected report."
    
    $opt5 = New-Object System.Management.Automation.Host.ChoiceDescription "&4 Clone All App Reports", `
        "Clones all the reports in an app workspace for a selected dataset."
    
    $opt6 = New-Object System.Management.Automation.Host.ChoiceDescription "&5 Delete Report", `
        "Deletes a report."
    
    $opt7 = New-Object System.Management.Automation.Host.ChoiceDescription "&6 Rebind Report", `
        "Rebinds a report to a different datasource."

    $opt8 = New-Object System.Management.Automation.Host.ChoiceDescription "&7 Rebind Dataset", `
        "Changes a dataset's connection string."
    
    $opt9 = New-Object System.Management.Automation.Host.ChoiceDescription "&8 Get Dashboards", `
        "Lists dashboards."

    $opt10 = New-Object System.Management.Automation.Host.ChoiceDescription "&9 Get Tiles", `
        "Lists dashboard tiles."

    $options = [System.Management.Automation.Host.ChoiceDescription[]]($opt1, $opt2, $opt3, $opt4, $opt5, $opt6, $opt7, $opt8, $opt9, $opt10)

    $actionMenu = $host.ui.PromptForChoice($title, $message, $options, 0) 

    #Prompt user for output method
    $file = outputMethod

    if($file -eq "")
    {
        switch ($actionMenu)
        {
            0 { getGroupsData -at $at | Format-Table -AutoSize | Out-String -Width 4096 | write-host;  }
            1 { listReports -at $at | Format-Table -AutoSize | Out-String -Width 4096 | write-host; }
            2 { listDatasets -at $at | Format-Table -AutoSize | Out-String -Width 4096 | write-host;  }
            3 { cloneSingleReport -at $at;  }
            4 { cloneAllGroupReports -at $at; }
            5 { deleteReport -at $at;  }
            6 { rebindReport -at $at; }
            7 { rebindDataset -at $at; }
            8 { listDashboards -at $at | Format-Table -AutoSize | Out-String -Width 4096 | write-host ; }
            9 { listTiles -at $at | Format-Table -AutoSize | Out-String -Width 4096 | write-host ; }
        }
    }
    else {
        switch ($actionMenu)
        {
            0 { getGroupsData -at $at | Export-Csv ($file + "getGroupsData.csv");  }
            1 { listReports -at $at | Export-Csv ($file + "listReports.csv"); }
            2 { listDatasets -at $at | Export-Csv ($file + "listDatasets.csv");  }
            3 { cloneSingleReport -at $at;  }
            4 { cloneAllGroupReports -at $at; }
            5 { deleteReport -at $at;  }
            6 { rebindReport -at $at; }
            7 { rebindDataset -at $at; }
            8 { listDashboards -at $at | Export-Csv ($file + "listDashboards.csv"); }
            9 { listTiles -at $at | Export-Csv ($file + "listTiles.csv"); }
        }
    }
    
    Write-Host "Press any key to continue ..."

    Read-Host  | Out-Null
    
    return 1
}

function outputMethod()
{
    $title = "Output Method"
    $message = "What would you like to do?"

    $opt1 = New-Object System.Management.Automation.Host.ChoiceDescription "&0 Screen", `
        "Output results to Screen"

    $opt2 = New-Object System.Management.Automation.Host.ChoiceDescription "&1 CSV File", `
        "Output results to a CSV file in a chosen directory"

    $options = [System.Management.Automation.Host.ChoiceDescription[]]($opt1, $opt2)
    
    $actionMenu = $host.ui.PromptForChoice($title, $message, $options, 0) 

    switch ($actionMenu)
    {
        0 { $fileLocation = "" }
        1 {
            $fileLocation = read-host -prompt "Please provide file location"
            if(!$fileLocation.EndsWith("\")){$fileLocation+="\"}
        }        
    }
    return $fileLocation
}

$authToken = GetAuthToken

# Main
while (mainControlFlow -at $authToken)
{

}