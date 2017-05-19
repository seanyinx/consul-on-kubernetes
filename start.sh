#!/bin/bash

export PATH=$PATH:$GOPATH/bin

if ! [ -x "$(command -v cfssl)" ]; then
  echo "cfssl command not found, downloading cfssl and cfssljson..."
  go get -u github.com/cloudflare/cfssl/cmd/...
fi

cfssl gencert -initca ca/ca-csr.json | cfssljson -bare ca

echo "Generated TSL certificates"

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca/ca-config.json \
  -profile=default \
  ca/consul-csr.json | cfssljson -bare consul

echo "Created consul private key"

if ! [ -x "$(command -v consul)" ]; then
  echo "Consul client not found, downloading consul..."
  wget https://releases.hashicorp.com/consul/0.8.3/consul_0.8.3_linux_amd64.zip
  unzip consul_0.8.3_linux_amd64.zip -d $GOPATH/bin
fi


GOSSIP_ENCRYPTION_KEY=$(consul keygen)
echo "Generated consul gossip encripytion key"

kubectl create secret generic consul \
  --from-literal="gossip-encryption-key=${GOSSIP_ENCRYPTION_KEY}" \
  --from-file=ca.pem \
  --from-file=consul.pem \
  --from-file=consul-key.pem

kubectl create configmap consul --from-file=configs/server.json

echo "Created consul secrete and configmap"

kubectl create -f services/consul.yaml

echo "Created consul service"

kubectl create -f statefulsets/consul.yaml
echo "Created consul stateful set"

sleep 5

while (( $(kubectl get pods | grep -E "consul.*Running" | wc -l) != 3 ))
do
  kubectl get pods
  sleep 1s
done

kubectl get pods

kubectl create -f jobs/consul-join.yaml
