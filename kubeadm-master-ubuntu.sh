#!/bin/bash

sudo apt-get update
sudo apt-get install apt-transport-https ca-certificates -y
sudo apt-get install curl \
    linux-image-extra-$(uname -r) \
    linux-image-extra-virtual -y
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo apt-key adv \
               --keyserver hkp://ha.pool.sks-keyservers.net:80 \
               --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo 'deb https://apt.dockerproject.org/repo ubuntu-xenial main' | sudo tee /etc/apt/sources.list.d/docker.list
echo 'deb http://apt.kubernetes.io/ kubernetes-xenial main' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install docker-engine=1.12* python-pip joe kubeadm kubelet kubectl kubernetes-cni -y
sudo service docker start
sudo groupadd docker
sudo usermod -aG docker ubuntu
#sudo apt-get install python-pip -y
#sudo apt-get install joe -y
sudo -H pip install --upgrade pip

#Setup Kubernetes
#sudo apt-get install kubeadm kubelet kubectl kubernetes-cni -y
ADDRESS="$(ip -4 addr show enp0s8 | grep "inet" | head -1 |awk '{print $2}' | cut -d/ -f1)"
sudo sed -e "s/^.*master.*/${ADDRESS} master master.local/" -i /etc/hosts
sudo sed -e '/^.*ubuntu-xenial.*/d' -i /etc/hosts

sudo sed -i -e 's/AUTHZ_ARGS=.*/AUTHZ_ARGS="/' /etc/systemd/system/kubelet.service.d/10-kubeadm.conf

sudo systemctl daemon-reload

sudo kubeadm init --apiserver-advertise-address=192.168.56.10 --pod-network-cidr 10.32.0.0/12 --token=b9e6bb.6746bcc9f8ef8267
sleep 15
sudo mkdir -p /root/.kube/
sudo cp /etc/kubernetes/admin.conf /root/.kube/config
sudo cp /etc/kubernetes/admin.conf /vagrant/

su ubuntu
sudo cp /etc/kubernetes/admin.conf $HOME/
sudo chown $(id -u):$(id -g) $HOME/admin.conf
export KUBECONFIG=$HOME/admin.conf

#install weave overlay network
sudo kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"

sudo kubectl apply -f /vagrant/kubernetes-default-http-backend.yaml
sudo kubectl apply -f /vagrant/kubernetes-ingress-rbac.yaml
sudo kubectl apply -f /vagrant/kubernetes-ingress.yaml
sudo kubectl apply -f /vagrant/petclinic.yaml

#sudo kubectl config set-credentials kubernetes-admin/kubernetes --username=kubeuser --password=kubepassword
#sudo kubectl config set-cluster kubernetes --insecure-skip-tls-verify=true --server=https://192.168.56.10:6443
#sudo kubectl config set-context default/kubernetes/kubernetes-admin --user=kubernetes-admin/kubernetes --namespace=default --cluster=kubernetes
#sudo kubectl config use-context default/kubernetes/kubernetes-admin

# Add storage on master and export via NFS
apt-get install nfs-kernel-server nfs-common -y
mkdir -p /var/nfs/general
mkfs.ext4 -L nfs-general /dev/sdc
echo 'LABEL=nfs-general ext4 defaults 0 0' >> /etc/fstab
echo '/var/nfs/general *(rw,sync,no_subtree_check)' >> /etc/exports
mount -a
for n in one two three four; do mkdir /var/nfs/general/${n}; done
chown -R nobody.nogroup /var/nfs/general

mkdir -p /var/nfs/mysql
mkfs.ext4 -L nfs-mysql /dev/sdd
echo 'LABEL=nfs-mysql ext4 defaults 0 0' >> /etc/fstab
echo '/var/nfs/mysql *(rw,sync,no_subtree_check,no_root_squash)' >> /etc/exports

exportfs -a
