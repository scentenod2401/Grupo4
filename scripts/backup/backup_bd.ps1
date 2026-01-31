param($Host, $User)
ssh $User@$Host "mysqldump --all-databases | gzip > /tmp/db-$(date +%Y%m%d).sql.gz"