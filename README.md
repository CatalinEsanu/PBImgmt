# PBImgmt
Manage your PBI env VIA Powershell Script

Please make sure that you fill in the $clientId pramater within the script.

Based on the following project:
https://github.com/Azure-Samples/powerbi-powershell/blob/master/rebindReport.ps1

## Current supported actions:

List Groups - Lists all groups (App Workspaces)
List Reports - List all reports or per specifc group   
List Datasets - List all datasets or per specifc group    
Clone Single Report - Clones a selected report   
Clone All App Reports - Clones all the reports in an app workspace for a selected dataset
Delete Report - Deletes a report
Rebind Report - Rebinds a report to a different datasource
Rebind Dataset - Changes a dataset's connection string
Get Dashboards - Lists dashboards
Get Tiles - Lists dashboard tiles