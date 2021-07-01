---
title: Statefulsets with preexisting Persistent Volumes 
tags: ['kubernetes', 'statefulset','persistentvolume','preexisting']
status: draft
---
# Statefulsets with preexisting Persistent Volumes

TLDR; In this blog post, we will talk about how you can use preexisting Persistent Volumes with statefulsets.

  *[Arnav Jain](https://www.linkedin.com/in/arnav-jain-5545a574/) and Murat Celep has worked on this article together.*

## Why?

[StatefulSet](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/) is a K8S construct that comes into play when a piece of software that runs with multiple replicas and each replica needs its own version of data. So imagine a datababase cluster consisting of 3 nodes. If each node, has a specific part of the data and when one of those nodes gets rescheduled, it needs to connect to the same Persistent Volume that it initially connected with. StatefulSets, makes sure that a Persistent Volume is associated with a pod and it makes sure throughout the lifecycle of the Pod always the same Persistent Volume is used.

In many K8S installations, NFS becomes the initial choice for hosting Persistent Volumes. The reason is quite simple. Most of the organizations have already invested in a NFS based storage solution and it's quite straight-forward to set up K8S to connect to NFS for enabling Persistent Volumes. And although there are some solutions out there to automatically provision NFS backed Persistent Volumes(such as [this](https://github.com/kubernetes-sigs/sig-storage-lib-external-provisioner)), K8S platform teams - aspecially in the earlier stages of their K8S journey - end up provisining Persistent Volumes manually. Moreover, there might be other reasons why you haven't/can't enable dynamic Persistent Volume provisioning in your K8S cluster.

Statefulset relies on an element called ```volumeClaimTemplates``` to control how PersistentVolumeClaims are used to map each PersistentVolume to a specific Pod/Replica.

##<a name="pattern"></a> How?

StatefulSet uses the following pattern to generate PersistentVolumeClaim names:

```
"{.spec.volumeClaimTemplates[*].metadata.name}" + "-" + "{.metadata.name}" + "-"+ "$index"
```

If an existing PersistentVolumeClaim is already available in the samenamepsace where the StatefulSet object is, it will just reuse the existing PersistentVolumeClaim instead of creating new ones.


## Action

Below is an example StatefulSet resource yaml file:
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: nginx
spec:
  selector:
    matchLabels:
      app: nginx
  serviceName: "nginx"
  replicas: 2
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: k8s.gcr.io/nginx-slim:0.8
        ports:
        - containerPort: 80
          name: web
        volumeMounts:
        - name: pvc
          mountPath: /usr/share/nginx/html
  volumeClaimTemplates:
  - metadata:
      name: pvc
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 1Gi
```

Notice that under ```volumeClaimTemplates``` key, we have a single volumeClaimTemplate that has name ```pvc```.  For the StatefulSet object we use name ```nginx```. Based on the  [pattern](#pattern), we will need two PersistentVolumeClaim resources with the following names: ```pvc-nginx-0``` and ```pvc-nginx-1```. Below is the definition for those PersistentVolumes Claims


```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-nginx-0
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-nginx-1
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```

### Beware
You should be aware of the fact that when you use preexisting PersistentVolumeClaims, the ```spec``` section of the ```volumeClaimTemplates``` within a StatefulSet, will not have any impact on the actual PersistentVolume e.g. if you use the PersistentVolumeClaim resources above, the Persistent Volumes are requested with a volume of 1Gi and neither ```accessModes``` nor ```storage``` elements of ```volumeClaimTemplates``` will change the preexisting Persistent Volumes.
