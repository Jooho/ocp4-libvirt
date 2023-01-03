#!/bin/bash

jq '.transports.docker. +={"registry.redhat.io/redhat/community-operator-index":[{"type": "insecureAcceptAnything"}]}' /etc/containers/policy.json
jq '.transports.docker. +={"registry.redhat.io/redhat/certified-operator-index":[{ "type": "signedBy","keyType": "GPGKeys","keyPath": "/etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-isv"}]}' /etc/containers/policy.json
jq '.transports.docker. +={"registry.redhat.io/redhat/redhat-marketplace-index":[{ "type": "signedBy","keyType": "GPGKeys","keyPath": "/etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-isv"}]}' /etc/containers/policy.json


prefix=local-quay.example.com:8443/mirror/oc-mirror-metadata

for i in  quay.io/modh/odh-deployer-container:v1.16.0-6 \
          quay.io/modh/odh-operator-container:v1.16.0-6  \
          quay.io/modh/odh-minimal-notebook-container:v1.16.0-6 \
          quay.io/modh/odh-dashboard-container:v1.16.0-6 \
          quay.io/modh/odh-notebook-controller-container:v1.16.0-6 \
          quay.io/modh/odh-kf-notebook-controller-container:v1.16.0-6 \
          quay.io/integreatly/prometheus-blackbox-exporter:v0.19.0
do 
  podman pull $i
  postfix=$(echo $i|sed 's/quay.io\///g')
  echo "podman tag $i ${prefix}/${postfix}"
  podman tag $i ${prefix}/${postfix}
  podman push ${prefix}/${postfix}
done


cat <<EOF > /tmp/imageset-config.yaml 
kind: ImageSetConfiguration
apiVersion: mirror.openshift.io/v1alpha2
archiveSize: 4                                                      
storageConfig:                                                      
  registry:
    imageURL: local-quay.example.com:8443/mirror/oc-mirror-metadata                 
    skipTLS: false
mirror:                                                     
  operators:
  - catalog: registry.redhat.io/redhat/community-operator-index:v4.11
    packages:
    - name: nfs-provisioner-operator
      channels:
      - name: alpha
  - catalog: quay.io/jooholee/rhods-operator-live-catalog:1.18.0-digest
    packages:
    - name: rhods-operator
      channels:
      - name: beta  
EOF


oc mirror --config=/tmp/imageset-config.yaml   docker://local-quay.example.com:8443/mirror/oc-mirror-metadata 
oc create -f  oc-mirror-workspace/results-* 