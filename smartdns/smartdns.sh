#!/bin/bash

# Parameter
OWNER="hezhijie0327"
REPO="smartdns"
TAG="latest"
DOCKER_PATH="/docker/smartdns"

CURL_OPTION=""
DOWNLOAD_CONFIG="" # false, true
USE_CDN="true"

CNIPDB_SOURCE="" # bgp, dbip, geolite2, iana, ip2location, ipipdotnet, iptoasn, vxlink, zjdb

ENABLE_LOCAL_UPSTREAM="ipv64" # false, ipv4, ipv6, ipv64
ENABLE_REMOTE_UPSTREAM="ipv64" # false, ipv4, ipv6, ipv64

ENABLE_LOCAL_UPSTREAM_PROXY="false" # false, 127.0.0.1:7891
ENABLE_REMOTE_UPSTREAM_PROXY="false" # false, 127.0.0.1:7891

HTTPS_PORT="" # 5553
TLS_PORT="" # 5535
UNENCRYPTED_PORT="" # 5533

ENABLE_HTTPS="false"
ENABLE_TLS="false"
ENABLE_UNENCRYPTED_DNS="true"

SSL_CERT="fullchain.cer"
SSL_KEY="zhijie.online.key"

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
# Download Configuration
function DownloadConfiguration() {
    if [ "${USE_CDN}" == "true" ]; then
        CDN_PATH="source.zhijie.online"
    else
        CDN_PATH="raw.githubusercontent.com/hezhijie0327"
    fi

    if [ ! -d "${DOCKER_PATH}/conf" ]; then
        mkdir -p "${DOCKER_PATH}/conf"
    fi

    if [ "${DOWNLOAD_CONFIG:-true}" == "true" ]; then
        curl ${CURL_OPTION:--4 -s --connect-timeout 15} "https://${CDN_PATH}/CMA_DNS/main/smartdns/smartdns.conf" | sed "s/fullchain\.cer/${SSL_CERT/./\\.}/g;s/zhijie\.online\.key/${SSL_KEY/./\\.}/g" > "${DOCKER_PATH}/conf/smartdns.conf"

        if [ "${ENABLE_LOCAL_UPSTREAM}" != "false" ]; then
            if [ "${ENABLE_LOCAL_UPSTREAM}" == "ipv4" ]; then
                sed -i "/local_ipv6/d" "${DOCKER_PATH}/conf/smartdns.conf"
            elif [ "${ENABLE_LOCAL_UPSTREAM}" == "ipv6" ]; then
                sed -i "/local_ipv4/d" "${DOCKER_PATH}/conf/smartdns.conf"
            fi
        else
            sed -i "/local_ipv/d" "${DOCKER_PATH}/conf/smartdns.conf"
        fi
        if [ "${ENABLE_REMOTE_UPSTREAM}" != "false" ]; then
            if [ "${ENABLE_REMOTE_UPSTREAM}" == "ipv4" ]; then
                sed -i "/remote_ipv6/d" "${DOCKER_PATH}/conf/smartdns.conf"
            elif [ "${ENABLE_REMOTE_UPSTREAM}" == "ipv6" ]; then
                sed -i "/remote_ipv4/d" "${DOCKER_PATH}/conf/smartdns.conf"
            fi
        else
            sed -i "/remote_ipv/d" "${DOCKER_PATH}/conf/smartdns.conf"
        fi

        if [ "${ENABLE_LOCAL_UPSTREAM_PROXY}" == "false" ] || [ "${ENABLE_LOCAL_UPSTREAM}" == "false" ]; then
            if [ "${ENABLE_LOCAL_UPSTREAM_PROXY}" == "false" ]; then
                sed -i "s/ -proxy local_proxy//g" "${DOCKER_PATH}/conf/smartdns.conf"
            fi
        fi
        if [ "${ENABLE_REMOTE_UPSTREAM_PROXY}" == "false" ] || [ "${ENABLE_REMOTE_UPSTREAM}" == "false" ]; then
            if [ "${ENABLE_REMOTE_UPSTREAM_PROXY}" == "false" ]; then
                sed -i "s/ -proxy remote_proxy//g" "${DOCKER_PATH}/conf/smartdns.conf"
            fi
        fi

        if [ -f "${DOCKER_PATH}/conf/smartdns.conf" ]; then
            sed -i "/#/d" "${DOCKER_PATH}/conf/smartdns.conf"
        fi

        if [ ! -d "${DOCKER_PATH}/data" ]; then
            mkdir -p "${DOCKER_PATH}/data"
        fi && curl ${CURL_OPTION:--4 -s --connect-timeout 15} "https://${CDN_PATH}/CNIPDb/main/cnipdb_${CNIPDB_SOURCE:-geolite2}/country_ipv4_6.txt" | sed "s/^/whitelist-ip /g" > "${DOCKER_PATH}/data/GeoIP_CNIPDb.conf"
    fi
}
# Create New Container
function CreateNewContainer() {
    if [ ! -d "${DOCKER_PATH}/conf" ]; then
        mkdir -p "${DOCKER_PATH}/conf"
    fi

    if [ ! -d "${DOCKER_PATH}/work" ]; then
        mkdir -p "${DOCKER_PATH}/work"
    fi

    docker run --name ${REPO} --net host --restart=always \
        -v /docker/ssl:/etc/smartdns/cert:ro \
        -v ${DOCKER_PATH}/conf:/etc/smartdns/conf \
        -v ${DOCKER_PATH}/conf:/etc/smartdns/data \
        -v ${DOCKER_PATH}/work:/etc/smartdns/work \
        -d ${OWNER}/${REPO}:${TAG} \
        -c "/etc/smartdns/conf/smartdns.conf" \
        -p "/etc/smartdns/work/smartdns.pid" \
        -f
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
