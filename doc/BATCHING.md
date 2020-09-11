# How Batching works in Cyphernode

Details on how batching was implemented in Cyphernode.

## Glossary

A Batcher is a batching template with corresponding past batched transactions and a queue of outputs waiting to be batched in the next batch transaction.

A batched transaction is a transaction that combines multiple recipients in one transaction with multiple outputs, instead of using multiple individual transactions.

An ongoing batch is a batcher with its queued outputs waiting to be part of the next batch transaction.  There's no associated txid yet.

## Entities

### Database

See [Cyphernode's Entity-Relation Model](../proxy_docker/app/data/cyphernode.sql).

- `batcher`: batching template.  The conf_target is the default confTarget that will be used when creating the batch transaction if no confTarget is supplied to batchspend that would override it.
  - id: autoincrementing primary key
  - label: optional unique label to be used on subsequent calls instead of using the id
  - conf_target: optional default confTarget to be used when creating the batched transaction
- `recipient`: a batch output.  Minimally requires the destination address and the amount.
  - id: autoincrementing primary key
  - address: destination Bitcoin address
  - amount: amount to be sent, in BTC
  - tx_id: foreign key on the tx table, the actual transaction if created
  - webhook_url: optional URL that you want Cyphernode to call back when the batch transaction is broadcast
  - batcher_id: foreign key on the batcher table, the corresponding batching template for this recipient
  - label: an optional label for this output.
- `tx`: a transaction.  The information about a broadcast Bitcoin transaction.

### Good to know

- There is a default batcher created on installation time, with id 1, label "default" and conf_target 6.
- When a recipient has no tx_id, it means it is waiting for the next batch.
- When a recipian has a batcher_id, it means it is part of a past or ongoing batch.
- When a batch transaction is broadcast, the webhook_url of each included recipient will be called by Cyphernode, if present, with information about the batched transaction in the POSTed body.
- Cyphernode knows when a callback webhook didn't work.  It will retry the callback when a new blocks is mined, until it works.

## 2nd layer: the Batcher cypherapp

The Cyphernode's base functionalities for batching is pretty basic.  Instead of adding complex batching features to the Cyphernode API, we decided to develop a [CypherApp](CYPHERAPPS.md).

The [Batcher](https://github.com/SatoshiPortal/batcher) cypherapp will take care of the following tasks:

- Merging same destination outputs into one, adding the amounts and calling the different webhook URLs on batch execution.
- Scheduling the batches.
- Executing the batches when an amount threshold has been reached.
- Hiding Cyphernode complexity by dealing only with a `batchRequestId` and a `batchId`.
