#! /bin/bash

export TARGET_NAMESPACE=console-namespace
export CI_CLUSTER=true
export CONFIG_YAML=./resources/console/console-config.yaml
export CLUSTER_DOMAIN="minihost.dev"


# minikube addons enable ingress
# minikube addons enable ingress-dns
function prepare(){
    kubectl create namespace $TARGET_NAMESPACE
    sleep 10
}

function strimzi(){
    kubectl create -f https://strimzi.io/install/latest?namespace=$TARGET_NAMESPACE -n $TARGET_NAMESPACE
    kubectl wait deployment/strimzi-cluster-operator --for=condition=available --timeout=180s -n $TARGET_NAMESPACE
}

function prometheus(){
    curl -s "https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/bundle.yaml" | sed "s#namespace: default#namespace: ${TARGET_NAMESPACE}#g" | kubectl create -n $TARGET_NAMESPACE -f -
    kubectl wait deployment/prometheus-operator --for=condition=available --timeout=180s -n $TARGET_NAMESPACE
    ./001-deploy-prometheus.sh $TARGET_NAMESPACE $CLUSTER_DOMAIN
}

function kafka(){
    ./002-deploy-console-kafka.sh $TARGET_NAMESPACE $CLUSTER_DOMAIN zk
    kubectl wait kafka/console-kafka --for=condition=Ready --timeout=300s -n $TARGET_NAMESPACE
    while ! kubectl get secret console-kafka-user1 -n $TARGET_NAMESPACE; do echo "Waiting for user secret"; sleep 5; done
}

function console(){
    echo -e "$(kubectl get secret console-kafka-user1 -n $TARGET_NAMESPACE -o yaml | yq '.data.password' - | base64 --decode)"

}

function deploy(){
#     replace config.yaml
    export USERPS=$(kubectl get secret console-kafka-user1 -n $TARGET_NAMESPACE -o yaml | yq '.data.password' - | base64 --decode)
    echo -e "password= ${USERPS}"
    sed -i -e "s#\$USER_PASSWORD#\"${USERPS}\"#g" -e "s#\$CLUSTER_DOMAIN#${CLUSTER_DOMAIN}#g" -e "s#\$NAMESPACE#${TARGET_NAMESPACE}#g" $CONFIG_YAML
    ./003-install-console.sh $TARGET_NAMESPACE $CLUSTER_DOMAIN $CONFIG_YAML
}

# prepare
# strimzi
# prometheus
# kafka
# console
deploy