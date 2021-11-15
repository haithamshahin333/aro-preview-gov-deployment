#!/bin/bash

# register the aro resource provider
if [ -n "$(az provider show -n Microsoft.RedHatOpenShift -o table | grep -E '(Unregistered|NotRegistered)')" ]; then
    echo "The ARO resource provider has not been registered for your subscription $SUBID."
    echo -n "I will attempt to register the ARO RP now (this may take a few minutes)..."
    az provider register -n Microsoft.RedHatOpenShift --wait > /dev/null
    echo "done."
    echo -n "Verifying the ARO RP is registered..."
    if [ -n "$(az provider show -n Microsoft.RedHatOpenShift -o table | grep -E '(Unregistered|NotRegistered)')" ]; then
        echo "error! Unable to register the ARO RP. Please remediate this."
        exit 1
    fi
    echo "done."
fi

az aro create \
    --name $ARO_NAME \
    --resource-group $ARO_RG \
    --location $ARO_LOCATION \
    --vnet-resource-group $VNET_RG \
    --vnet $VNET \
    --master-subnet $CONTROL_PLANE_SUBNET \
    --worker-subnet $WORKER_SUBNET \
    --location $ARO_LOCATION \
    --apiserver-visibility $ARO_VISIBILITY \
    --ingress-visibility $ARO_VISIBILITY \
    --worker-vm-size $ARO_WORKER_NODE_SIZE \
    --worker-count $ARO_WORKER_NODE_COUNT \
    --client-id $ARO_SP_CLIENT_ID \
    --client-secret $ARO_SP_CLIENT_SECRET \
    --pull-secret $ARO_PULL_SECRET \
    --domain $ARO_DOMAIN