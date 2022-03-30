# Cyphernode v0.8.1

This is a minor release of a few fixes and improvements:

- Fixed: full compatibility with docker-compose was lost in v0.8.0 (thanks @bhodl)
- Improved: `ln_pay` now pays using the pay plugin first (with MPP), then `legacypay` on failure
- Improved: moved env variables from docker-compose.yaml to env files, for proxycron only for now (thanks @phillamy)
- Small improvements in the startup scripts
- Removed inserting previous txs in database when computing a tx fees
