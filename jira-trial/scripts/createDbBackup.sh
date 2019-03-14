#!/usr/bin/env bash

# 2018 j.peschke@syseleven.de

myBucket=dbdump-$(date +%F)
dbdump=mysqldump-syseleven-$(date +%F).sql

# check for valid s3 credentials or exit

checkObjectCred(){
 if s3cmd ls; then
    echo "Found valid SEOS credentials"
 else
    echo "Your credentials does not seem to work!"
 fi
}

# check if defined backup bucket exists. If not, create one
checkIfBucketExists(){
 if s3cmd ls s3://$myBucket; then 
  echo "Backup bucket $myBucket exists..."
 else 
  echo "Backup bucket $myBucket will be created."
  s3cmd mb s3://$myBucket
 fi
}

# make a fresh mysql dump

createDump(){
 mysqldump syseleven > $dbdump
}

# put the dump online
saveDump(){
 s3cmd put $dbdump s3://$myBucket
}
# 

checkObjectCred
checkIfBucketExists
createDump
saveDump

