#!/bin/bash

# Parameter
OWNER="hezhijie0327"
REPO="gost"
TAG="latest"

RUNNING_MODE="" # client, server

CONTAINER_NAME="" # gost

GOST_HOST="" # demo.zhijie.online
GOST_IP=() # ("1.0.0.1" "1.1.1.1")
GOST_PORT="" # 8443

WG_LOCAL_PORT="" # 51821
WG_REMOTE_PORT="" # 51820

SSL_CERT="" # fullchain.cer
SSL_KEY="" # zhijie.online.key

## Function
# Get Latest Image
function GetLatestImage() {
    docker pull ${OWNER}/${REPO}:${TAG} && IMAGES=$(docker images -f "dangling=true" -q)
}
# Cleanup Current Container
function CleanupCurrentContainer() {
    if [ $(docker ps -a --format "table {{.Names}}" | grep -E "^${CONTAINER_NAME:-${REPO}}$") ]; then
        docker stop ${CONTAINER_NAME:-${REPO}} && docker rm ${CONTAINER_NAME:-${REPO}}
    fi
}
# Create New Container
function CreateNewContainer() {
    if [ "${RUNNING_MODE:-server}" == "server" ]; then
        docker run --name ${CONTAINER_NAME:-${REPO}} --net host --restart=always \
            -v /docker/ssl/${SSL_CERT:-fullchain.cer}:/cert.pem:ro \
            -v /docker/ssl/${SSL_KEY:-zhijie.online.key}:/key.pem:ro \
            -d ${OWNER}/${REPO}:${TAG} \
            -L relay+grpc://:${GOST_PORT:-8443}
    else
        if [ "${GOST_IP[*]}" != "" ]; then
            GOST_HOSTS_LIST="" && for GOST_IP_TASK in "${!GOST_IP[@]}"; do
                GOST_HOSTS_LIST="${GOST_HOSTS_LIST} ${GOST_HOST}:${GOST_IP[$GOST_IP_TASK]},"
                GOST_HOSTS_LIST=$(echo "${GOST_HOSTS_LIST}" | sed "s/^\ //g")
            done && GOST_HOSTS_LIST="?hosts=$(echo ${GOST_HOSTS_LIST} | sed 's/\ //g;s/,$//g')"
        fi

        docker run --name ${CONTAINER_NAME:-${REPO}} --net host --restart=always \
            -d ${OWNER}/${REPO}:${TAG} \
            -L "udp://:${WG_LOCAL_PORT:-51821}/127.0.0.1:${WG_REMOTE_PORT:-51820}?keepAlive=true&ttl=5s" \
            -F "relay+grpc://${GOST_HOST:-demo.zhijie.online}:${GOST_PORT:-8443}${GOST_HOSTS_LIST}"
    fi
}
# Cleanup Expired Image
function CleanupExpiredImage() {
    if [ "${IMAGES}" != "" ]; then
        docker rmi ${IMAGES}
    fi
}

## Process
# Call GetLatestImage
GetLatestImage
# Call CleanupCurrentContainer
CleanupCurrentContainer
# Call CreateNewContainer
CreateNewContainer
# Call CleanupExpiredImage
CleanupExpiredImage
