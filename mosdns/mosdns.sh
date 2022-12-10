#!/bin/bash

# Parameter
OWNER="hezhijie0327"
REPO="mosdns"
TAG="latest"
DOCKER_PATH="/docker/mosdns"
USE_CDN="true"

## Function
# Get Latest Image
function GetLatestImage() {
    docker pull ${OWNER}/${REPO}:${TAG} && IMAGES=$(docker images -f "dangling=true" -q)
}
# Cleanup Current Container
function CleanupCurrentContainer() {
    if [ $(docker ps -a --format "table {{.Names}}" | grep -E "^${REPO}$") ]; then
        docker stop ${REPO} && docker rm ${REPO}
    fi
}
# Download mosDNS Configuration
function DownloadmosDNSConfiguration() {
    ENABLE_IPV6_UPSTREAM="true"
    ENABLE_HTTP3_UPSTREAM="false"
    ENABLE_PROXY_UPSTREAM="false"

    ENABLE_ECS="true"
    FORCE_ECS_AUTO="true"
    FORCE_ECS_IPV4="119.29.29.29"
    FORCE_ECS_IPV6="2402:4e00::"
    FORCE_ECS_OVERWRITE="false"

    ENABLE_CACHE="true"
    ENABLE_REDIS_CACHE="false"

    ENABLE_HTTPS="false"
    ENABLE_TLS="false"
    ENABLE_UNENCRYPTED_DNS="true"
    SSL_CERT="fullchain.cer"
    SSL_KEY="zhijie.online.key"
    HTTPS_CONFIG=(
        "      - protocol: https"
        "        addr: ':5553'"
        "        cert: '/etc/mosdns/cert/${SSL_CERT}'"
        "        key: '/etc/mosdns/cert/${SSL_KEY}'"
        "        url_path: '/dns-query'"
    )
    TLS_CONFIG=(
        "      - protocol: tls"
        "        addr: ':5535'"
        "        cert: '/etc/mosdns/cert/${SSL_CERT}'"
        "        key: '/etc/mosdns/cert/${SSL_KEY}'"
    )

    if [ "${USE_CDN}" == "true" ]; then
        CDN_PATH="source.zhijie.online"
    else
        CDN_PATH="raw.githubusercontent.com/hezhijie0327"
    fi && curl -s --connect-timeout 15 "https://${CDN_PATH}/CMA_DNS/main/mosdns/config.yaml" > "${DOCKER_PATH}/conf/config.yaml"

    if [ "${ENABLE_IPV6_UPSTREAM}" == "false" ]; then
        sed -i "s/#-/  /g" "${DOCKER_PATH}/conf/config.yaml"
    fi
    if [ "${ENABLE_HTTP3_UPSTREAM}" == "true" ]; then
        sed -i "s/##/  /g" "${DOCKER_PATH}/conf/config.yaml"
    fi
    if [ "${ENABLE_PROXY_UPSTREAM}" == "true" ]; then
        sed -i "s/#@/  /g" "${DOCKER_PATH}/conf/config.yaml"
    fi

    if [ "${ENABLE_ECS}" == "false" ]; then
        sed -i "s/#%/  /g;s/        - set_edns0_client_subnet/#%      - set_edns0_client_subnet/g" "${DOCKER_PATH}/conf/config.yaml"
    fi
    if [ "${FORCE_ECS_AUTO}" == "false" ]; then
        sed -i "s/#+/  /g;s/auto: true/auto: false/g" "${DOCKER_PATH}/conf/config.yaml"
    fi
    if [ "${FORCE_ECS_IPV4}" != "" ]; then
        sed -i "s/255.255.255.255/${FORCE_ECS_IPV4}/g" "${DOCKER_PATH}/conf/config.yaml"
    fi
    if [ "${FORCE_ECS_IPV6}" != "" ]; then
        sed -i "s/ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff/${FORCE_ECS_IPV6}/g" "${DOCKER_PATH}/conf/config.yaml"
    fi
    if [ "${FORCE_ECS_OVERWRITE}" == "true" ]; then
        sed -i "s/force_overwrite: false/force_overwrite: true/g" "${DOCKER_PATH}/conf/config.yaml"
    fi

    if [ "${ENABLE_CACHE}" == "true" ]; then
        sed -i "s/#&/  /g" "${DOCKER_PATH}/conf/config.yaml"
    fi
    if [ "${ENABLE_REDIS_CACHE}" == "true" ]; then
        sed -i "s/#\*/  /g;s/      size/#\*    size/g" "${DOCKER_PATH}/conf/config.yaml"
    fi

    if [ "${ENABLE_UNENCRYPTED_DNS}" == "false" ]; then
        if [ "${ENABLE_HTTPS}" == "true" ] || [ "${ENABLE_TLS}" == "true" ]; then
            for i in $(seq 1 4); do
                sed -i '$d' "${DOCKER_PATH}/conf/config.yaml"
            done
        fi
    fi
    if [ "${ENABLE_HTTPS}" == "true" ]; then
        for HTTPS_CONFIG_TASK in "${!HTTPS_CONFIG[@]}"; do
            echo "${HTTPS_CONFIG[$HTTPS_CONFIG_TASK]}" >> "${DOCKER_PATH}/conf/config.yaml"
        done
    fi
    if [ "${ENABLE_TLS}" == "true" ]; then
        for TLS_CONFIG_TASK in "${!TLS_CONFIG[@]}"; do
            echo "${TLS_CONFIG[$TLS_CONFIG_TASK]}" >> "${DOCKER_PATH}/conf/config.yaml"
        done
    fi
}
# Update GeoIP CN Rule
function UpdateGeoIPCNRule() {
    CNIPDB_SOURCE="geolite2"
    curl -s --connect-timeout 15 "https://${CDN_PATH}/CNIPDb/main/cnipdb_${CNIPDB_SOURCE}/country_ipv4_6.dat" > "${DOCKER_PATH}/data/GeoIP_CNIPDb.dat"
}
# Create New Container
function CreateNewContainer() {
    docker run --name ${REPO} --net host --restart=always \
        -v /docker/ssl:/etc/mosdns/cert:ro \
        -v ${DOCKER_PATH}/conf:/etc/mosdns/conf \
        -v ${DOCKER_PATH}/data:/etc/mosdns/data \
        -d ${OWNER}/${REPO}:${TAG} \
        start \
        -c "/etc/mosdns/conf/config.yaml" \
        -d "/etc/mosdns/data"
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
# Call DownloadmosDNSConfiguration
DownloadmosDNSConfiguration
# Call UpdateGeoIPRule
UpdateGeoIPCNRule
# Call CreateNewContainer
CreateNewContainer
# Call CleanupExpiredImage
CleanupExpiredImage
