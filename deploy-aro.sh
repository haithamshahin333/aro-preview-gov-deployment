#!/bin/bash

# Written by Stuart Kirk
# stuart.kirk@microsoft.com
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
# NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# API and INGRESS server configuration must be set to either "Public" or "Private" (case sensitive)


################################################################################################## Initialize


if [ $# -gt 1 ]; then
    echo "Usage: $BASH_SOURCE <Custom Domain eg. aro.foo.com>"
    exit 1
fi

# Random string generator - don't change this.
RAND="$(echo $RANDOM | tr '[0-9]' '[a-z]')"
export RAND

# Customize these variables as you need for your cluster deployment
APIPRIVACY="Public"
INGRESSPRIVACY="Public"
LOCATION="usgovvirginia"
VNET="10.133.0.0"
VNET_RG=""
WORKERS="3"
WORKER_SIZE="Standard_D4s_v3"

################################################ Don't change these
export APIPRIVACY
export INGRESSPRIVACY
export LOCATION
export VNET
export VNET_RG
export WORKERS
export WORKER_SIZE

BUILDDATE="$(date +%Y%m%d-%H%M%S)"
export BUILDDATE
CLUSTER="aro-$(whoami)-$RAND"
export CLUSTER
RESOURCEGROUP="$CLUSTER-$LOCATION"
export RESOURCEGROUP
SUBID="$(az account show -o tsv --query id)"
export SUBID
VNET_NAME="$CLUSTER-vnet"
export VNET_NAME
VNET_OCTET1="$(echo $VNET | cut -f1 -d.)"
export VNET_OCTET1
VNET_OCTET2="$(echo $VNET | cut -f2 -d.)"
export VNET_OCTET2
if [ -z "$VNET_RG" ]; then
    VNET_RG="$RESOURCEGROUP"
    export VNET_RG
fi

################################################################################################## Infrastructure Provision


echo " "
echo "Building Azure Red Hat OpenShift 4"
echo "----------------------------------"

if [ -n "$(az provider show -n Microsoft.Compute -o table | grep -E '(Unregistered|NotRegistered)')" ]; then
    echo "The Azure Compute resource provider has not been registered for your subscription $SUBID."
    echo -n "I will attempt to register the Azure Compute RP now (this may take a few minutes)..."
    az provider register -n Microsoft.Compute --wait > /dev/null
    echo "done."
    echo -n "Verifying the Azure Compute RP is registered..."
    if [ -n "$(az provider show -n Microsoft.Compute -o table | grep -E '(Unregistered|NotRegistered)')" ]; then
        echo "error! Unable to register the Azure Compute RP. Please remediate this."
        exit 1
    fi
    echo "done."
fi

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

if [ -n "$(az provider show -n Microsoft.Storage -o table | grep -E '(Unregistered|NotRegistered)')" ]; then
    echo "The storage provider has not been registered for your subscription $SUBID."
    echo -n "I will attempt to register the storage RP now (this may take a few minutes)..."
    az provider register -n Microsoft.Storage --wait > /dev/null
    echo "done."
    echo -n "Verifying the storage is registered..."
    if [ -n "$(az provider show -n Microsoft.Storage -o table | grep -E '(Unregistered|NotRegistered)')" ]; then
        echo "error! Unable to register the storage RP. Please remediate this."
        exit 1
    fi
    echo "done."
fi

if [ $# -eq 1 ]; then
    CUSTOMDNS="--domain=$1"
    export CUSTOMDNS
    echo "You have specified a parameter for a custom domain: $1. I will configure ARO to use this domain."
    echo " "
fi

# Resource Group Creation
echo -n "Creating Resource Group..."
az group create -g "$RESOURCEGROUP" -l "$LOCATION" -o table >> /dev/null 
echo "done"

# VNet Creation
echo -n "Creating Virtual Network..."
az network vnet create -g "$VNET_RG" -n $VNET_NAME --address-prefixes $VNET/16 -o table > /dev/null
echo "done"

# Subnet Creation
echo -n "Creating 'Master' Subnet..."
az network vnet subnet create -g "$RESOURCEGROUP" --vnet-name $VNET_NAME -n "$CLUSTER-master" --address-prefixes "$VNET_OCTET1.$VNET_OCTET2.$(shuf -i 0-254 -n 1).0/24" --service-endpoints Microsoft.ContainerRegistry -o table > /dev/null
echo "done"
echo -n "Creating 'Worker' Subnet..."
az network vnet subnet create -g "$RESOURCEGROUP" --vnet-name $VNET_NAME -n "$CLUSTER-worker" --address-prefixes "$VNET_OCTET1.$VNET_OCTET2.$(shuf -i 0-254 -n 1).0/24" --service-endpoints Microsoft.ContainerRegistry -o table > /dev/null
echo "done"

# VNet & Subnet Configuration
echo -n "Disabling 'PrivateLinkServiceNetworkPolicies' in 'Master' Subnet..."
az network vnet subnet update -g "$RESOURCEGROUP" --vnet-name $VNET_NAME -n "$CLUSTER-master" --disable-private-link-service-network-policies true -o table > /dev/null
echo "done"

# echo -n "Adding ARO RP Contributor access to VNET..."
# az role assignment create --scope /subscriptions/$SUBID/resourceGroups/$RESOURCEGROUP/providers/Microsoft.Network/virtualNetworks/$VNET_NAME --assignee f1dd0a37-89c6-4e07-bcd1-ffd3d43d8875 --role "Contributor" -o table > /dev/null
# echo "done"

# Pull Secret
echo -n "Checking if pull-secret.txt exists..."
if [ -f "pull-secret.txt" ]; then
    echo "detected"
    echo -n "Removing extra characters from pull-secret.txt..."
    tr -d "\n\r" < pull-secret.txt >pull-secret.tmp
    rm -f pull-secret.txt
    mv pull-secret.tmp pull-secret.txt
    echo "done"
    PULLSECRET="--pull-secret=$(cat pull-secret.txt)"
    export PULLSECRET
else
    echo "not detected."
fi
echo " "

################################################################################################## Build ARO

# Build ARO
echo "=============================================================================================================================================================================="
echo "Building Azure Red Hat OpenShift with $WORKERS x $WORKER_SIZE sized workers - this takes roughly 30-40 minutes. The time is now: $(date)..."
echo " "
echo "Executing: "
echo "az aro create -g $RESOURCEGROUP -n $CLUSTER --cluster-resource-group $RESOURCEGROUP-cluster --vnet=$VNET_NAME --vnet-resource-group=$VNET_RG --master-subnet=$CLUSTER-master --worker-subnet=$CLUSTER-worker --ingress-visibility=$INGRESSPRIVACY --apiserver-visibility=$APIPRIVACY --worker-count=$WORKERS --worker-vm-size=$WORKER_SIZE $CUSTOMDNS $PULLSECRET -o table"
echo " "
time az aro create -g "$RESOURCEGROUP" -n "$CLUSTER" --cluster-resource-group "$RESOURCEGROUP-cluster" --vnet="$VNET_NAME" --vnet-resource-group="$VNET_RG" --master-subnet="$CLUSTER-master" --worker-subnet="$CLUSTER-worker" --ingress-visibility="$INGRESSPRIVACY" --apiserver-visibility="$APIPRIVACY" --worker-count="$WORKERS" --worker-vm-size="$WORKER_SIZE" $CUSTOMDNS $PULLSECRET  --tags test-tag=tagged -o table

################################################################################################## Post Provisioning

# Update ARO RG tags
echo " "
echo -n "Updating resource group tags..."
DOMAIN="$(az aro show -n $CLUSTER -g $RESOURCEGROUP -o tsv --query 'clusterProfile.domain' 2>/dev/null)"
export DOMAIN
VERSION="$(az aro show -n $CLUSTER -g $RESOURCEGROUP -o tsv --query 'clusterProfile.version' 2>/dev/null)"
export VERSION
az group update -g "$RESOURCEGROUP" --tags "ARO $VERSION Build Date=$BUILDDATE" -o table >> /dev/null 2>&1
echo "done."

# Forward Zone Creation (if necessary)
if [ -n "$CUSTOMDNS" ]; then
    DNS="$(echo $CUSTOMDNS | cut -f2 -d=)"
    export DNS
    if [ -z "$(az network dns zone list -o tsv --query '[*].name' | grep $DNS)" ]; then
        echo -n "A DNS zone was not detected for $DNS. Creating..."
	az network dns zone create -n $DNS -g $RESOURCEGROUP -o table >> /dev/null 2>&1
        echo "done." 
        echo " "
        echo "Dumping nameservers for newly created zone..." 
        az network dns zone show -n $DNS -g $RESOURCEGROUP -o tsv --query 'nameServers'
        echo " "
    else
        echo "A DNS zone was already detected for $DNS. Skipping zone creation..."
    fi
    DNSRG="$(az network dns zone list -o table |grep $DNS | awk '{print $2}')"
    export DNSRG
    if [ -z "$(az network dns record-set list -g $DNSRG -z $DNS -o table |grep api)" ]; then
        echo -n "An A record for the ARO API does not exist. Creating..." 
        IPAPI="$(az aro show -n $CLUSTER -g $RESOURCEGROUP -o tsv --query apiserverProfile.ip)"
	export IPAPI
	az network dns record-set a add-record -z $DNS -g $DNSRG -a $IPAPI -n api -o table >> /dev/null 2>&1
        echo "done."
    else
        echo "An A record appears to already exist for the ARO API server. Please verify this in your DNS zone configuration."
    fi
    if [ -z "$(az network dns record-set list -g $DNSRG -z $DNS -o table |grep apps)" ]; then
        echo -n "An A record for the apps wildcard ingress does not exist. Creating..."
        IPAPPS="$(az aro show -n $CLUSTER -g $RESOURCEGROUP -o tsv --query ingressProfiles[*].ip)"
	export IPAPPS
        az network dns record-set a add-record -z $DNS -g $DNSRG -a $IPAPPS -n *.apps -o table >> /dev/null 2>&1
        echo "done."
    else
        echo "An A record appears to already exist for the apps wildcard ingress. Please verify this in your DNS zone configuration."
    fi
fi

################################################################################################## Output Messages


echo " "
echo "$(az aro list-credentials -n $CLUSTER -g $RESOURCEGROUP -o table 2>/dev/null)"

echo " "
echo "$APIPRIVACY Console URL"
echo "-------------------"
echo "$(az aro show -n $CLUSTER -g $RESOURCEGROUP -o tsv --query 'consoleProfile.url' 2>/dev/null)"

echo " "
echo "$APIPRIVACY API URL"
echo "-------------------"
echo "$(az aro show -n $CLUSTER -g $RESOURCEGROUP -o tsv --query 'apiserverProfile.url' 2>/dev/null)"

echo " "
echo "To delete this ARO Cluster"
echo "--------------------------"
echo "az aro delete -n $CLUSTER -g $RESOURCEGROUP -y ; az group delete -n $RESOURCEGROUP -y"

if [ -n "$CUSTOMDNS" ]; then

    echo " "
    echo "To delete the two A records in DNS"
    echo "----------------------------------"
    echo "az network dns record-set a delete -g $DNSRG -z $DNS -n api -y ; az network dns record-set a delete -g $DNSRG -z $DNS -n *.apps -y"
fi

echo " "
echo "-end-"
echo " "
