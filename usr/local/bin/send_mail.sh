#!/bin/bash

declare -a VOPTS;
declare -a HOPTS;

sesAccess="sender.account.authentication@email.id" ;
sesSecret="sender.account.passwordXXXXXX";
sesFromName="Sender Full Name";
sesFromAddress='<sender@email.id>';
sesToName="Recipient Full Name";
sesToAddress="<recipient@email.id>"
sesSubject="Email Subject Line";
sesSMTP='mail.server.fqdn';
sesPort='465';
sesMessage=$'Test of line 1\nTest of line 2'
sesFile="$1"; # attachment is frist argument
sesHTMLbody="/path/to/html/file.html";

sesMIMEType=`file --mime-type "$sesFile" | sed 's/.*: //'`;
# sesMIMEType=`file -b --mime-type "$sesFile"`;

VOPTS=();
HOPTS=();

#Curl Options
VOPTS+=("-v");
VOPTS+=("--url"); VOPTS+=("smtps://$sesSMTP:$sesPort"); 
VOPTS+=("--ssl-reqd")
VOPTS+=("--user"); VOPTS+=("${sesAccess}:${sesSecret}"); 
VOPTS+=("--mail-from"); VOPTS+=("${sesFromAddress}");
VOPTS+=("--mail-rcpt"); VOPTS+=("${sesToAddress}");

#Header Options
HOPTS+=("-H"); HOPTS+=("Subject: ${sesSubject}");
HOPTS+=("-H"); HOPTS+=("From: ${sesFromName} ${sesFromAddress}"); 
HOPTS+=("-H"); HOPTS+=("To: ${sesToName} ${sesToAddress}"); 

curl "${VOPTS[@]}" -F '=(;type=multipart/mixed' -F "=<$sesHTMLbody;type=text/html;encoder=base64" -F "file=@$sesFile;type=$sesMIMEType;encoder=base64" -F '=)' "${HOPTS[@]}"

exit
