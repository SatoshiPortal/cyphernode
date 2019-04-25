# Cyphernode Apps

We are providing one default Cyphernode application: The Cyphernode Welcome App.  It is a simple Golang application that uses the Cyphernode API to get some information about it: the Bitcoin Core syncing progression, the installed components, a link to download the encrypted config file, a link to download the encrypted API ID/keys file and a link to Spark Wallet, if LN is installed.

We are also providing Spark Wallet as a Cyphernode application.  It is a hybrid application, directly using the c-lightning directory instead of only using the Cyphernode API.

## Concept

As you already know it, we want Cyphernode to be modular and decoupled.  That's why we created a completely separated repository for the Cyphernode Apps: https://github.com/SatoshiPortal/cypherapps

Cypherapps acts as an indirection layer between Cyphernode and the actual applications.  The repo is cloned into the Cyphernode directory during setup, depending on the selected optional features.  The corresponding docker images are taken from the Docker hub repositories.

Separating Cypherapps from Cyphernode allows us to add applications without changing Cyphernode.

## Examples

Welcome App: https://github.com/SatoshiPortal/cyphernode_welcome
