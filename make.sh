#!/bin/bash

set -e

echo "$(date +%Y-%m-%dT%H:%M:%S) Start" > log.txt

log(){
    echo "$(date +%Y-%m-%dT%H:%M:%S) $*" >> log.txt
}

wait_server_boot(){
    addr=$(terraform output -json | jq -r .node2_address.value)
    echo -n "Waiting for docker installed."
    i=0
    until timeout 5 ssh -i id_rsa -o StrictHostKeyChecking=no root@$addr docker ps > /dev/null 2>&1; do
        echo -n "."
        i=$(($i + 1))
	if [ $i -ge 60 ] ; then
	     echo "Given up the connecting to the server" 1>&2 >> log.txt
	     exit 1
	fi
    done
    echo
}

gen_rke_config() {
    log Generate rke.yml

    addr0=$(terraform output -json | jq -r .node0_address.value)
    addr1=$(terraform output -json | jq -r .node1_address.value)
    addr2=$(terraform output -json | jq -r .node2_address.value)

    addr0_private=$(terraform output -json | jq -r .node0_address_private.value)
    addr1_private=$(terraform output -json | jq -r .node1_address_private.value)
    addr2_private=$(terraform output -json | jq -r .node2_address_private.value)

    sed -e "1,/<IP>/s/<IP>/$addr0/" \
        -e "1,/<IP>/s/<IP>/$addr1/" \
        -e "1,/<IP>/s/<IP>/$addr2/" \
        -e "1,/<IP_PRIVATE>/s/<IP_PRIVATE>/$addr0_private/" \
        -e "1,/<IP_PRIVATE>/s/<IP_PRIVATE>/$addr1_private/" \
        -e "1,/<IP_PRIVATE>/s/<IP_PRIVATE>/$addr2_private/" \
        -e "s/<USER>/root/" \
        -e "s/<PEM_FILE>/id_rsa/" \
       rancher-cluster/rancher-cluster.yml > rke.yml
}

download_rke(){
    log Download rke
    local uname=$(uname -s -m)
    local version=0.1.7
    local base_url=https://github.com/rancher/rke/releases/download
    case "$uname" in
      "Linux x86_64")
          if [ ! -f rke ] ; then
              curl -Lo rke ${base_url}/v${version}/rke_linux-amd64
	  fi
	  chmod 755 rke
	  ;;
      Darwin*)
          if [ ! -f rke ] ; then
              curl -Lo rke ${base_url}/v${version}/rke_darwin-amd64
	  fi
	  chmod 755 rke
	  ;;
      MINGW64*)
          if [ ! -f rke.exe ] ; then
              curl -Lo rke.exe ${base_url}/v${version}/rke_windows-amd64.exe
	  fi
	  ;;
      *)
          echo "Unsupported platform $uname" 1>&2 >> log.txt
	  exit 1
    esac
}

test_kubernetes(){
    log test kubernetes
    kubectl --kubeconfig=kube_config_rke.yml get nodes
    kubectl --kubeconfig=kube_config_rke.yml get pods --all-namespaces
    log test finished
}

create_tiller(){
    log Creating tiller
    kubectl --kubeconfig=kube_config_rke.yml -n kube-system create serviceaccount tiller
    log Creating tiller succeeded
}

create_clusterrolebinding(){
    log Creating clusterrolebinding
    kubectl --kubeconfig=kube_config_rke.yml create clusterrolebinding tiller --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
    log Creating clusterrolebinding succeeded
}

helm_int(){
    sleep 10
    log helm init
    helm --kubeconfig=kube_config_rke.yml init --service-account tiller
    log helm succeded
    log add rancher:stable repo
    sleep 10
    helm --kubeconfig=kube_config_rke.yml repo add rancher-stable https://releases.rancher.com/server-charts/stable
    log add rancher:stable succeded
}

install_cert_manager(){
    log installing cert manager
    sleep 10
    helm --kubeconfig=kube_config_rke.yml install stable/cert-manager --name cert-manager --namespace kube-system --version v0.5.2
    log installing cert manager finished
}

install_rancher(){
    log installing rancher 2
    sleep 10
    helm --kubeconfig=kube_config_rke.yml install rancher-stable/rancher --name rancher --namespace cattle-system --set hostname=rc.${DOMAIN_SUFFIX} --set ingress.tls.source=letsEncrypt --set letsEncrypt.email=$CERT_EMAIL
    sleep 10
    kubectl --kubeconfig=kube_config_rke.yml -n cattle-system rollout status deploy/rancher
    log installing rancher 2 finished
}

describe_cert(){
    kubectl --kubeconfig=kube_config_rke.yml -n cattle-system describe certificate
    sleep 10
}

cleanup(){
    rm -f rke* lego* *.yml log.txt
    rm -fr .lego
}

if [ -z "$DIGITALOCEAN_TOKEN" ] ; then
    echo "set DIGITALOCEAN_TOKEN first." 1>&2 >> log.txt
    exit 1
fi

if [ -z "$DOMAIN_SUFFIX" ] ; then
    echo "set DOMAIN_SUFFIX first." 1>&2 >> log.txt
    exit 1
fi

if [ -z "$CERT_EMAIL" ] ; then
    echo "set CERT_EMAIL first." 1>&2 >> log.txt
    exit 1
fi

if [ ! -d .terraform ] ; then
    log terraform init
    terraform init
fi

if [ ! -f id_rsa ] ; then
    log Generate SSH key pair
    ssh-keygen -t rsa -b 2048 -P "" -f id_rsa
fi

case "$1" in
  # apply
  a*|u*)
      terraform plan \
        -var domain_suffix=$DOMAIN_SUFFIX \
	-out tf.plan
      terraform apply tf.plan
      wait_server_boot
      gen_rke_config
      download_rke
      log rke up
      ./rke up --config rke.yml
      test_kubernetes
      create_tiller
      create_clusterrolebinding
      helm_int
      install_cert_manager
      install_rancher
      describe_cert

      echo >> log.txt
      echo "Try open https://rc.${DOMAIN_SUFFIX}/" >> log.txt
      echo >> log.txt
    ;;
  d*)
      terraform destroy -var domain_suffix=$DOMAIN_SUFFIX
    ;;
  p*)
      terraform plan -var domain_suffix=$DOMAIN_SUFFIX
    ;;
  c*)
      terraform destroy -var domain_suffix=$DOMAIN_SUFFIX
      cleanup
    ;;
  *) echo "Usage: $0 {up|plan|destroy|cleanup}" 1>&2 >> log.txt
     exit 1
esac
