#!/bin/bash

api_key='MyApiKey'
api_endpoint='https://dns.api.gandi.net/api/v5'

ifconfig='https://homnomnom.fr/ip/'

host="example.com"
ttl='300'

domainsV4=(
    "subdomain1"
    "subdomain2"
)

domainsV6=(
    "subdomain3"
    "subdomain4"
)

#script below
function die {
    echo -e $1 >&2
    kill -HUP $$
}

function get_api {
    tmpfile=$(mktemp)
    http_code=$(curl --silent "${api_endpoint}/${1}" \
                     --header "Content-Type: application/json" \
                     --header "X-Api-Key: ${api_key}" \
                     --output ${tmpfile} \
                     --write-out '%{http_code}')

    message=$(cat ${tmpfile})
    rm ${tmpfile}

    if [[ ${http_code} != "200" ]]; then
        die "API GET call exited with code ${http_code}.\nMessage: ${message}"
    fi

    echo ${message}
}

function put_api {
    tmpfile=$(mktemp)
    http_code=$(curl --request PUT \
         --header "Content-Type: application/json" \
         --header "X-Api-Key: ${api_key}" \
         --silent \
         --output ${tmpfile} \
         --write-out '%{http_code}' \
         "${api_endpoint}/${1}" \
         -d "${2}")

    message=$(cat ${tmpfile})
    rm ${tmpfile}

    if [[ ${http_code} != "201" ]]; then
        die "API PUT call exited with code ${http_code}.\nMessage: ${message}"
    fi

    echo ${message}
}

#find out zone UUID for domain
uuid=$(get_api "domains/${host}")
uuid=$(echo ${uuid} | jq '.zone_uuid' | sed 's/"//g')
echo "UUID: ${uuid}"

ipv4=$(curl -4 --silent ${ifconfig})
echo "detected IPv4 address: ${ipv4}"
for domain in ${domainsV4[@]}; do
    ip=$(get_api "zones/${uuid}/records/${domain}/A" | jq '.rrset_values[0]' | sed 's/"//g')
    if [ "${ip}" == "${ipv4}" ]; then
        echo "- ${domain}.${host}: IP already OK"
    else
        payload='{"rrset_ttl": '${ttl}', "rrset_values": ["'${ipv4}'"]}'

        put_api "zones/${uuid}/records/${domain}/A" "${payload}" >/dev/null
        echo "- ${domain}.${host}: replaced ${ip} with ${ipv4}"
    fi
done

ipv6=$(curl -6 --silent ${ifconfig})
echo "detected IPv6 address: ${ipv6}"
for domain in ${domainsV6[@]}; do
    ip=$(get_api "zones/${uuid}/records/${domain}/AAAA" | jq '.rrset_values[0]' | sed 's/"//g')
    if [ "${ip}" == "${ipv6}" ]; then
        echo "- ${domain}.${host}: IP already OK"
    else
        payload='{"rrset_ttl": '${ttl}', "rrset_values": ["'${ipv6}'"]}'

        put_api "zones/${uuid}/records/${domain}/AAAA" "${payload}" >/dev/null
        echo "- ${domain}.${host}: replaced ${ip} with ${ipv6}"
    fi
done
