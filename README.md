# aro-preview-gov-deployment

### [Deploy ARO](https://docs.microsoft.com/en-us/azure/openshift/tutorial-create-cluster)
### [Networking Config](https://docs.microsoft.com/en-us/azure/openshift/concepts-networking#whats-new-in-openshift-45)

1. Login to Azure Gov Account:

```
az cloud set --name AzureUSGovernment
az login
```

2. Run the following:

> Note: Add the pull-secret.txt file to the root where `deploy-aro.sh` is located

```
./deploy-aro.sh
```