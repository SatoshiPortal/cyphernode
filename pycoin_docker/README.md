# Build image

```shell
docker build -t pycoinimg .
```

# Usefull examples

See https://github.com/shivaenigma/pycoin

List SegWit addresses for path 0/24-30 for a pub32:

```shell
curl -H "Content-Type: application/json" -d '{"pub32":"tpubD6NzVbkrYhZ4YR3QK2tyfMMvBghAvqtNaNK1LTyDWcRHLcMUm3ZN2cGm5BS3MhCRCeCkXQkTXXjiJgqxpqXK7PeUSp86DTTgkLpcjMtpKWk","path":"0/25-30"}' http://localhost:7777/derive
curl -H "Content-Type: application/json" -d '{"pub32":"vpub5SLqN2bLY4WeZF3kL4VqiWF1itbf3A6oRrq9aPf16AZMVWYCuN9TxpAZwCzVgW94TNzZPNc9XAHD4As6pdnExBtCDGYRmNJrcJ4eV9hNqcv","path":"0/25-30"}' http://localhost:7777/derive
```
