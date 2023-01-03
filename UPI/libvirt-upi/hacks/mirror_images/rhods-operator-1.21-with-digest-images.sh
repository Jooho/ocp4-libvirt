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
    imageURL: registry.example:5000/mirror/oc-mirror-metadata                 # Update    
    skipTLS: false
mirror:
  operators:
  - catalog: registry.redhat.io/redhat/redhat-operator-index:v4.11            # Need to check
    packages:
    - name: rhods-operator
      channels:
      - name: stable 
  additionalImages:
  - name: quay.io/integreatly/prometheus-blackbox-exporter@sha256:35b9d2c1002201723b7f7a9f54e9406b2ec4b5b0f73d114f47c70e15956103b5 
  - name: quay.io/modh/cuda-notebooks@sha256:348fa993347f86d1e0913853fb726c584ae8b5181152f0430967d380d68d804f
  - name: quay.io/modh/cuda-notebooks@sha256:492c37fb4b71c07d929ac7963896e074871ded506230fe926cdac21eb1ab9db8
  - name: quay.io/modh/odh-generic-data-science-notebook@sha256:ebb5613e6b53dc4e8efcfe3878b4cd10ccb77c67d12c00d2b8c9d41aeffd7df5
  - name: quay.io/modh/odh-minimal-notebook-container@sha256:a5a7738b09a204804e084a45f96360b568b0b9d85709c0ce6742d440ff917183
  - name: quay.io/modh/cuda-notebooks@sha256:2163ba74f602ec4b3049a88dcfa4fe0a8d0fff231090001947da66ef8e75ab9a
  - name: quay.io/modh/etcd-container@sha256:35581ad49d7bbdbb9aea6c517c35c5869c0cc7c5f0a45f50fec7c185c389d7f4
  - name: quay.io/openshift/origin-deployer@sha256:baa1a8672911cd3dd71a83f91f534ba865b74027f7c1f53196100c8779d930b7
  - name: quay.io/modh/must-gather@sha256:2a5abc16745d72c14c4144d89edbe373d6d56c8b6ce7965fcbed1862519092ab
EOF


oc mirror --config=/tmp/imageset-config.yaml   docker://local-quay.example.com:8443/mirror/oc-mirror-metadata 
oc create -f  oc-mirror-workspace/results-* 