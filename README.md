# aro-preview-gov-deployment

### [Deploy ARO](https://docs.microsoft.com/en-us/azure/openshift/tutorial-create-cluster)
### [Networking Config](https://docs.microsoft.com/en-us/azure/openshift/concepts-networking#whats-new-in-openshift-45)

### Prereq:

0. Run the following:

```
LOCATION=usgovvirginia
az vm list-usage -l $LOCATION \
--query "[?contains(name.value, 'standardDSv3Family')]" \
-o table
```

1. Login to Azure Gov Account:

```
az cloud set --name AzureUSGovernment
az login
```

2. [Generate a Pull Secret from Red Hat](https://sso.redhat.com/auth/realms/redhat-external/protocol/openid-connect/auth?client_id=cloud-services&redirect_uri=https%3A%2F%2Fconsole.redhat.com%2Fopenshift%2Finstall%2Fazure%2Faro-provisioned&state=ebbc60c4-2c03-4705-8da7-6621a57c5fbc&response_mode=fragment&response_type=code&scope=openid&nonce=4594aa13-0a68-4769-818b-0ca6d72a37a1)

3. Run the following:

> Note: Add the pull-secret.txt file to the root where `deploy-aro.sh` is located

```
./deploy-aro.sh
```

LOCATION=usgovvirginia
az vm list-usage -l $LOCATION \
--query "[?contains(name.value, 'standardDSv3Family')]" \
-o table