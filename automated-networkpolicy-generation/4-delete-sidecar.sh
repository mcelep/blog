#!/bin/bash

source env.sh
DEPLOYMENTS=$(kubectl get deployment -n $TARGET_NS -o name)

for d in $DEPLOYMENTS
do
  INDEX=$(kubectl get $d -n $TARGET_NS -o json  | jq '.spec.template.spec.containers | map(.name == "tcpdump") | index(true)')
  kubectl -n $TARGET_NS patch $d --type=json -p="[{'op': 'remove', 'path': '/spec/template/spec/containers/$INDEX'}]"
done
