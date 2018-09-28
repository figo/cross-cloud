resource "gzip_me" "ca" {
  input = "${ var.ca }"
}

resource "gzip_me" "kubelet_crt" {
  input = "${ var.kubelet }"
}

resource "gzip_me" "kubelet_key" {
  input = "${ var.kubelet_key }"
}

resource "gzip_me" "proxy" {
  input = "${ var.proxy }"
}

resource "gzip_me" "proxy_key" {
  input = "${ var.proxy_key }"
}
resource "gzip_me" "controller" {
  input = "${ var.controller }"
}

resource "gzip_me" "controller_key" {
  input = "${ var.controller_key }"
}

resource "gzip_me" "dns_conf" {
  input = "${ var.dns_conf }"
}

resource "gzip_me" "dns_dhcp" {
  input = "${ var.dns_dhcp }"
}

resource "gzip_me" "kubelet" {
  count = "${ var.worker_node_count }"
  input = "${ element(data.template_file.kubelet.*.rendered, count.index) }"
}

data "template_file" "kubelet" {
  count    = "${ var.worker_node_count }"
  template = "${ file( "${ path.module }/kubelet" )}"

  vars {
    cluster_domain      = "${ var.cluster_domain }"
    cloud_provider      = "${ var.cloud_provider }"
    cloud_config        = "${ var.cloud_config }"
    dns_service_ip      = "${ var.dns_service_ip }"
    non_masquerade_cidr = "${ var.non_masquerade_cidr }"
  }
}

resource "gzip_me" "kubelet_bootstrap_kubeconfig" {
  input = "${ data.template_file.kubelet_bootstrap_kubeconfig.rendered }"
}

data "template_file" "kubelet_bootstrap_kubeconfig" {
  template = "${ file( "${ path.module }/kubeconfig" )}"

  vars {
    cluster             = "certificate-authority: /etc/srv/kubernetes/pki/ca-certificates.crt \n    server: https://${ var.internal_lb_ip }"
    user                = "kubelet-bootstrap"
    name                = "service-account-context"
    user_authentication = "token: ${ var.bootstrap }"
  }
}

resource "gzip_me" "kube_controller_manager_kubeconfig" {
  input = "${ data.template_file.kube_controller_manager_kubeconfig.rendered }"
}

data "template_file" "kube_controller_manager_kubeconfig" {
  template = "${ file( "${ path.module }/kubeconfig" )}"

  vars {
    cluster             = "certificate-authority: /etc/srv/kubernetes/pki/ca-certificates.crt \n    server: https://${ var.internal_lb_ip }"
    user                = "kube-controller-manager"
    name                = "service-account-context"
    user_authentication = "client-certificate: /etc/srv/kubernetes/pki/controller.crt \n    client-key: /etc/srv/kubernetes/pki/controller.key"
  }
}

resource "gzip_me" "proxy_kubeconfig" {
  input = "${ data.template_file.proxy_kubeconfig.rendered }"
}

data "template_file" "proxy_kubeconfig" {
  template = "${ file( "${ path.module }/kubeconfig" )}"

  vars {
    cluster             = "certificate-authority: /etc/srv/kubernetes/pki/ca-certificates.crt \n    server: https://${ var.internal_lb_ip }"
    user                = "kube-proxy"
    name                = "service-account-context"
    user_authentication = "client-certificate: /etc/srv/kubernetes/pki/proxy.crt \n    client-key: /etc/srv/kubernetes/pki/proxy.key"
  }
}

resource "gzip_me" "cni_subnet" {
  count = "${ var.worker_node_count}" 
  input = "${ element(data.template_file.cni_subnet.*.rendered, count.index) }"
}

data "template_file" "cni_subnet" {
  count    = "${ var.worker_node_count }"
  template = "${ file( "${ path.module }/flannel-subnet.env" )}"

  vars {
    pod_cidr_subnet = "${ cidrsubnet("${ var.worker_pod_cidr }", 4, count.index)}"
    pod_cidr = "${ var.pod_cidr}"
  }
}

resource "gzip_me" "cni_flannel" {
  input = "${ data.template_file.cni_flannel.rendered }"
}

data "template_file" "cni_flannel" {
  template = "${ file( "${ path.module }/flannel" )}"
}

resource "gzip_me" "cni_loopback" {
  input = "${ data.template_file.cni_loopback.rendered }"
}

data "template_file" "cni_loopback" {
  template = "${ file( "${ path.module }/cni-loopback" )}"
}


resource "gzip_me" "kube_proxy" {
  count = "${ var.worker_node_count}"
  input = "${ element(data.template_file.kube-proxy.*.rendered, count.index) }"
}

data "template_file" "kube-proxy" {
  count    = "${ var.worker_node_count }"
  template = "${ file( "${ path.module }/kube-proxy" )}"

  vars {
    pod_cidr         = "${ var.worker_pod_cidr }"
  }
}

data "template_file" "worker" {
  count    = "${ var.worker_node_count }"
  template = "${ file( "${ path.module }/worker.yml" )}"

  vars {
    hostname                     = "${ var.hostname }-${ count.index + 1 }.${ var.hostname_suffix }"
    hostname_path                = "${ var.hostname_path }"
    cloud_config_file            = "${ base64gzip(var.cloud_config_file) }"
    ca                           = "${ gzip_me.ca.output }"
    controller                   = "${ gzip_me.controller.output }"
    controller_key               = "${ gzip_me.controller_key.output }"
    kubelet_crt                  = "${ gzip_me.kubelet_crt.output }"
    kubelet_key                  = "${ gzip_me.kubelet_key.output }"
    proxy                        = "${ gzip_me.proxy.output }"
    proxy_key                    = "${ gzip_me.proxy_key.output }"
    kubelet                      = "${ element(gzip_me.kubelet.*.output, count.index) }"
    kubelet_bootstrap_kubeconfig = "${ gzip_me.kubelet_bootstrap_kubeconfig.output }"
    kube_proxy                   = "${ element(gzip_me.kube_proxy.*.output, count.index) }"
    proxy_kubeconfig             = "${ gzip_me.proxy_kubeconfig.output }"
    kubelet_artifact             = "${ var.kubelet_artifact }"
    cni_artifact                 = "${ var.cni_artifact }"
    kube_proxy_artifact          = "${ var.kube_proxy_artifact }"
    cni_plugins_artifact         = "${ var.cni_plugins_artifact }"
    cni_subnet                   = "${ element(gzip_me.cni_subnet.*.output, count.index) }"
    cni_loopback                 = "${ gzip_me.cni_loopback.output }"
    cni_flannel                  = "${ gzip_me.cni_flannel.output }"
    kube_controller_manager_kubeconfig = "${ gzip_me.kube_controller_manager_kubeconfig.output }"
    dns_conf                     = "${ gzip_me.dns_conf.output }"
    dns_dhcp                     = "${ gzip_me.dns_dhcp.output }"
  }
}
