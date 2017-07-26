
#############################
# Settings. Please edit.
#############################
  
#Your server URL. Do not forget the 'x' at the end
$global:server_url = 'http://urbackup.domain.com:55414/x'

# Login user needs following rights
#   "status": "some"
#   "add_client": "all"
# Optionally, to be able to
# install existing clients:
#   "settings": "all"
$server_username='XXXX'
$server_password='XXXX'
  
  
#############################
# Global script variables.
# Please do not modify.
# Only modify something after this line
# if you know what you are doing
#############################

$global:session=""
$global:headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$global:headers.add("Accept", 'application/json')
$global:headers.add("Content-Type", 'application/json; charset=UTF-8')


Function get_response($action, $params, $method, $download)
{
	
    $payload = "a=" + $action
	$curr_Server_Url = $global:server_url + "?" + $payload
	if($global:session.Length -gt 0)
		{
			$params['ses']=$global:session
		}
	if($method -eq 'GET')
		{
            $tempparams = [uri]::EscapeDataString($params)
            write-host $tempparams

			$curr_Server_Url+="&"+$tempparams
		}
	$target = [System.Uri]$curr_Server_Url
	$curr_Server_Url = '"'+$curr_Server_Url+'"'
    
	if(-Not $method){
		$method = "Get"
	}
	if ($method -eq "Post")
	{
		$body = $params
	}
	else
	{
		$body = ''
	}

    if($download)
	{
        
		$response = Invoke-RestMethod -Uri $target -Method $method -Body $body -Headers $global:headers -Outfile $download
	}
	else
	{
        $response = Invoke-RestMethod -Uri $target -Method $method -Body $body -Headers $global:headers 	
	}
	
	
	return $response
}

Function get_json($action, $params = @{})
{
	$response = get_response $action $params "Post" ''
	$httpStatusCode = $response.StatusCode.value_
	if($httpStatusCode -ne 200)
	{
		return ""
	}
	$data = $response.Content
	return (Get-Content $data -join "`n" | ConvertFrom-Json)
}

function download_file($action, $outputfn, $params)
{
	$response = get_response $action $params 'GET' $outputfn
	if(![System.IO.File]::Exists(".\"+$outputfn)){
		return 0
	}
	return 1
}
$payload = @{username = $server_username} | ConvertTo-Json
$salt = get_json 'salt' $payload
if(-Not ('ses' -in $salt)){
	Write-Host "Username Does Not Exist"
	exit
}
$session = $salt["ses"]






	
	