#!/bin/zsh

#authentication - you can fill in these lines and add your information if you don't want to be prompted interactively when the script runs
#the jamfURL should be exactly what you type into the address bar to access Jamf (no slash at the end)
jamfURL=""
jamfUsername=""
jamfPassword=""

if [ -z $jamfURL ]; then
	echo "Please enter the Jamf Pro URL (with no slash at the end):"
	read -r jamfURL
fi 

if [ -z $jamfUsername ]; then
	echo "Please enter your Jamf Pro username:"
	read -r jamfUsername
fi 

if [ -z $jamfPassword ]; then 
	echo "Please enter the Jamf Pro password for account: $jamfUsername:"
	read -r -s jamfPassword
fi

#encoding credentials so they aren't sent in plaintext
encodedCreds=$(printf "$jamfUsername:$jamfPassword" | iconv -t ISO-8859-1 | base64 -i -)

#using encoded credentials to get bearer token
token=$(curl -s "${jamfURL}/api/v1/auth/token" -H "Authorization: Basic $encodedCreds" -X POST | jq -r '.token')

#setting field separator to newline
IFS=$'\n'

#search number - you can fill in the search number here if you don't want to be prompted
#this search should have less than 2000 computers in it
searchNumber=""
if [ -z $searchNumber ]; then
	echo "Please enter the number of the advanced computer search you want to send the command to:"
	read -r searchNumber
fi 

#recovery password - you can fill in the recovery password here if you don't want to be prompted
recoveryPassword=""
if [ -z $recoveryPassword ]; then
	echo "Please enter the recovery password you would like to set on these computers:"
	read -r recoveryPassword
	echo "Password will be set to $recoveryPassword"
fi

#looping through computers in advanced search
computers=($(curl -s "${jamfURL}/JSSResource/advancedcomputersearches/id/$searchNumber" -H "Accept: application/json" -H "Authorization: Bearer ${token}" -X GET | jq ".advanced_computer_search.computers[].id" ))
	for computerID in "${computers[@]}"; do
		#get the Management ID for computers in the search
		echo "Processing computer number $computerID"
		managementID=$(curl -s "${jamfURL}/api/preview/computers?page-size=2000" -H "Accept: application/json" -H "Authorization: Bearer ${token}" | jq -r '.results[] | select (.id=='\"$computerID\"') | .managementId' )
		#send the recovery lock command
		curl -s "${jamfURL}/api/preview/mdm/commands" -H "Content-Type: application/json" -H "Authorization: Bearer ${token}" -X POST -d "{\"clientData\":[{\"managementId\":\""$managementID"\",\"clientType\":\"COMPUTER\"}],\"commandData\":{\"commandType\": \"SET_RECOVERY_LOCK\",\"newPassword\":\""$recoveryPassword"\"}}"	1 > /dev/null
		echo "Recovery Lock command sent to computer number $computerID."
	done

#cleaning up
curl -s -k "${jamfURL}/api/v1/auth/invalidate-token" -H "Authorization: Bearer ${token}" -X POST
unset IFS

echo "Complete. All computers in the advanced search have been sent the Recovery Lock command."