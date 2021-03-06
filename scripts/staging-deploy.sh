#!/bin/sh -eux
# deploy our contracts to a node started by `./scripts/staging-ganache.sh`

[ -d contracts ]

rm -rf build/deployments/

# we could let run compile for us, but the error messages (if any) aren't as easy to read
./venv/bin/brownie compile

export EXPORT_ARTIFACTS=${EXPORT_ARTIFACTS:-1}

./venv/bin/brownie run deploy/dev --network staging "$@"

if [ "$EXPORT_ARTIFACTS" = "1" ]; then
    ./scripts/export.sh
fi
