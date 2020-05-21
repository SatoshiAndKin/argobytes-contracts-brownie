#!/bin/sh

export NODE_OPTIONS="--max-old-space-size=16384"

set -x

exec ganache-cli \
    --accounts 10 \
    --hardfork istanbul \
    --fork ws://127.0.0.1:8546 \
    --gasLimit 6721975 \
    --mnemonic "opinion adapt negative bone suit ill fossil alcohol razor script damp fold" \
    --port 8555 \
    --verbose \
    --networkId 1 \
;
