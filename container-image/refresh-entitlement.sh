#!/bin/sh

oc login --token=`cat /var/run/secrets/kubernetes.io/serviceaccount/token` https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_SERVICE_PORT --insecure-skip-tls-verify

SUB_USER_KEY_PATH=/etc/pki/entitlement/user_key.pem
SUB_USER_CERT_PATH=/etc/pki/entitlement/user_cert.pem

while true; do 
    if [ ! -f $SUB_USER_CERT_PATH ] && [ ! -f $SUB_USER_KEY_PATH ]; then 
        echo -e ">> Cannot find the entitlement key and certificate under the paths $SUB_USER_KEY_PATH and $SUB_USER_CERT_PATH respectively \n"
    else 
        entitlement_key=$(curl -sk --cert $SUB_USER_CERT_PATH --key $SUB_USER_KEY_PATH 'https://subscription.rhsm.redhat.com/subscription/consumers/'${SYSTEM_UUID}'/entitlements' | jq -r '.[0].certificates[0].key' | base64 -w0)
        entitlement_cert=$(curl -sk --cert $SUB_USER_CERT_PATH --key $SUB_USER_KEY_PATH 'https://subscription.rhsm.redhat.com/subscription/consumers/'${SYSTEM_UUID}'/entitlements' | jq -r '.[0].certificates[0].cert' | base64 -w0)

        # if [ -z $last_entitlement_key ]; then 
        #     last_entitlement_key=$entitlement_key
        # fi 

        # if [ -z $last_entitlement_cert ]; then 
        #     last_entitlement_cert=$entitlement_cert
        # fi 

        echo ">> Checking for MC 50-machine-entitlements"
        oc get mc 50-machine-entitlements

        if [[ $? != 0 ]]; then 
            echo ">> MC 50-machine-entitlements doesn't exist, creating one now."
            sed  "s/BASE64_ENCODED_KEY_PEM_FILE/${entitlement_key}/g" 50-machine-entitlements.yaml.template > /tmp/50-machine-entitlements.yaml
            sed  -i "s/BASE64_ENCODED_CERT_PEM_FILE/${entitlement_cert}/g" /tmp/50-machine-entitlements.yaml 
            echo ">> File 50-machine-entitlements.yaml created, applying to Openshift"
            oc apply -f /tmp/50-machine-entitlements.yaml
            if [[ $? != 0 ]]; then 
                echo -e "Applied the 50-machine-entitlements MC successfully\n"
                last_entitlement_key=$entitlement_key
                last_entitlement_cert=$entitlement_cert
            else
                echo -e ">> Failed to apply the 50-machine-entitlement MC. Exiting!\n"
                exit
            fi
        elif [ "$last_entitlement_key" != "$entitlement_key" ] || [ "$last_entitlement_cert" != "$entitlement_cert" ]; then
            
            echo ">> Updated key and/or cert found!"

            # Prevent MC from restarting nodes until we are finished (optional)
            oc patch --type=merge \
                    --patch='{"spec":{"paused":true}}' machineconfigpool/worker

            # Update the key in your cluster
            oc patch machineconfigs 50-machine-entitlements \
                    --type json \
                    -p='[{"op": "replace", "path": "/spec/config/storage/files/1/contents/source", "value": "data:text/plain;charset=utf-8;base64,'${entitlement_key}'"}]'

            oc patch machineconfigs 50-machine-entitlements \
                    --type json \
                    -p='[{"op": "replace", "path": "/spec/config/storage/files/2/contents/source", "value": "data:text/plain;charset=utf-8;base64,'${entitlement_cert}'"}]'

            # Re-enable MC restarts so the updates can be applied (if neither file was updated, no restart will occur)
            oc patch --type=merge \
                    --patch='{"spec":{"paused":false}}' machineconfigpool/worker
            
            echo -e ">> MC 50-machine-entitlements is updated\n"

            last_entitlement_key=$entitlement_key
            last_entitlement_cert=$entitlement_cert
        else
            echo -e ">> No change in the key or cert discovered.\n"
        fi
    fi
    
    echo -e ">> Sleeping for $SLEEP_SECONDS seconds\n"
    sleep $SLEEP_SECONDS
done 
