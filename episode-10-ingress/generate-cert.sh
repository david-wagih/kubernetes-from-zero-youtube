#!/usr/bin/env bash
# Creates a self-signed certificate for app.example.com + api.example.com
# and stores it in a Kubernetes TLS Secret called "myapp-tls".
set -euo pipefail

ctx=$(kubectl config current-context)
if [[ "$ctx" != kind-* ]]; then
  echo "Current kubectl context is '$ctx', not a kind cluster. Aborting." >&2
  exit 1
fi

cd "$(dirname "$0")"
mkdir -p certs

openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
  -keyout certs/tls.key \
  -out certs/tls.crt \
  -subj "/CN=app.example.com" \
  -addext "subjectAltName=DNS:app.example.com,DNS:api.example.com"

kubectl create secret tls myapp-tls \
  --cert=certs/tls.crt \
  --key=certs/tls.key \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Secret myapp-tls created from certs/tls.crt + certs/tls.key"
