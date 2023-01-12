#!/bin/bash

# set -o errexit
# set -o pipefail
# set -o nounset
# set -o errtrace
# set -x

source "./config.sh"

oc create ns ${MINIO_NS}

SECRETKEY=$(openssl rand -hex 32)

sed "s/<secretkey>/$SECRETKEY/g" ./minio.yaml | sed "s/<minio-ns>/${MINIO_NS}/g" | oc -n ${MINIO_NS} apply -n ${MINIO_NS} -f -
sed "s/<secretkey>/$SECRETKEY/g" ./minio-secret.yaml | sed "s/<minio-ns>/${MINIO_NS}/g" | tee ./minio-secret.yaml | oc -n ${MINIO_NS} apply -n ${MINIO_NS} -f -

until oc -n ${MINIO_NS} get pod minio |grep Running &> /dev/null
do
    echo "Waiting for Godot... err MinIO"
    sleep 1
done

oc -n ${MINIO_NS} exec minio -- bash -c "cd ${MODEL_PATH} ; for i in \$(seq 1 ${MODEL_COUNT}) ; do ln mnist.onnx mnist\${i}.onnx ; done"
