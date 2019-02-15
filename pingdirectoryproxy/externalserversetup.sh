#this script requires the number of replicas to be passed in as an argument
NUM_REPLICAS=$1
for ((i=0;i<NUM_REPLICAS;i++)); do
  prepare-external-server --hostname \
      ${K8S_DS_STATEFUL_SET_NAME}-$i.${K8S_SERVICE_NAME} \
      --port ${LDAPS_PORT} \
      --trustAll --useSSL \
      --proxyBindPasswordFile "${ROOT_USER_PASSWORD_FILE}" \
      --bindPasswordFile "${ROOT_USER_PASSWORD_FILE}" \
      --baseDN "${USER_BASE_DN}" \
      --bindDN "${ROOT_USER_DN}" \
      --no-prompt
done
