# Velero


Velero(formerly known as Heptio Ark) is arguably the most popular backup/restore solution for Kubernetes. It was created by Heptio and Velero continues to be actively developed as an open source project. [Here](https://github.com/vmware-tanzu/velero) is the github project and [this](https://velero.io/) is the official website.

In this blog post, we will present different options to backup/restore Kubernetes clusters running on vSphere and we will use [S3](https://docs.aws.amazon.com/AmazonS3/latest/API/Welcome.html) API based Object Store.

## Dependencies
You need a S3 API compatible object storage to use Velero. If you have already have a AWS(Amazon Web services) account, you can use a S3 bucket from your AWS account or if you want to just 'kick the tires', you can deploy an open-source alternative such as [MinIO](https://github.com/minio/minio) on your Kubernetes cluster.

Other than a Kubernetes cluster access, you also need the following tools:

- [Kubectl (Kubernetes CLI)](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [Helm CLI](https://helm.sh/docs/intro/install/)
- [Velero CLI](https://github.com/vmware-tanzu/velero/releases/latest)

## Velero Providers

Velero is based on *plugin design pattern* and depending on what cloud your kubernetes runs on and what Object Store you use, right plugins need to be installed and configured. In Velero terminology, this cloud plugins are called **providers**, you can see the list of plugins and their supported features [here](https://velero.io/docs/main/supported-providers/).

We will focus on a couple of different provider combinations in this blog post. The Object Store we will use will always be S3 based as it's the most common solution out there and we will use the AWS plugin for Object Store. For snapshotting volumes, we will talk about the following options: 
1. **Restic:**  [Restic](https://github.com/restic/restic) is a popular open-source tool and because is not tied to a specific storage platform, it gives you some flexilibity to migrate data between different cloud providers. It has some limitations too though which you can read [here](https://velero.io/docs/main/restic/#limitations)


1. **vSphere plugin**: vSphere has its own volume snapshot plugin: [velero-plugin-for-vsphere](https://github.com/vmware-tanzu/velero-plugin-for-vsphere). This plugin backups kubernetes persistent volumes to a S3 bucket.

1. **CSI VolumeSnapshots**:  [Container Storage Interface (CSI)](https://github.com/container-storage-interface/spec/blob/master/spec.md) has been promoted to GA in the Kubernetes v1.13 release and features that rely on CSI are being added to Kubernetes. One such feature is called [Volume Snaphots](https://kubernetes.io/docs/concepts/storage/volume-snapshots/) and this feature has been in **beta** state as of Kubernetes v1.17. In order to use this plugin, you have to make sure that CSI is configured correctly for storage provider of your kubernetes cluster e.g. if you use TKGI(Tanzu Kubernetes Grid Integrate), you can follow the steps explained [here](https://docs.pivotal.io/tkgi/1-9/vsphere-cns.html). As of 18.11.2020 *CSI Volume Snapshots* is not supported by *vsphere-csi-driver*; [here](https://github.com/kubernetes-sigs/vsphere-csi-driver/issues/228) is a relevant issue.


## Velero in action

### 1) Velero with Restic

In this section, we will create a step-by-step tutorial to:

- Install Velero with Restic enabled
- Create a test application with a Persistent Volume
- Create a backup of the application
- Delete the application
- Restore the application from the backup

#### Create namespace velero
We will install velero server side components into a namespace called *velero*, let's create a new namespace:
```bash
kubectl create ns velero
```

#### Create a Kubernetes secret for a AWS S3 bucket

Add your s3 Bucket access credential to `creds.txt` file. Replace the placeholders *<aws_access_key_id>* and *<aws_secret_access_key>* with actual values and create a new K8S secret with the content of the file:

```bash
kubectl -n velero create secret generic cloud-credentials --from-file=cloud=creds.txt
```

#### Install velero with Restic

We  need to opt-in for Restic installation in *values.yaml* with ```deployRestic: true``` and enable privileged mode to access Hostpath by using the following parameters: ```restic.podVolumePath``` and ```restic.privileged```.

For configuring a S3 bucket, we use ```configuration.backupStorageLocation.bucket``` and ```configuration.backupStorageLocation.config.region``` parameters. Note that, we also use a parameter called ```configuration.backupStorageLocation.prefix```. This parameter comes in handy, if we are to use the same S3 bucket for multiple clusters. With the help of the prefix, we can differentiate the cluster specific content easily, so it would make sense to use a prefix that clearly identifiers a Kubernetes cluster. Before executing the command below, make sure you replace the placeholders with the right values.

```bash
helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts
helm install velero vmware-tanzu/velero -f values.yaml \
    -n velero --version 2.13.6 \
    --set configuration.backupStorageLocation.bucket=<your-bucket> \
    --set configuration.backupStorageLocation.config.region=<aws-region> \
    --set configuration.backupStorageLocation.prefix=<some-prefix> \
    --set restic.podVolumePath=/var/lib/kubelet/pods \
    --set restic.privileged=true
```
(**Note:** for TKG hostpath should be ```/var/lib/kubelet/pods```, where as for TKGI(formerly known as PKS) *restic.podVolumePath* value should read ```/var/vcap/data/kubelet/pods```)

#### Create a backup && restore

When using restic to backup you need to add annotations to your pods which specify the volumes to backup. See `nginx-with-pv.yaml` for an example. Here is annotation:

```txt
annotations:
    backup.velero.io/backup-volumes: nginx-logs
```

Here are the steps to create a backup & restore from backup:

```bash
# Create application resources
kubectl apply -f example-app-with-pv.yaml
kubectl -n example-app get pods -w  # wait till pod is running
# Write some data into persistent volume(PV)
kubectl -n example-app exec -it "$(kubectl get pods -n example-app -o name)" --  bash -c "echo 'I persisted' > /opt/my-pvc/hi.txt"
# Check if data has persisted into PV
kubectl -n example-app exec -it "$(kubectl get pods -n example-app -o name)"  --  bash -c "cat /opt/my-pvc/hi.txt"
# Start velero backup
velero backup create backup1 --include-namespaces example-app --storage-location aws  --snapshot-volumes
# Delete application
kubectl delete namespaces example-app
# Make sure PV is gone
kubectl get pv -A | grep my-pvc #check no pv
# Restore the latest backup
velero restore create --from-backup backup1
kubectl get pods -n example-app # wait till pod is running
# Check if data has been restored
kubectl -n example-app exec -it "$(kubectl get pods -n example-app -o name)"   --  bash -c "cat /opt/my-pvc/hi.txt" 
```

#### Cleanup

```bash
kubectl delete ns velero
kubectl delete ns example-app
```
### 2) vSphere plugin

We will cover *vSphere plugin* based velero configuration in a different blog post.

### 3) CSI Volume VolumeSnapshots

We will cover *CSI VolumeSnapshots* based velero configuration in a different blog post [once it's available](https://github.com/kubernetes-sigs/vsphere-csi-driver/issues/228).
