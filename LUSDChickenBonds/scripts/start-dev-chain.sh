#!/usr/bin/env bash

dirname=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

docker_run_cmd=(
  docker run
    --name openethereum

    --rm
    -d
    -p 8545:8545/tcp
    -p 8546:8546/tcp
    -v "${dirname}"/dev-chain:/dev-chain

    openethereum/openethereum

    --config /dev-chain/config.toml
)

"${docker_run_cmd[@]}"
