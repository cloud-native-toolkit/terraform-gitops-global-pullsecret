
# this script can be executed on a cluster node to append the cloud pak entitlement key

export IBM_ENTITLEMENT_KEY=<key>
export IBM_ENTITLEMENT_USER=cp
export IBM_ENTITLEMENT_SERVER=cp.icr.io


PASSWD=`echo "${IBM_ENTITLEMENT_USER}:${IBM_ENTITLEMENT_KEY}" | tr -d '\n' | base64 -i -w 0`

cp config.json config.json.backup
cat config.json | jq '.auths += {"'$IBM_ENTITLEMENT_SERVER'":{"auth":"'$PASSWD'"}}' > config.json.tmp
mv config.json.tmp config.json


