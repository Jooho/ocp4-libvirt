 #!/bin/bash
# https://access.redhat.com/solutions/6542281
# In order to download community operator, this GPG has to be added
sudo curl -s -o /etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-isv https://www.redhat.com/security/data/55A34A82.txt
jq '.transports.docker. +={"registry.redhat.io/redhat/community-operator-index":[{"type": "insecureAcceptAnything"}]}' /etc/containers/policy.json
jq '.transports.docker. +={"registry.redhat.io/redhat/certified-operator-index":[{ "type": "signedBy","keyType": "GPGKeys","keyPath": "/etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-isv"}]}' /etc/containers/policy.json
jq '.transports.docker. +={"registry.redhat.io/redhat/redhat-marketplace-index":[{ "type": "signedBy","keyType": "GPGKeys","keyPath": "/etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-isv"}]}' /etc/containers/policy.json


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
EOF

oc mirror --config=/tmp/imageset-config.yaml   docker://local-quay.example.com:8443/mirror/oc-mirror-metadata 
oc create -f  oc-mirror-workspace/results-* 
