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
  - catalog: quay.io/modh/self-managed-rhods-index:beta
    packages:
    - name: rhods-operator
      channels:
      - name: beta  
  additionalImages:
  - name: registry.redhat.io/openshift4/ose-oauth-proxy:v4.8
  - name: registry.redhat.io/openshift4/ose-prometheus
  - name: registry.redhat.io/openshift4/ose-prometheus-alertmanager
  - name: registry.access.redhat.com/ubi8/ubi-minimal:8.4-208
  - name: registry.redhat.io/rhel8/grafana:7
EOF


oc mirror --config=/tmp/imageset-config.yaml   docker://local-quay.example.com:8443/mirror/oc-mirror-metadata 
oc create -f  oc-mirror-workspace/results-* 