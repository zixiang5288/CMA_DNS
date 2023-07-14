#!/bin/bash

# Parameter
OWNER="hezhijie0327"
REPO="mosdns"
TAG="latest"
DOCKER_PATH="/docker/mosdns"

CURL_OPTION=""
DOWNLOAD_CONFIG="" # false, true
USE_CDN="true"

CNIPDB_SOURCE="" # bgp, dbip, geolite2, iana, ip2location, ipipdotnet, iptoasn, vxlink, zjdb

ENABLE_ALWAYS_STANDBY="true"
ENABLE_HTTP3_UPSTREAM="false"
ENABLE_PIPELINE="true"

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
        curl ${CURL_OPTION:--4 -s --connect-timeout 15} "https://${CDN_PATH}/CMA_DNS/main/mosdns/config.yaml" > "${DOCKER_PATH}/conf/config.yaml"

        HTTPS_CONFIG=(
            "  - tag: create_https_server"
            "    type: tcp_server"
            "    args:"
            "      entries:"
            "        - path: '/dns-query'"
            "          exec: sequence_forward_query_to_forward_dns"
            "      cert: '/etc/mosdns/cert/${SSL_CERT}'"
            "      key: '/etc/mosdns/cert/${SSL_KEY}'"
            "      listen: :${HTTPS_PORT:-5553}"
        )
        TLS_CONFIG=(
            "  - tag: create_tls_server"
            "    type: tcp_server"
            "    args:"
            "      entry: sequence_forward_query_to_forward_dns"
            "      cert: '/etc/mosdns/cert/${SSL_CERT}'"
            "      key: '/etc/mosdns/cert/${SSL_KEY}'"
            "      listen: :${TLS_PORT:-5535}"
        )

        if [ "${ENABLE_ALWAYS_STANDBY}" == "false" ]; then
            sed -i 's/always_standby: true/always_standby: false/g' "${DOCKER_PATH}/conf/config.yaml"
        fi
        if [ "${ENABLE_HTTP3_UPSTREAM}" == "false" ] || [ "${ENABLE_LOCAL_UPSTREAM_PROXY}" != "false" ] || [ "${ENABLE_REMOTE_UPSTREAM_PROXY}" != "false" ]; then
            sed -i "s/enable_http3: true/enable_http3: false/g" "${DOCKER_PATH}/conf/config.yaml"
        fi
        if [ "${ENABLE_PIPELINE}" == "false" ]; then
            sed -i "s/enable_pipeline: true/enable_pipeline: false/g" "${DOCKER_PATH}/conf/config.yaml"
        fi

        if [ "${ENABLE_LOCAL_UPSTREAM}" != "false" ]; then
            sed -i "s/primary: fallback_forward_query_to_local_ecs_ipv64/primary: fallback_forward_query_to_local_ecs_${ENABLE_LOCAL_UPSTREAM}/g;s/secondary: fallback_forward_query_to_local_no_ecs_ipv64/secondary: fallback_forward_query_to_local_no_ecs_${ENABLE_LOCAL_UPSTREAM}/g;s/#(/  /g" "${DOCKER_PATH}/conf/config.yaml"
        fi
        if [ "${ENABLE_REMOTE_UPSTREAM}" != "false" ]; then
            sed -i "s/primary: fallback_forward_query_to_remote_ecs_ipv64/primary: fallback_forward_query_to_remote_ecs_${ENABLE_REMOTE_UPSTREAM}/g;s/secondary: fallback_forward_query_to_remote_no_ecs_ipv64/secondary: fallback_forward_query_to_remote_no_ecs_${ENABLE_REMOTE_UPSTREAM}/g;s/#)/  /g" "${DOCKER_PATH}/conf/config.yaml"
        fi
        if [ "${ENABLE_LOCAL_UPSTREAM}" != "false" ] && [ "${ENABLE_REMOTE_UPSTREAM}" != "false" ]; then
            sed -i "s/#@/  /g" "${DOCKER_PATH}/conf/config.yaml"
        fi

        if [ "${ENABLE_LOCAL_UPSTREAM_PROXY}" != "false" ]; then
            if [ "${ENABLE_LOCAL_UPSTREAM_PROXY}" != "true" ]; then
                sed -i "s/#+        socks5: '127.0.0.1:7891'/#+        socks5: '${ENABLE_LOCAL_UPSTREAM_PROXY}'/g" "${DOCKER_PATH}/conf/config.yaml"
            else
                sed -i "s/#+/  /g" "${DOCKER_PATH}/conf/config.yaml"
            fi
        fi
        if [ "${ENABLE_REMOTE_UPSTREAM_PROXY}" != "false" ]; then
            if [ "${ENABLE_REMOTE_UPSTREAM_PROXY}" != "true" ]; then
                sed -i "s/#-        socks5: '127.0.0.1:7891'/#-        socks5: '${ENABLE_REMOTE_UPSTREAM_PROXY}'/g" "${DOCKER_PATH}/conf/config.yaml"
            else
                sed -i "s/#-/  /g" "${DOCKER_PATH}/conf/config.yaml"
            fi
        fi

        if [ "${ENABLE_UNENCRYPTED_DNS}" == "false" ]; then
            if [ "${ENABLE_HTTPS}" == "true" ] || [ "${ENABLE_TLS}" == "true" ]; then
                for i in $(seq 1 10); do
                    sed -i '$d' "${DOCKER_PATH}/conf/config.yaml"
                done
            fi
        else
            if [ "${UNENCRYPTED_PORT:-5533}" != "5533" ]; then
                sed "s/listen: :5533/listen: :${UNENCRYPTED_PORT}/g" "${DOCKER_PATH}/conf/config.yaml"
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

        if [ -f "${DOCKER_PATH}/conf/config.yaml" ]; then
            sed -i "/#/d" "${DOCKER_PATH}/conf/config.yaml"
        fi
    fi

    if [ ! -d "${DOCKER_PATH}/data" ]; then
        mkdir -p "${DOCKER_PATH}/data"
    fi && curl ${CURL_OPTION:--4 -s --connect-timeout 15} "https://${CDN_PATH}/CNIPDb/main/cnipdb_${CNIPDB_SOURCE:-geolite2}/country_ipv4_6.txt" > "${DOCKER_PATH}/data/GeoIP_CNIPDb.txt"
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
# Call DownloadConfiguration
DownloadConfiguration
# Call CreateNewContainer
CreateNewContainer
# Call CleanupExpiredImage
CleanupExpiredImage
