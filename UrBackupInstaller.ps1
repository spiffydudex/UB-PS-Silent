
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


#############################
# Function get_response
# Purpose: Compile a payload and pass information to the server.
# Retreive info from server and return.
# If parameter $download is set, Write an output file.
#############################
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
		$response = Invoke-RestMethod -Uri $target.AbsoluteUri -Method $method -Body $body -Headers $global:headers -Outfile $download
	}
	else
	{
        $response = Invoke-RestMethod -Uri $target.AbsoluteUri -Method $method -Body $body -Headers $global:headers 	
	}
	
	
	return $response
}

#############################
# Function get_json
# Pass info to the get_response function.
# if there is a bad response from the server return Nothing
# Return the content as string joining on new-line
#############################

Function get_json($action, $params = @{})
{
	$response = get_response $action $params "Post" ''
	return $response
}

#############################
# Function download_file
# output file from the server response
# This function may be unneeded in Powershell
# 
#############################

function download_file($action, $outputfn, $params)
{
	$response = get_response $action $params 'GET' $outputfn
	if(![System.IO.File]::Exists(".\"+$outputfn)){
		return 0
	}
	return 1
}


#############################
# Main Program Start
#
# 
#############################

$payload = @{username=$server_username}
$salt = get_json 'salt' $payload
if($salt.ses -ne ""){
	Write-Host "Username Does Not Exist"
	exit
}
Write-Host "We have a user"
$session = $salt.ses	

if($salt.salt -ne ""){
    $md5 = new-object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
    $utf8 = new-object -TypeName System.Text.UTF8Encoding
    $toEncode = $salt.salt + $server_password
    $password_md5_bin = [System.BitConverter]::ToString($md5.ComputeHash($utf8.GetBytes($toEncode)))
    $enc = [system.Text.Encoding]::UTF8
    $password_md5 = $enc.GetBytes([Convert]::ToString($password_md5_bin, 16))

    if($salt.pbkdf2_rounds -ne ""){
        $pbkdf2_rounds = [convert]::ToInt32($salt.pbkdf2_rounds, 10)

        if($pbkdf2_rounds -gt 0){
            $hmacsha = New-Object System.Security.Cryptography.HMACSHA256
            $hmacsha.key = [Text.Encoding]::ASCII.GetBytes([convert]::ToInt32($salt.salt, 10))
            $password_md5 = $hmacsha.ComputeHash([Text.Encoding]::ASCII.GetBytes($password_md5_bin))
        }
        $password_md5 = [System.BitConverter]::ToString($md5.ComputeHash($utf8.GetBytes($salt.rnd + $password_md5)))

        $payload = @{
            username=$server_username
            password=$password_md5
        }
        $login = get_json "login" $payload
        if ((!($login -contains 'success')) -or (!($login['success']))){
            Write-Host "Error during login. Password Wrong?"
            exit
        }
        $clientname = $env:computername
        Write-Host "Creating Client " + $clientname + "..."

        $payload = @{clientname= $clientname}
        $new_client = get_json "add_client" $payload
        if ($new_client -contains "already_exists"){
            $status = get_json "status"
            if($status -contains "client_downloads"){
              ForEach ($client in $status["client_downloads"]){
                if ($client["name"] -eq $clientname){
                    Write-Host "Downloading Installer..."
                    $payload = @{clientid=$client["id"]}
                    $downloads_status = download_file "download_client" "UrBackupUpdate.exe" $payload
                    if(!($downloads_status)){
                        Write-Host "Download of client failed."
                        exit
                    }
                }
              }
            }
            else{
                Write-Host "Client already exists and login user has probably no right to access existing clients"
                exit
            }
        }
        else{
            if (!($new_client -contains "new_authkey")){
                Write-Host "Error creating new client"
                exit
            }
            write-host "Downloading Installer..."
            #############################
            # Remaining functions yet to be written
            #############################
        }
    }

}