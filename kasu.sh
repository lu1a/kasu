#!/bin/bash

if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as the root user."
    exit 1
fi

apt-get install -y curl

mkdir -p /etc/apt/keyrings &&
curl -fsSL https://repo.charm.sh/apt/gpg.key | gpg --batch --yes --dearmor -o /etc/apt/keyrings/charm.gpg &&
echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | tee /etc/apt/sources.list.d/charm.list &&
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | gpg --batch --yes --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg &&
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list &&
apt update &&
apt-get -y install gum

gum style --foreground 255 'Pick the mode'
MODE=$(gum choose "worker" "control-plane")
echo "$MODE deps will be installed"

# assuming you're root

gum spin --spinner line --title "🛜 Turning swap off, setting ip-forwarding on..." -- apt update && apt upgrade -y;
apt-get install -y apt-transport-https ca-certificates;

swapoff -a;
{ head -n -1 /etc/fstab && tail -n 1 /etc/fstab | sed 's/^/#/'; } > /etc/fstab-temp && mv /etc/fstab-temp /etc/fstab;

sysctl net.ipv4.ip_forward=1;
sed -i '/#net.ipv4.ip_forward=1/s/^#//' /etc/sysctl.conf

# echo "🛜 Installed curl, turned swap off, set ip-forwarding on"

gum spin --spinner line --title "🚢 Installing containerd-1.7.6 and runc-1.1.9" -- wget https://github.com/containerd/containerd/releases/download/v1.7.6/containerd-1.7.6-linux-amd64.tar.gz;
tar Cxzvf /usr/local containerd-1.7.6-linux-amd64.tar.gz;
wget https://github.com/opencontainers/runc/releases/download/v1.1.9/runc.amd64;
install -m 755 runc.amd64 /usr/local/sbin/runc;
wget https://github.com/containernetworking/plugins/releases/download/v1.3.0/cni-plugins-linux-amd64-v1.3.0.tgz;
mkdir -p /opt/cni/bin;
tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-v1.3.0.tgz;
mkdir /etc/containerd;
containerd config default | tee /etc/containerd/config.toml;
sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml;
curl -L https://raw.githubusercontent.com/containerd/containerd/main/containerd.service -o /etc/systemd/system/containerd.service;
systemctl daemon-reload;
systemctl enable --now containerd;
echo "# these first two endpoint setting is where you configure crictl to containerd
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 2
debug: true
pull-image-on-create: false" | sudo tee /etc/crictl.yaml

# echo "🚢 Installed containerd-1.7.6 and runc-1.1.9"

gum spin --spinner line --title "☸️ Installing kubelet kubeadm kubectl, version 1.28" -- apt-get install -y kubelet kubeadm kubectl;
apt-mark hold kubelet kubeadm kubectl

# echo "☸️ Installed kubelet kubeadm kubectl, version 1.28"

gum spin --spinner line --title "👷🐝 Installing helm and cilium" -- modprobe br_netfilter;
echo "br_netfilter" | sudo tee /etc/modules-load.d/k8s.conf;
systemctl restart systemd-modules-load;

wget https://get.helm.sh/helm-v3.13.0-linux-amd64.tar.gz;
tar -zxvf helm-v3.13.0-linux-amd64.tar.gz;
mv linux-amd64/helm /usr/local/bin/helm;
helm repo add cilium https://helm.cilium.io/

# echo "👷🐝 Installed helm and cilium"

gum spin --spinner line --title "📦 Pulling k8s images" -- kubeadm config images pull

# echo "📦 Pulled k8s images"

if [ $MODE == "control-plane" ]; then
    echo "⚙️ Initialising the control plane"
    kubeadm init
    gum spin --spinner line --title "✨ Final touches: KUBECONFIG=/etc/kubernetes/admin.conf, activating cilium" -- mkdir -p $HOME/.kube;
    cp -i /etc/kubernetes/admin.conf $HOME/.kube/config;
    chown $(id -u):$(id -g) $HOME/.kube/config;
    export KUBECONFIG=/etc/kubernetes/admin.conf;

    helm install cilium cilium/cilium --version 1.14.2 --namespace kube-system;
    echo "✅ Done! Check it yourself with crictl ps"
elif [ $MODE == "worker" ]; then
    JOIN_COMMAND=$(gum input --width 500 --placeholder "copy-paste your 'kubeadm join YOUR_TOKENS_HERE' (as 1 line!!!)")
    eval "$JOIN_COMMAND"
fi