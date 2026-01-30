#!/bin/bash

LOCAL_DIR=/home/zapy/db_backups
S3_BUCKET=s3://s3-g4-bucket

aws s3 sync $LOCAL_DIR $S3_BUCKET

# Opcional: borrar los ya subidos
# rm -f $LOCAL_DIR/*.sql
