#!/bin/bash

# get params
while [[ $# > 1 ]]; do 
  case $1 in
    --access_key)
    access_key=$2
    ;;
    --secret_key)
    secret_key=$2
    ;;
    --s3_region)
    s3_region=$2
    ;;
    *)
    echo 'unknown parameter!'
    ;;
  esac
  shift 2
done

write_s3_config(){
# build a valid s3 credentials file:
cat <<EOF> /root/.s3cfg
[default]
access_key = ${access_key} 
secret_key = ${secret_key} 
host_base = s3.${s3_region}.cloud.syseleven.net
host_bucket = %(bucket).${s3_region}.s3.cloud.syseleven.net
use_https = True
check_ssl_certificate = True
check_ssl_hostname = False
EOF

}

if [[ -z ${access_key} || -z ${secret_key} ]]; then
 echo "parameter --access_key or --secret_key not given, exiting."
 exit 1
fi

if [[ -z ${s3_region} ]]; then
 s3_region="dbl"
 echo "parameter --s3_region not given; using \"dbl\" as fallback "
fi

write_s3_config
