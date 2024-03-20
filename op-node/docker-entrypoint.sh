#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ! -f /var/lib/op-node/ee-secret/jwtsecret ]]; then
  echo "Generating JWT secret"
  __secret1=$(head -c 8 /dev/urandom | od -A n -t u8 | tr -d '[:space:]' | sha256sum | head -c 32)
  __secret2=$(head -c 8 /dev/urandom | od -A n -t u8 | tr -d '[:space:]' | sha256sum | head -c 32)
  echo -n "${__secret1}""${__secret2}" > /var/lib/op-node/ee-secret/jwtsecret
fi

if [[ -O "/var/lib/op-node/ee-secret/jwtsecret" ]]; then
  chmod 666 /var/lib/op-node/ee-secret/jwtsecret
fi

__public_ip="--p2p.advertise.ip $(wget -qO- https://ifconfig.me/ip)"

if [ "${NETWORK_ID}" = 5000 ]; then
  __network=mainnet
elif [ "${NETWORK_ID}" = 5003 ]; then
  __network=sepolia
else
  echo "This script doesn't know how to fetch the rollup.json for network ID ${NETWORK_ID}. Can't proceed."
  sleep 60
  exit 1
fi

mkdir -p /var/lib/op-node/config
curl \
  --fail \
  --show-error \
  --silent \
  --retry-connrefused \
  --retry-all-errors \
  --retry 5 \
  --retry-delay 5 \
  https://raw.githubusercontent.com/mantlenetworkio/networks/main/${__network}/rollup.json \
  -o /var/lib/op-node/config/rollup.json

# Word splitting is desired for the command line parameters
# shellcheck disable=SC2086
exec "$@" ${__public_ip} ${CL_EXTRAS}
