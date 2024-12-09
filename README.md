# Archived repo

Please use [Optimism Docker](https://github.com/CryptoManufaktur-io/optimism-docker) for Mantle RPC nodes

# Overview

Docker Compose for Mantle rollup

`cp default.env .env`, then `nano .env` and adjust values, particularly SNAPSHOT and DTL

This repo does not support Mantle on Sepolia at present

Meant to be used with [central-proxy-docker](https://github.com/CryptoManufaktur-io/central-proxy-docker) for traefik
and Prometheus remote write; use `:ext-network.yml` in `COMPOSE_FILE` inside `.env` in that case.

If you want the l2-geth RPC ports exposed locally, use `mantle-shared.yml` in `COMPOSE_FILE` inside `.env`.

The `./mantled` script can be used as a quick-start:

`./mantled install` brings in docker-ce, if you don't have Docker installed already.

`cp default.env .env`

`nano .env` and adjust variables as needed, particularly `SNAPSHOT` and `DTL`

`./mantled up`

To update the software, run `./mantled update` and then `./mantled up`

This is Mantle Docker v2.0.0
