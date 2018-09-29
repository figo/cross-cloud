variable "master_node_count" {}
variable "name" {}
variable "hostname" {}
variable "hostname_suffix" {}
variable "hostname_path" {}

variable "etcd_endpoint" {}
variable "etcd_discovery" {}

variable "etcd_artifact" {}
variable "kube_apiserver_artifact" {}
variable "kube_controller_manager_artifact" {}
variable "kube_scheduler_artifact" {}

variable "cloud_provider" {}
variable "cloud_config" {}
variable "cluster_domain" {}
variable "pod_cidr" {}
variable "master_pod_cidr" {}
variable "service_cidr" {}
variable "dns_service_ip" {}
variable "non_masquerade_cidr" {}
variable "internal_lb_ip" {}

variable "ca" {}
variable "ca_key" {}
variable "apiserver" {}
variable "apiserver_key" {}
variable "controller" {}
variable "controller_key" {}
variable "scheduler" {}
variable "scheduler_key" {}
variable "cloud_config_file" {}

variable "dns_conf" {}
variable "dns_dhcp" {}
variable "kubelet_artifact" {}
variable "cni_artifact" {}
variable "cni_plugins_artifact" {}
variable "kube_proxy_artifact" {}
variable "kubelet" {}
variable "kubelet_key" {}
variable "proxy" {}
variable "proxy_key" {}
variable "bootstrap" {}
