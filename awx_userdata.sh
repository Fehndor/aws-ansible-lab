#!/bin/bash
set -e
set +e  # Don't exit on error after this point for non-critical steps

dnf update -y
dnf install -y --allowerasing git curl wget python3-pip
pip3 install ansible

curl -sfL https://get.k3s.io | sh -s - \
  --disable traefik \
  --write-kubeconfig-mode 644

echo "Waiting for K3s to be ready..."
sleep 30
until kubectl get nodes | grep -q "Ready"; do
  sleep 10
done

mkdir -p /home/ec2-user/.kube
cp /etc/rancher/k3s/k3s.yaml /home/ec2-user/.kube/config
chown ec2-user:ec2-user /home/ec2-user/.kube/config
chmod 600 /home/ec2-user/.kube/config
echo 'export KUBECONFIG=/home/ec2-user/.kube/config' >> /home/ec2-user/.bashrc

curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

helm repo add awx-operator https://ansible-community.github.io/awx-operator-helm/
helm repo update
kubectl create namespace awx
helm install awx-operator awx-operator/awx-operator \
  -n awx \
  --set nodeSelector."kubernetes\.io/os"=linux

echo "Waiting for AWX Operator..."
sleep 30
until kubectl get pods -n awx | grep "awx-operator" | grep -q "Running"; do
  sleep 15
done

kubectl create secret generic awx-postgres-secret \
  -n awx \
  --from-literal=host=${postgres_private_ip} \
  --from-literal=port=5432 \
  --from-literal=database=awx \
  --from-literal=username=awx \
  --from-literal=password=${postgres_password} \
  --from-literal=sslmode=prefer \
  --from-literal=type=unmanaged

cat > /tmp/awx-instance.yaml << AWXYAML
apiVersion: awx.ansible.com/v1beta1
kind: AWX
metadata:
  name: awx
  namespace: awx
spec:
  service_type: NodePort
  nodeport_port: 30080
  postgres_configuration_secret: awx-postgres-secret
AWXYAML

kubectl apply -f /tmp/awx-instance.yaml

dnf install -y iptables iptables-services
iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 30080
service iptables save
systemctl enable iptables

cat > /home/ec2-user/check_awx.sh << 'CHECKSCRIPT'
#!/bin/bash
echo "=== K3s Node Status ==="
kubectl get nodes
echo ""
echo "=== AWX Namespace Pods ==="
kubectl get pods -n awx
echo ""
echo "=== AWX Admin Password ==="
kubectl get secret awx-admin-password -n awx -o jsonpath='{.data.password}' 2>/dev/null | base64 --decode && echo "" || echo "Not ready yet"
CHECKSCRIPT

chown ec2-user:ec2-user /home/ec2-user/check_awx.sh
chmod +x /home/ec2-user/check_awx.sh

echo "AWX/K3s bootstrap completed at $(date)" > /home/ec2-user/bootstrap_complete.txt
chown ec2-user:ec2-user /home/ec2-user/bootstrap_complete.txt
