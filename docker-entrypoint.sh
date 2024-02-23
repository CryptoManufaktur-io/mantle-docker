#!/usr/bin/env bash
set -euo pipefail

# Secret generation is not needed on mainnet, but keeping it here in case Mantle moves to op-node/op-geth
if [[ ! -f /var/lib/op-geth/ee-secret/jwtsecret ]]; then
  echo "Generating JWT secret"
  __secret1=$(head -c 8 /dev/urandom | od -A n -t u8 | tr -d '[:space:]' | sha256sum | head -c 32)
  __secret2=$(head -c 8 /dev/urandom | od -A n -t u8 | tr -d '[:space:]' | sha256sum | head -c 32)
  echo -n "${__secret1}""${__secret2}" > /var/lib/op-geth/ee-secret/jwtsecret
fi

if [[ -O "/var/lib/op-geth/ee-secret/jwtsecret" ]]; then
  chmod 666 /var/lib/op-geth/ee-secret/jwtsecret
fi

# Set verbosity
shopt -s nocasematch
case ${LOG_LEVEL} in
  error)
    __verbosity="--verbosity 1"
    ;;
  warn)
    __verbosity="--verbosity 2"
    ;;
  info)
    __verbosity="--verbosity 3"
    ;;
  debug)
    __verbosity="--verbosity 4"
    ;;
  trace)
    __verbosity="--verbosity 5"
    ;;
  *)
    echo "LOG_LEVEL ${LOG_LEVEL} not recognized"
    __verbosity=""
    ;;
esac

if [ ! -d "/var/lib/op-geth/keystore/" ]; then # Set up keys if fresh
# import the key that will be used to locally sign blocks
# this key does not have to be kept secret in order to be secure
# we use an insecure password ("pwd") to lock/unlock the password
  echo "Importing private key"
  echo $BLOCK_SIGNER_KEY > /var/lib/op-geth/key.prv
  echo "pwd" > /var/lib/op-geth/password
  geth --nousb account import --datadir /var/lib/op-geth --password /var/lib/op-geth/password /var/lib/op-geth/key.prv
#  echo $FP_OPERATOR_PRIVATE_KEY > /var/lib/op-geth/fp-key.prv
#  geth --nousb account import --datadir /var/lib/op-geth --password /var/lib/op-geth/password /var/lib/op-geth/fp-key.prv
fi

# Prep datadir
if [ -n "${SNAPSHOT}" ] && [ ! -d "/var/lib/op-geth/geth/chaindata" ]; then
  __dont_rm=0
  cd /var/lib/op-geth/snapshot
  eval "__url=${SNAPSHOT}"
  aria2c -c -x16 -s16 --auto-file-renaming=false --conditional-get=true --allow-overwrite=true "${__url}"
  mkdir -p /var/lib/op-geth/geth
  filename=$(echo "${__url}" | awk -F/ '{print $NF}')
  tar xzvf "${filename}" -C /var/lib/op-geth/geth
  if [ "${__dont_rm}" -eq 0 ]; then
    rm -f "${filename}"
  fi
  if [[ ! -d /var/lib/op-geth/geth/chaindata ]]; then
    echo "Chaindata isn't in the expected location."
    echo "This snapshot likely won't work until the entrypoint script has been adjusted for it."
  fi
elif [ ! -d "/var/lib/op-geth/geth/chaindata" ]; then # Init from genesis
# get the genesis file from the deployer
  curl \
    --fail \
    --show-error \
    --silent \
    --retry-connrefused \
    --retry-all-errors \
    --retry $RETRIES \
    --retry-delay 5 \
    $ROLLUP_STATE_DUMP_PATH \
    -o /var/lib/op-geth/genesis.json

    # initialize the geth node with the genesis file
  echo "Initializing Geth node"
  geth ${__verbosity} init /var/lib/op-geth/genesis.json --datadir /var/lib/op-geth
fi

if [ -f /var/lib/op-geth/prune-marker ]; then
  rm -f /var/lib/op-geth/prune-marker
  exec "$@" snapshot prune-state
else
  # wait for the dtl to be up, else geth will crash if it cannot connect
  curl \
    --fail \
    --show-error \
    --silent \
    --output /dev/null \
    --retry-connrefused \
    --retry $RETRIES \
    --retry-delay 1 \
    ${ROLLUP_CLIENT_HTTP}/eth/syncing
# Word splitting is desired for the command line parameters
# shellcheck disable=SC2086
  exec "$@" ${__verbosity} ${EL_EXTRAS}
fi
