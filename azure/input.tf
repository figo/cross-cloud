variable "name" { default = "azure" }

variable "internal_tld" { default = "cncf.demo" }
variable "data_dir" { default = "/cncf/data/azure" }

# Azure Cloud Specific Settings
variable "location"        { default = "westus" }
variable "vpc_cidr"        { default = "10.0.0.0/8" }
variable "subnet_cidr"     { default = "10.240.0.0/16"}
variable "internal_lb_ip"  { default = "10.240.0.100"}

# VM Image and size
variable "admin_username" { default = "cncf"}
variable "image_publisher" { default = "CoreOS" }
variable "image_offer"     { default = "CoreOS" }
variable "image_sku"       { default = "Stable" }
variable "image_version"   { default = "1465.8.0" }
variable "master_vm_size"   { default = "Standard_A2" }
variable "worker_vm_size"   { default = "Standard_A2" }
variable "bastion_vm_size"   { default = "Standard_A2" }

# Kubernetes
variable "cloud_provider" { default = "azure" }
variable "cloud_config" { default = "--cloud-config=/etc/srv/kubernetes/cloud-config" }
variable "cluster_domain" { default = "cluster.local" }
variable "pod_cidr" { default = "100.96.0.0/11" }
variable "service_cidr"   { default = "100.64.0.0/13" }
variable "non_masquerade_cidr" { default = "100.64.0.0/10"}
variable "dns_service_ip" { default = "100.64.0.10" }
variable "master_node_count" { default = "3" }
variable "worker_node_count" { default = "3" }
# Autoscaling not supported by Kuberenetes on Azure yet
# variable "worker_node_min" { default = "3" }
# variable "worker_node_max" { default = "5" }

# Deployment Artifact Versions
variable "kubelet_artifact" { default = "https://storage.googleapis.com/kubernetes-release/release/v1.7.2/bin/linux/amd64/kubelet" }
variable "cni_artifact" { default = "https://github.com/containernetworking/cni/releases/download/v0.5.2/cni-amd64-v0.5.2.tgz" }

variable "etcd_registry" { default = "registry.cncf.ci/etcd/etcd-docker"}
variable "etcd_tag" { default = "master.38cc76af.26448"}
variable "kube_apiserver_registry" { default = "gcr.io/google_containers/kube-apiserver"}
variable "kube_apiserver_tag" { default = "v1.7.2"}
variable "kube_controller_manager_registry" { default = "gcr.io/google_containers/kube-controller-manager"}
variable "kube_controller_manager_tag" { default = "v1.7.2"}
variable "kube_scheduler_registry" { default = "gcr.io/google_containers/kube-scheduler"}
variable "kube_scheduler_tag" { default = "v1.7.2"}
variable "kube_proxy_registry" { default = "gcr.io/google_containers/kube-proxy"}
variable "kube_proxy_tag" { default = "v1.7.2"}



variable "client_id" {}
variable "client_secret" {}
variable "tenant_id" {}
variable "subscription_id" {}

