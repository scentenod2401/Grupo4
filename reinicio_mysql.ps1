param($Host, $User)
ssh $User@$Host "sudo systemctl restart mysql && echo OK"  # o mariadb
