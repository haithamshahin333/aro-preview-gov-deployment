# aro-preview-gov-deployment

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