#!/bin/bash

#this has been added into the vagrant box kubernetes
#sudo apt-get update
#sudo apt-get install apt-transport-https ca-certificates -y
#sudo apt-get install curl \
#    linux-image-extra-$(uname -r) \
#    linux-image-extra-virtual -y
#curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
#sudo apt-key adv \
#               --keyserver hkp://ha.pool.sks-keyservers.net:80 \
#               --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
#curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
#echo 'deb https://apt.dockerproject.org/repo ubuntu-xenial main' | sudo tee /etc/apt/sources.list.d/docker.list
#echo 'deb http://apt.kubernetes.io/ kubernetes-xenial main' | sudo tee /etc/apt/sources.list.d/kubernetes.list
#sudo apt-get update
#sudo apt-get install docker-engine=1.12* python-pip joe kubeadm kubelet kubectl kubernetes-cni nfs-common -y

#init docker services
sudo service docker start
sudo groupadd docker
sudo usermod -aG docker ubuntu

#Setup Kubernetes
#sudo apt-get install kubeadm kubelet kubectl kubernetes-cni -y
ADDRESS="$(ip -4 addr show enp0s8 | grep "inet" | head -1 |awk '{print $2}' | cut -d/ -f1)"
sudo sed -e "s/^.*master.*/${ADDRESS} master master.local/" -i /etc/hosts
sudo sed -e '/^.*ubuntu-xenial.*/d' -i /etc/hosts
sudo sed -i -e 's/AUTHZ_ARGS=.*/AUTHZ_ARGS="/' /etc/systemd/system/kubelet.service.d/10-kubeadm.conf

sudo systemctl daemon-reload

#Copy all config from the manifests file and deploy the default applications
#We make use of the existing certificates 
sudo mkdir -p /etc/kubernetes/pki 
sudo cp /vagrant/kubernetes/pki/* /etc/kubernetes/pki
sudo kubeadm init --config /vagrant/kubernetes/masterconfig.yaml

sleep 5
sudo mkdir -p /root/.kube/
sudo cp /etc/kubernetes/admin.conf /root/.kube/config
sudo cp /etc/kubernetes/admin.conf /vagrant/

#install weave overlay network
sudo kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"

#run the standard pods that we always need
sudo kubectl apply -f /vagrant/kubernetes/yamls/namespace-production.yaml
sudo kubectl apply -f /vagrant/kubernetes/yamls/kubernetes-default-http-backend.yaml
sudo kubectl apply -f /vagrant/kubernetes/yamls/kubernetes-ingress-rbac.yaml
sudo kubectl apply -f /vagrant/kubernetes/yamls/kubernetes-ingress.yaml
sudo kubectl apply -f /vagrant/kubernetes/influxdb
sudo kubectl apply -f /vagrant/kubernetes/rbac/heapster-rbac.yaml
sudo kubectl apply -f /vagrant/kubernetes/yamls/mysql_service.yaml
sudo kubectl apply -f /vagrant/petclinic.yaml

#Ping the jenkins hosts to resolve any ARP cache issues
ping -c 4 192.168.56.2

# Add storage on master and export via NFS
apt-get install nfs-kernel-server -y
mkdir -p /var/nfs/general
mkfs.ext4 -L nfs-general /dev/sdc
echo 'LABEL=nfs-general ext4 defaults 0 0' >> /etc/fstab
echo '/var/nfs/general *(rw,sync,no_subtree_check)' >> /etc/exports

#Add MySQL Storage on the main cluster
mkdir -p /var/nfs/mysql
echo 'LABEL=nfs-mysql ext4 defaults 0 0' >> /etc/fstab
echo '/var/nfs/mysql *(rw,sync,no_subtree_check,no_root_squash)' >> /etc/exports

exportfs -a
