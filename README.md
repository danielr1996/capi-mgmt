# CAPI

Setup a kind based management cluster for ClusterAPI

## Installation
> There are two supported environment, the local `capi-test` and the remote `capi-prod`
> 
> Configure `values/capi-test.sh` and `values/capi-prod.sh` with the credentials to a S3 Bucket and the prod ip address

```shell
createmanagementcluster <capi-test|capi-prod>
```

## Restore
```shell
# List Backups
kubectl get backups -n velero

# Restore Backup
velero restore create --from-backup <name>
```

