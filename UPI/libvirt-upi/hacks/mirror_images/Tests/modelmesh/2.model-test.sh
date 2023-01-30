#!/bin/bash

# set -o errexit
# set -o pipefail
# set -o nounset
# set -o errtrace
# set -x


source "./config.sh"

# create namespaces first
# for i in $(seq 1 ${NS_COUNT})
# do
#     NS=${NS_BASENAME}-${i}
#     # oc create ns ${NS}
#     oc new-project ${NS} --skip-config-write
#     oc apply -f ./minio-secret.yaml -n ${NS}
#     # oc apply -f ./openvino-serving-runtime.yaml -n ${NS}
#     oc apply -f ./sa_user.yaml -n ${NS}
# done
# unset NS

# start by creating all model mesh instances by adding the first inference endpoint
# of each namespace
for j in $(seq 1 ${MODEL_COUNT})
do
    for i in $(seq 1 ${NS_COUNT})
    do
        NS=${NS_BASENAME}-${i}
	    oc label namespace ${NS} modelmesh-enabled=true --overwrite=true
        sed s/example-onnx-mnist/example-onnx-mnist-${j}/g ./openvino-inference-service.yaml | oc apply -n ${NS} -f -
    done
done
unset NS

# # check for model mesh instances
# for i in $(seq 1 ${NS_COUNT})
# do
#     NS=${NS_BASENAME}-${i}

#     until [[ "$(oc get pods -n ${NS} | grep '5/5' |grep Running |wc -l)" == ${MM_POD_COUNT} ]]
#     do
#         echo "NS:${NS}: Waiting for the model mesh pods"
#         sleep 1
#     done
#     unset NS
# done

# echo "id,ns,endpoint" > endpoints.txt

# # test inference endpoints
# INDEX=0
# for i in $(seq 1 ${NS_COUNT})
# do
#     NS=${NS_BASENAME}-${i}
    
#     auth_token=$(oc -n ${NS} sa new-token user-one)
#     for j in $(seq 1 ${MODEL_COUNT})
#     do
#         let "INDEX=INDEX+1"
#       	route=$(oc -n ${NS} get routes example-onnx-mnist-$j --template={{.spec.host}}{{.spec.path}})
#         ENDPOINT=https://${route}/infer
#         if [[ "$API_ENDPOINT_CHECK" -eq 0 ]]
#         then
#             echo "NS:${NS}: Smoke-testing endpoint example-onnx-mnist-$j"
#             until curl $CURL_OPTIONS $ENDPOINT -d @./input-onnx.json  | jq '.outputs[] | select(.data != null)' &>/dev/null
#             until curl $CURL_OPTIONS $ENDPOINT -d @./input-onnx.json -H "Authorization: Bearer ${auth_token}" | jq '.outputs[] | select(.data != null)' &>/dev/null
#             do
#                 echo "S:${NS}: Waiting for inference endpoint example-onnx-mnist-$j"
#                 sleep 1
#             done
# 	fi
# 	echo "${INDEX},${NS},${ENDPOINT}" >> endpoints.txt
#     done
#     unset NS
# done
