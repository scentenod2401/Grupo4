param($Host, $User)
ssh $User@$Host "sudo systemctl restart mysql"

