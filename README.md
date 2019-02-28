# rancher-ha-tf-do
Building HA Rancher 2.x server on DigitalOcean using Terraform and RKE

* Rancher 2 installation without HA RKE Add-on, meaning >V2.0.8 can be installed => [Info](https://rancher.com/docs/rancher/v2.x/en/upgrades/upgrades/migrating-from-rke-add-on/)
* Private IP enabled in DO nodes. According to rancher documentation, Kubernetes will use it for intra-cluster communication => [Info](https://rancher.com/docs/rancher/v2.x/en/installation/ha/kubernetes-rke/)
* Go to [Rancher documentation](https://rancher.com/docs/rancher/v2.x/en/installation/ha/) for more information

## Prerequisite

* [Terraform](https://www.terraform.io/) binary ([tfenv](https://github.com/kamatama41/tfenv) recommended)
* [DigitalOcean](https://www.digitalocean.com/) account and API Token
* Own your custom domain and register zone in DigitalOcean DNS service
* [jq](https://stedolan.github.io/jq/) command

## Usage

### clone this repository

```
git clone https://github.com/ishworthapaliya/rancher-ha-tf-do.git
```

### Build HA Rancher cluster

```
export DIGITALOCEAN_TOKEN=***
export DOMAIN_SUFFIX=your.own.example.com
export CERT_EMAIL=user@example.com # for Let's Encrypt
./make.sh up

For windows
set DIGITALOCEAN_TOKEN=***
set DOMAIN_SUFFIX=your.own.example.com
set CERT_EMAIL=user@example.com # for Let's Encrypt
./make.sh up
```

Then open https://rc.${DOMAIN_SUFFIX}/

`rke` creates `kube_config_rke.yml`.
If you want to access k8s using kubectl copy it to `~/.kube/config`.

### Destroy cluster

Delete droplet (server) and DNS record.

```
export DIGITALOCEAN_TOKEN=***
export DOMAIN_SUFFIX=your.own.example.com
export CERT_EMAIL=user@example.com # for Let's Encrypt
./make.sh destroy
```
