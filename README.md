# 🚀 Private AKS with Azure CNI Powered by Cilium (eBPF)

[![Terraform](https://img.shields.io/badge/Terraform-1.16+-623CE4?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![Azure](https://img.shields.io/badge/Microsoft_Azure-swedencentral-0078D4?logo=microsoftazure&logoColor=white)](https://azure.microsoft.com/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-v1.30+-326CE5?logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![Cilium](https://img.shields.io/badge/Cilium-eBPF_Datapath-F59121?logo=cilium&logoColor=white)](https://cilium.io/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

An enterprise-grade, reproducible sandbox lab demonstrating a **Private Azure Kubernetes Service (AKS)** cluster configured with **Azure CNI Powered by Cilium in Overlay mode**. 

This repository explores the elimination of `kube-proxy` in favor of Linux Kernel eBPF Socket-Level Load Balancing ($O(1)$ Hash Map lookups), private control plane isolation via Jumpbox architecture, self-healing pod lifecycles, and production-level troubleshooting.

---

## 🏗️ Architecture Overview

The infrastructure isolates the Kubernetes Control Plane (API Server) inside a Virtual Network, blocking all direct inbound traffic from the public internet. Management and operations are conducted securely via an air-gapped Linux Jumpbox VM.

```text
[ Developer Machine / WSL ]
           │
           │  (SSH Port 22 - TLS RSA 4096)
           ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ Azure Virtual Network: vnet-aks-lab (10.200.0.0/16)                      │
│                                                                         │
│  ┌─────────────────────────────┐    ┌────────────────────────────────┐  │
│  │ Subnet: snet-jumpbox        │    │ Subnet: snet-aks-nodes         │  │
│  │ (10.200.1.0/24)             │    │ (10.200.2.0/24)                │  │
│  │                             │    │                                │  │
│  │ ┌─────────────────────────┐ │    │ ┌────────────────────────────┐ │  │
│  │ │ Jumpbox VM              │ │    │ │ AKS Worker Node            │ │  │
│  │ │ (Standard_D2s_v5)       │ │    │ │ (aks-systempool / 10.200.2.x)│ │
│  │ │ - Azure CLI & Kubectl   │ │    │ │ - Linux Kernel 6.8 (eBPF)  │ │  │
│  │ └────────────┬────────────┘ │    │ └──────────────┬─────────────┘ │  │
│  └──────────────┼──────────────┘    └────────────────┼───────────────┘  │
│                 │ (kubectl / HTTPS Port 6443)        │                  │
│                 ▼                                    │                  │
│  ┌──────────────────────────────────────────────┐    │                  │
│  │ Private AKS Control Plane (API Server)       │    │                  │
│  │ (Private Endpoint & CoreDNS Resolution)      │    │                  │
│  └──────────────────────────────────────────────┘    │                  │
│                                                      ▼                  │
│                                     ┌─────────────────────────────────┐ │
│                                     │ Cilium Overlay (10.244.0.0/16)  │ │
│                                     │  ┌───────────────────────────┐  │ │
│                                     │  │ Pod Replicas (3x Nginx)   │  │ │
│                                     │  │ Dynamic IPs: 10.244.0.x   │  │ │
│                                     │  └─────────────▲─────────────┘  │ │
│                                     │                │ Socket-Level LB│ │
│                                     │  ┌─────────────┴─────────────┐  │ │
│                                     │  │ Service: web-service      │  │ │
│                                     │  │ Dynamic ClusterIP (10.0.x)│  │ │
│                                     │  └───────────────────────────┘  │ │
│                                     └─────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
```

> **📌 Note on IP Addresses:**
> All IP addresses displayed in architectural diagrams and execution logs (e.g. `10.200.2.5` for the node, `10.244.0.x` for pods, and `10.0.63.110` for ClusterIP) are dynamic runtime examples captured during live benchmark verification. On every `terraform apply`, Azure and Kubernetes dynamically allocate fresh IP addresses within their designated subnet and overlay CIDR ranges.

---

## ⚡ Why Cilium eBPF over Traditional Kube-Proxy?

| Feature | Geleneksel `kube-proxy` + `iptables` | Azure CNI Powered by Cilium (eBPF) |
| :--- | :--- | :--- |
| **Routing Complexity** | $O(N)$ — Kurallar sıralı taranır. Binlerce serviste CPU ve gecikme tavan yapar. | **$O(1)$** — Linux Kernel Hash Map ile sabit nanosaniye erişim süresi. |
| **Packet Interception** | Paket TCP/IP ağ katmanını baştan sona dolaşır. | **Socket-Level Translation:** İstemci soketi açtığı anda (`connect` syscall) çekirdekte anında yönlendirilir. |
| **IP Exhaustion** | Flat CNI her Pod için VNet'ten IP harcar; Subnet hızla tükenir. | **Overlay Mode:** VNet'ten yalnızca Worker Node IP alır; Pod'lar izole VXLAN havuzunda yaşar. |
| **Data Plane Engine** | User Space ile Kernel Space arasında sürekli context switch. | Linux Kernel içinde çalışan güvenli, sandbox edilmiş eBPF Bytecode. |

---

## 🔬 Deep-Dive Live Verification & Proofs

### 1. Linux Kernel eBPF Load Balancing Hash Map
Inside the Cilium agent daemonset, inspecting the kernel BPF tables reveals that `web-service` (`10.0.63.110:80` in our verified run) points directly to the 3 pod endpoints without passing through iptables:

```bash
$ kubectl -n kube-system exec daemonset/cilium -c cilium-agent -- cilium-dbg bpf lb list

SERVICE ADDRESS          BACKEND ADDRESS (REVNAT_ID) (SLOT)
10.0.63.110:80/TCP (3)   10.244.0.115:80/TCP (5) (3)   # Slot 3 -> Pod 3
10.0.63.110:80/TCP (0)   0.0.0.0:0 (5) (0) [ClusterIP] # Master Virtual IP
10.0.63.110:80/TCP (2)   10.244.0.83:80/TCP (5) (2)    # Slot 2 -> Pod 2
10.0.63.110:80/TCP (1)   10.244.0.10:80/TCP (5) (1)    # Slot 1 -> Pod 1
```
*Note: Entries appear in hash-order rather than sequential order because they are stored in a kernel-level eBPF Hash Map.*

### 2. Pod Lifecycle & Self-Healing
- **Bare Pod vs. Deployment:** Deleting a standalone pod permanently terminates it. In contrast, pods managed by a Deployment/ReplicaSet continuously evaluate `Desired State vs. Current State` (Reconciliation Loop); deleting a pod causes the ReplicaSet to spawn a replacement within seconds.
- **Horizontal Scaling:** Scaling to 3 replicas instantly assigns unique overlay IPs (`10.244.0.x`) and registers 3 new endpoints in the Cilium datapath (`cilium-dbg endpoint list`).

### 3. Production Troubleshooting Post-Mortem
- **`ImagePullBackOff` Teşhisi:** Sahte bir imaj tag'i (`nginx:nonexistent999`) ile pod çalıştırıldığında container'ın hiç başlayamadığı; `kubectl describe pod` çıktısındaki `Events` tablosundan 404 Registry hatası tespit edilmiştir.
- **`CrashLoopBackOff` Teşhisi:** Container'ın başarıyla indiği ancak ana sürecin sonlandığı (`exit 1`) senaryoda; Kubelet restart sayacının kademeli artışı ve `Last State: Terminated -> Exit Code: 1` CLI teşhisiyle kök neden analizi gerçekleştirilmiştir.

---

## 📦 Project Structure

```text
.
├── aks.tf              # Private AKS Cluster & Azure CNI Cilium Profile
├── jumpbox.tf          # Bastion VM, Dynamic TLS Key, NSG (Port 22), NIC
├── network.tf          # Resource Group, VNet (10.200.0.0/16), Subnets
├── outputs.tf          # Jumpbox Public IP, Cluster Name, Private FQDN
├── providers.tf        # HashiCorp azurerm (v5.x) & tls providers
└── variables.tf        # Configurable deployment parameters
```

---

## 🚀 Quickstart & Deployment

### 1. Prerequisites
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) logged in (`az login`)
- [Terraform](https://www.terraform.io/) >= 1.0.0
- Active Azure Subscription

### 2. Deploy Infrastructure
```bash
git clone https://github.com/Elxeoo/aks-cilium-ebpf-lab.git
cd aks-cilium-ebpf-lab

terraform init
terraform plan
terraform apply -auto-approve
```

### 3. Connect via Jumpbox
```bash
# Extract dynamic SSH private key
terraform output -raw jumpbox_private_key > ~/.ssh/id_rsa_jumpbox
chmod 600 ~/.ssh/id_rsa_jumpbox

# SSH into Jumpbox
ssh -i ~/.ssh/id_rsa_jumpbox azureuser@<JUMPBOX_PUBLIC_IP>

# Verify Kubernetes & Cilium
kubectl get nodes -o wide
kubectl -n kube-system exec daemonset/cilium -c cilium-agent -- cilium-dbg status
```

### 4. Teardown (FinOps / $0.00 Cost)
```bash
terraform destroy -auto-approve
```

---

## 👤 Author
**Can Dumanlı**  
*Cloud & DevOps Engineer*  
- GitHub: [@Elxeoo](https://github.com/Elxeoo)  

---
## 📄 License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
