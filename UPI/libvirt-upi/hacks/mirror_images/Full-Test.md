# Environment Variables
~~~
export test_home=/tmp/test
export quay_id=init
export quay_pw=Redhat_0123456
export quay_local_registry_url=local-quay.example.com
export quay_local_registry_port=443
export quay_root_ca=/etc/quay-install/quay-rootCA/rootCA.pem
export pull_secret_path=${test_home}/osia-configuration/ps.json
export catalogsource_url=brew.registry.redhat.io/rh-osbs/iib:408697

mkdir ${test_home}
cd ${test_home}

    #http://external-ci-coldstorage.datahub.redhat.com/cvp/cvp-redhat-operator-bundle-image-validation-test/odh-operator-bundle-container-vX.Y.Z-N/
~~~

# osia-configuration 
~~~
git clone https://gitlab.cee.redhat.com/AICoE/osia-configuration.git
cd osia-configuration
git crypt unlock ~/Documents/osia-key.key
~~~

# Install CRC 
~~~
crc setup
crc config set memory 40000
crc config set cpus 10
crc config set disk-size 70
crc config set kubeadmin-password kubeadmin
crc start
~~~

# Deploy Quay Registry
~~~
cd ${test_home}

wget https://developers.redhat.com/content-gateway/rest/mirror/pub/openshift-v4/clients/mirror-registry/latest/mirror-registry.tar.gz

tar xvf mirror-registry.tar.gz

# Add dummy network
sudo modprobe dummy
sudo ip link add eth0 type dummy
ip link show eth0 
sudo ifconfig eth0 hw ether C8:D7:4A:4E:47:50
sudo ip addr add 192.168.1.100/24 brd + dev eth0 label eth0:0
sudo ip link set dev eth0 up

echo "192.168.1.100 local-quay.example.com" >> /etc/hosts

./mirror-registry install  --quayHostname ${quay_local_registry_url}:${quay_local_registry_port} --initPassword ${quay_pw}  --initUser ${quay_id}

sudo cp ${quay_root_ca}   /etc/pki/ca-trust/source/anchors/
sudo update-ca-trust extract
~~~

# CRC Setup
~~~
podman login --authfile ${pull_secret_path}  -u ${quay_id} -p ${quay_pw}  ${quay_local_registry_url}:${quay_local_registry_port}

mv  ~/.docker/config.json ~/.docker/config.json.ori
cp  ${pull_secret_path} ~/.docker/config.json 

oc login -u kubeadmin https://api.crc.testing:6443
oc adm policy add-cluster-role-to-user cluster-admin developer
oc login -u developer https://api.crc.testing:6443

oc set data secret/pull-secret -n openshift-config --from-file=.dockerconfigjson=${pull_secret_path}

oc patch OperatorHub cluster --type json -p '[{"op": "add", "path": "/spec/disableAllDefaultSources","value": true}]'
   
# Add local-quay root cert 
cp ${quay_root_ca}  ca-bundle.crt
oc create configmap user-ca-bundle -n openshift-config --from-file=ca-bundle.crt

oc patch proxy/cluster -p '{"spec":{"trustedCA": {"name": "user-ca-bundle"}}}' --type=merge

#cat <<EOF | ssh -i ~/.crc/machines/crc/id_ecdsa -o StrictHostKeyChecking=no \
#                -q core@$(crc ip) "sudo tee /etc/containers/registries.conf"
#unqualified-search-registries = ["registry.access.redhat.com", "docker.io"]

#[[registry]]
#  prefix = ""
#  location = "registry-proxy.engineering.redhat.com"
#  mirror-by-digest-only = true
#  insecure = true
  
#  [[registry.mirror]]
#    location = "local-quay.example.com:443/mirror/oc-mirror-metadata"

#[[registry]]
#  prefix = ""
#  location = "registry.redhat.io"
#  mirror-by-digest-only = true
 
#  [[registry.mirror]]
#    location = "local-quay.example.com:443/mirror/oc-mirror-metadata"
 
#[[registry]]
#  prefix = ""
#  location = "registry.stage.redhat.io"
#  mirror-by-digest-only = true
 
#  [[registry.mirror]]
#    location = "local-quay.example.com:443/mirror/oc-mirror-metadata"
 
#[[registry]]
#  prefix = ""
#  location = "brew.registry.redhat.io"
#  mirror-by-digest-only = true
 
#  [[registry.mirror]]
#    location = "local-quay.example.com:443/mirror/oc-mirror-metadata"

#EOF

#cat ${pull_secret_path} | ssh -i ~/.crc/machines/crc/id_ecdsa -o StrictHostKeyChecking=no -q core@$(crc ip) "sudo tee /var/lib/kubelet/config.json"

ssh -i ~/.crc/machines/crc/id_ecdsa -o StrictHostKeyChecking=no \
    -q core@$(crc ip) "sudo systemctl restart crio kubelet"
~~~

# Mirroring Images
- RHODS
- NFS
- Minio (quay.io/opendatahub/modelmesh-minio-examples:v0.8.0)
~~~

cd ${test_home}

