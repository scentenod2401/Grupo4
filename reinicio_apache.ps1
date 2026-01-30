param($Host, $User)

ssh $User@$Host "sudo systemctl restart apache2" 
