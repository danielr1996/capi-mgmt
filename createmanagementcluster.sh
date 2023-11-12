CLUSTER="${1:-"capi-test"}"
CAPHVERSION=v1.0.0-beta.17
CAAPHVERSION=v0.1.0-alpha.10
VELEROAWSVERSION=v1.8.1

case $CLUSTER in
"capi-test")
  echo "installing test cluster"
  kind create cluster --name "$CLUSTER" --kubeconfig ~/.kube/"$CLUSTER"
  source "${BASH_SOURCE%/*}/values/capi-test.sh"
;;

"capi-prod")
  echo "installing prod cluster"
  source "${BASH_SOURCE%/*}/values/capi-prod.sh"
ssh -o "StrictHostKeyChecking=no" -q root@"$PRODIP" << 'ENDSSH'
  for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove "$pkg"; done
  apt-get -y update
  apt-get -y install ca-certificates curl gnupg
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null
  apt-get -y update
  apt-get -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-arm64
  chmod +x ./kind
  mv ./kind /usr/local/bin/kind
  cat <<EOF | kind create cluster --name capi-prod --kubeconfig ~/.kube/capi-prod --config=-
    kind: Cluster
    apiVersion: kind.x-k8s.io/v1alpha4
    networking:
      apiServerAddress: "$(ip route get 1.1.1.1 | awk -F"src " 'NR==1{split($2,a," ");print a[1]}')"
  EOF
ENDSSH
scp root@"$PRODIP":~/.kube/capi-prod ~/.kube/capi-prod
;;
*)
  echo "do nothing"
esac

export EXP_CLUSTER_RESOURCE_SET=true
KUBECONFIG=~/.kube/"$CLUSTER" clusterctl init --infrastructure hetzner:"$CAPHVERSION" --addon helm:"$CAAPHVERSION"


cat <<EOF > credentials
[default]
aws_access_key_id=$AWS_KEYID
aws_secret_access_key=$AWS_KEYSECRET
EOF

KUBECONFIG=~/.kube/"$CLUSTER" velero install \
    --provider aws \
    --plugins velero/velero-plugin-for-aws:$VELEROAWSVERSION \
    --bucket "$AWS_BUCKET" \
    --secret-file credentials \
    --use-volume-snapshots=false \
    --backup-location-config region="$AWSREGION",s3Url="$AWSURL"
rm credentials

