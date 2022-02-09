## Prereqs

1. Confirm you are in the right Azure Cloud:

```bash

# View the cloud list
az cloud list -o table

# Input the proper cloud name
az cloud set --name <NAME>
```

2. Create a resource group for you deployment:

```bash
az group create \
    --location $ARO_LOCATION \
    --name $ARO_RG
```

3. Create the vnet and associated subnets with the proper policies:

```bash
az network vnet create \
    --resource-group $ARO_RG \
    --name $VNET \
    --address-prefixes <>

az network vnet subnet create \
    --resource-group $ARO_RG \
    --vnet-name $VNET \
    --name "$VNET-control-plane" \
    --address-prefixes <>

az network vnet subnet create \
    --resource-group $ARO_RG \
    --vnet-name $VNET \
    --name "$VNET-worker" \
    --address-prefixes <>

az network vnet subnet update \
    --resource-group $ARO_RG \
    --vnet-name $VNET \
    --name "$VNET-control-plane" \
    --disable-private-link-service-network-policies true
```

## Deploy

1. Specify your .env file:

```bash
set -a
source .env
set +a
```

2. Run the deployment:

```bash
./deploy-aro-cli.sh
```

3. [Update DNS](https://docs.microsoft.com/en-us/azure/openshift/tutorial-create-cluster#prepare-a-custom-domain-for-your-cluster-optional)
