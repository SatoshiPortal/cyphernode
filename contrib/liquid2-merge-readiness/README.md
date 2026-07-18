# Liquid2 merge-readiness tests

This directory contains repeatable checks for preparing a draft PR that merges
`features/liquid2` into `dev`, including the `features/elgetaddrinfo` endpoint.

The scripts are intentionally external to the runtime containers. They should
not be sourced by production code and should not print RPC credentials or API
keys.

## Scripts

- `local-static.sh`
  Runs local static/build checks that do not require live Bitcoin/Elements RPC
  services.

- `lunanode-live-smoke.sh`
  Runs live smoke tests against a deployed Cyphernode stack. This is safe for
  the Lunanode test VM: it creates wallet addresses and temporary watch rows,
  then removes the watch rows. It does not broadcast spends.

- `gatekeeper-auth-matrix.sh`
  Reads the deployed Gatekeeper `api.properties` and verifies the full
  role/action permission matrix with no token, an invalid token, and all API ids
  present in the deployed `keys.properties`, deriving each id's role from its
  actual `kapi_groups`.

- `migration-dev-to-liquid2.sh`
  Starts an isolated throwaway PostgreSQL container, creates a database from
  `origin/dev` schemas, runs the candidate branch migration scripts twice, and
  verifies Bitcoin data survives while Liquid tables/indexes are created.

## Lunanode defaults

These defaults match the current test VM deployment:

```sh
STACK_DIR=/home/cypherdeploy/cyphernode-liquid2-full-20260718
PROJECT=cyphernode-liquid2-full
```

Run on the VM:

```sh
cd "$STACK_DIR"
/path/to/contrib/liquid2-merge-readiness/lunanode-live-smoke.sh
/path/to/contrib/liquid2-merge-readiness/gatekeeper-auth-matrix.sh
```