oc adm release mirror -a ${pull_secret_path} --from=quay.io/openshift-release-dev/ocp-release:4.11.13-x86_64 --to=local-quay.example.com:443/ocp4/openshift4 --to-release-image=local-quay.example.com:443/ocp4/openshift4:4.11.13-x86_64 --skip-verification=true

cat <<EOF | oc apply -f -
apiVersion: operator.openshift.io/v1alpha1
kind: ImageContentSourcePolicy
metadata:
  name: ocp4
spec:
  repositoryDigestMirrors:
  - mirrors:
    - local-quay.example.com:443/ocp4/openshift4
    source: quay.io/openshift-release-dev/ocp-release
  - mirrors:
    - local-quay.example.com:443/ocp4/openshift4
    source: quay.io/openshift-release-dev/ocp-v4.0-art-dev
EOF


cat <<EOF > ${test_home}/imageset-config.yaml 
kind: ImageSetConfiguration
apiVersion: mirror.openshift.io/v1alpha2
archiveSize: 4                                                      
storageConfig:                                                      
  registry:
    imageURL: local-quay.example.com:443/mirror/oc-mirror-metadata                 
    skipTLS: false
mirror:
  operators:
  - catalog: registry.redhat.io/redhat/community-operator-index:v4.11
    packages:
    - name: nfs-provisioner-operator
      channels:
      - name: alpha
  - catalog: ${catalogsource_url}          
    packages:
    - name: rhods-operator
      channels:
      - name: stable
      - name: beta
  additionalImages:
  - name: quay.io/modh/cuda-notebooks:cuda-jupyter-minimal-ubi8-python-3.8-c41c603
  - name: quay.io/modh/cuda-notebooks:cuda-jupyter-pytorch-ubi8-python-3.8-c41c603	
  - name: quay.io/modh/odh-generic-data-science-notebook@sha256:ebb5613e6b53dc4e8efcfe3878b4cd10ccb77c67d12c00d2b8c9d41aeffd7df5
  - name: quay.io/modh/odh-minimal-notebook-container@sha256:a5a7738b09a204804e084a45f96360b568b0b9d85709c0ce6742d440ff917183
  - name: quay.io/modh/cuda-notebooks:cuda-jupyter-tensorflow-ubi8-python-3.8-c41c603
  - name: quay.io/modh/must-gather:v1.0.0
  - name: quay.io/opendatahub/modelmesh-minio-examples:v0.8.0
  - name: registry.redhat.io/rhel8/support-tools
EOF

oc mirror --config=${test_home}/imageset-config.yaml   docker://${quay_local_registry_url}:${quay_local_registry_port}/mirror/oc-mirror-metadata   --continue-on-error 

cp oc-mirror-workspace/results-*/mapping.txt .
sed 's/^registry.redhat.io\/rhods/brew.registry.redhat.io\/rhods/g' mapping.txt |grep brew> mapping-brew.txt

oc image mirror -a ${pull_secret_path} -f mapping-brew.txt --filter-by-os='.*' --continue-on-error || true

oc create -f  oc-mirror-workspace/results-* 
~~~

# NFS Provioner
~~~
# Create a new namespace
oc new-project nfsprovisioner-operator

# Deploy NFS Provisioner operator in the terminal (You can also use OpenShift Console
cat << EOF | oc apply -f -  
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: nfs-provisioner-operator
  namespace: openshift-operators
spec:
  channel: alpha
  installPlanApproval: Automatic
  name: nfs-provisioner-operator
  source: community-operator-index
  sourceNamespace: openshift-marketplace
EOF


export target_node=$(oc get node -l node-role.kubernetes.io/worker= --no-headers -o name |head -1|cut -d'/' -f2)
oc label node/${target_node} app=nfs-provisioner

# ssh to the node
oc debug node/${target_node}

# Create a directory and set up the Selinux label.
 chroot /host
 mkdir -p /home/core/nfs
 chcon -Rvt svirt_sandbox_file_t /home/core/nfs
 exit; exit

# Create NFSProvisioner Custom Resource
cat << EOF | oc apply -f -  
apiVersion: cache.jhouse.com/v1alpha1
kind: NFSProvisioner
metadata:
  name: nfsprovisioner-sample
  namespace: nfsprovisioner-operator
spec:
  hostPathDir: /home/core/nfs
  nodeSelector:
    app: nfs-provisioner
EOF

# Update annotation of the NFS StorageClass
oc patch storageclass nfs -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
oc patch storageclass crc-csi-hostpath-provisioner -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
~~~

# RHODS
~~~


oc new-project redhat-ods-operator

cat << EOF | oc apply -f -  
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: rhods-operator-dev
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: rhods-operator-dev
spec:
  name: rhods-operator
  channel: beta
  source: iib
  sourceNamespace: openshift-marketplace
EOF
~~~

Model Serving Test
~~~
# update config

vi config.sh

# git clone --branch mm_locust_2 https://github.com/fcami/ci-artifacts.git

~~~

##Clean
~~~
crc stop
# crc delete
sed 's/192.168.1.100 local-quay.example.com//g' -i /etc/hosts

./mirror-registry uninstall --autoApprove -v

rm -rf oc-mirror-workspace/
rm mapping.txt mapping-brew.txt
~~~
