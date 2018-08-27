#!/bin/bash
# Usage
#
# provision.sh shell
# provision.sh <provider>-<command> <name> <config-backend> <data-folder>
#

# If the first argument is "shell" then exec into a shell and abandon
# the rest of the script.
if [ "$1" = "shell" ]; then exec /bin/bash; fi

# Initialize the configuration properties based on the command-line
# arguments OR on the corresponding environment variables.
CLOUD_CMD=$CLOUD-$COMMAND
DATA_FOLDER=$(pwd)/data
if [ ! "$1" = "" ]; then CLOUD_CMD=$1; fi
if [ ! "$2" = "" ]; then NAME=$2; fi
if [ ! "$3" = "" ]; then BACKEND=$3; fi
if [ ! "$4" = "" ]; then DATA_FOLDER=$4; fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
_retry() {
    [ -z "${2}" ] && return 1
    echo -n ${1}
    until printf "." && "${@:2}" &>/dev/null; do sleep 5.2; done; echo "✓"
}

set -e
RED='\033[0;31m'
NC='\033[0m' # No Color

# Setup Enviroment Using $NAME
export TF_VAR_name="$NAME"
export TF_VAR_data_dir="$DATA_FOLDER"
export TF_VAR_packet_api_key=${PACKET_AUTH_TOKEN}

# Configure Artifacts
if [ ! -e $KUBELET_ARTIFACT ] ; then
    export TF_VAR_kubelet_artifact=$KUBELET_ARTIFACT
fi

if [ ! -e $CNI_ARTIFACT ] ; then
    export TF_VAR_cni_artifact=$CNI_ARTIFACT
fi


if [ ! -e $ETCD_ARTIFACT ] ; then
    export TF_VAR_etcd_artifact=$ETCD_ARTIFACT
fi

if [ ! -e $KUBE_APISERVER_ARTIFACT ] ; then
    export TF_VAR_kube_apiserver_artifact=$KUBE_APISERVER_ARTIFACT
fi

if [ ! -e $KUBE_CONTROLLER_MANAGER_ARTIFACT ] ; then
    export TF_VAR_kube_controller_manager_artifact=$KUBE_CONTROLLER_MANAGER_ARTIFACT
fi

if [ ! -e $KUBE_SCHEDULER_ARTIFACT ] ; then
    export TF_VAR_kube_scheduler_artifact=$KUBE_SCHEDULER_ARTIFACT
fi

if [ ! -e $KUBE_PROXY_IMAGE ] ; then
    export TF_VAR_kube_proxy_image=$KUBE_PROXY_IMAGE
fi

if [ ! -e $KUBE_PROXY_TAG ] ; then
    export TF_VAR_kube_proxy_tag=$KUBE_PROXY_TAG
fi


 
# tfstate, sslcerts, and ssh keys are currently stored in TF_VAR_data_dir
mkdir -p $TF_VAR_data_dir

# Run CMD
if [ "$CLOUD_CMD" = "aws-deploy" ] ; then
    cd ${DIR}/aws
    if [ "$BACKEND" = "s3" ]; then
        cp ../s3-backend.tf .
    terraform init \
              -backend-config "bucket=${AWS_BUCKET}" \
              -backend-config "key=aws-${TF_VAR_name}" \
              -backend-config "region=${AWS_DEFAULT_REGION}"
    # ensure kubeconfig is written to disk on infrastructure refresh
    terraform taint -module=kubeconfig null_resource.kubeconfig || true
    time terraform apply -auto-approve ${DIR}/aws
    elif [ "$BACKEND" = "file" ]; then
        cp ../file-backend.tf .
        terraform init \
                  -backend-config "path=/cncf/data/${TF_VAR_name}/terraform.tfstate"
        # ensure kubeconfig is written to disk on infrastructure refresh
        terraform taint -module=kubeconfig null_resource.kubeconfig || true ${DIR}/aws
        time terraform apply -auto-approve  ${DIR}/aws
    fi

    export KUBECONFIG=${TF_VAR_data_dir}/kubeconfig
    _retry "❤ Trying to connect to cluster with kubectl" kubectl get cs
    _retry "❤ Ensure that the kube-system namespaces exists" kubectl get namespace kube-system
    _retry "❤ Ensure that ClusterRoles are available" kubectl get ClusterRole.v1.rbac.authorization.k8s.io
    _retry "❤ Ensure that ClusterRoleBindings are available" kubectl get ClusterRoleBinding.v1.rbac.authorization.k8s.io

elif [ "$CLOUD_CMD" = "aws-destroy" ] ; then
      cd ${DIR}/aws
      if [ "$BACKEND" = "s3" ]; then
          cp ../s3-backend.tf .
          terraform init \
                    -backend-config "bucket=${AWS_BUCKET}" \
                    -backend-config "key=aws-${TF_VAR_name}" \
                    -backend-config "region=${AWS_DEFAULT_REGION}"
    time terraform destroy -force ${DIR}/aws
      elif [ "$BACKEND" = "file" ]; then
          cp ../file-backend.tf .
          terraform init \
                    -backend-config "path=/cncf/data/${TF_VAR_name}/terraform.tfstate"
          time terraform destroy -force ${DIR}/aws

       fi

elif [ "$CLOUD_CMD" = "azure-deploy" ] ; then
    # There are some dependency issues around cert,sshkey,k8s_cloud_config, and dns
    # since they use files on disk that are created on the fly
    # should probably move these to data resources
    cd ${DIR}/azure
    if [ "$BACKEND" = "s3" ]; then
        cp ../s3-backend.tf .
    terraform init \
              -backend-config "bucket=${AWS_BUCKET}" \
              -backend-config "key=azure-${TF_VAR_name}" \
              -backend-config "region=${AWS_DEFAULT_REGION}"
    # ensure kubeconfig is written to disk on infrastructure refresh
    terraform taint -module=kubeconfig null_resource.kubeconfig || true
        terraform apply -target azurerm_resource_group.cncf -auto-approve ${DIR}/azure && \
        terraform apply -target module.network.azurerm_virtual_network.cncf -auto-approve ${DIR}/azure || true && \
        terraform apply -target module.network.azurerm_subnet.cncf -auto-approve ${DIR}/azure || true && \
        time terraform apply -auto-approve ${DIR}/azure

    elif [ "$BACKEND" = "file" ]; then
        cp ../file-backend.tf .
        terraform init \
                  -backend-config "path=/cncf/data/${TF_VAR_name}/terraform.tfstate"
        # ensure kubeconfig is written to disk on infrastructure refresh
        terraform taint -module=kubeconfig null_resource.kubeconfig || true
            terraform apply -target azurerm_resource_group.cncf -auto-approve ${DIR}/azure && \
            terraform apply -target module.network.azurerm_virtual_network.cncf -auto-approve ${DIR}/azure || true && \
            terraform apply -target module.network.azurerm_subnet.cncf -auto-approve ${DIR}/azure || true && \
            time terraform apply -auto-approve ${DIR}/azure
       fi 

    export KUBECONFIG=${TF_VAR_data_dir}/kubeconfig
    _retry "❤ Trying to connect to cluster with kubectl" kubectl get cs
    _retry "❤ Ensure that the kube-system namespaces exists" kubectl get namespace kube-system
    _retry "❤ Ensure that ClusterRoles are available" kubectl get ClusterRole.v1.rbac.authorization.k8s.io
    _retry "❤ Ensure that ClusterRoleBindings are available" kubectl get ClusterRoleBinding.v1.rbac.authorization.k8s.io


elif [ "$CLOUD_CMD" = "azure-destroy" ] ; then
    cd ${DIR}/azure
    if [ "$BACKEND" = "s3" ]; then
        cp ../s3-backend.tf .
    terraform init \
              -backend-config "bucket=${AWS_BUCKET}" \
              -backend-config "key=azure-${TF_VAR_name}" \
              -backend-config "region=${AWS_DEFAULT_REGION}"
    time terraform destroy -force ${DIR}/azure || true

    elif [ "$BACKEND" = "file" ]; then
        cp ../file-backend.tf .
        terraform init \
                  -backend-config "path=/cncf/data/${TF_VAR_name}/terraform.tfstate"
    time terraform destroy -force ${DIR}/azure || true
    fi

# Begin OpenStack
elif [[ "$CLOUD_CMD" = "openstack-deploy" || \
        "$CLOUD_CMD" = "openstack-destroy" ]] ; then
    cd ${DIR}/openstack

    # initialize based on the config type
    if [ "$BACKEND" = "s3" ] ; then
        cp ../s3-backend.tf .
        terraform init \
            -backend-config "bucket=${AWS_BUCKET}" \
            -backend-config "key=openstack-${TF_VAR_name}" \
            -backend-config "region=${AWS_DEFAULT_REGION}"
    elif [ "$BACKEND" = "file" ] ; then
        cp ../file-backend.tf .
        terraform init -backend-config "path=/cncf/data/${TF_VAR_NAME}/terraform.tfstate"
    fi

    # deploy/destroy implementations
    if [ "$CLOUD_CMD" = "openstack-deploy" ] ; then
        terraform taint -module=kubeconfig null_resource.kubeconfig || true
        time terraform apply -auto-approve ${DIR}/openstack
    elif [ "$CLOUD_CMD" = "openstack-destroy" ] ; then
        time terraform destroy -force ${DIR}/openstack || true
        # Exit after destroying resources as further commands cause hang
        exit
    fi

    export KUBECONFIG=${TF_VAR_data_dir}/kubeconfig
    _retry "❤ Trying to connect to cluster with kubectl" kubectl get cs
    _retry "❤ Ensure that the kube-system namespaces exists" kubectl get namespace kube-system
    _retry "❤ Ensure that ClusterRoles are available" kubectl get ClusterRole.v1.rbac.authorization.k8s.io
    _retry "❤ Ensure that ClusterRoleBindings are available" kubectl get ClusterRoleBinding.v1.rbac.authorization.k8s.io

# End OpenStack

elif [ "$CLOUD_CMD" = "packet-deploy" ] ; then
    cd ${DIR}/packet
    if [ "$BACKEND" = "s3" ]; then
        cp ../s3-backend.tf .
    terraform init \
              -backend-config "bucket=${AWS_BUCKET}" \
              -backend-config "key=packet-${TF_VAR_name}" \
              -backend-config "region=${AWS_DEFAULT_REGION}"
    # ensure kubeconfig & resolv.conf is written to disk on infrastructure refresh
    terraform taint -module=kubeconfig null_resource.kubeconfig || true ${DIR}/packet
    time terraform apply -auto-approve ${DIR}/packet

    elif [ "$BACKEND" = "file" ]; then
        cp ../file-backend.tf .
        terraform init \
                  -backend-config "path=/cncf/data/${TF_VAR_name}/terraform.tfstate" 
        # ensure kubeconfig is written to disk on infrastructure refresh
        terraform taint -module=kubeconfig null_resource.kubeconfig || true ${DIR}/packet
        time terraform apply -auto-approve ${DIR}/packet
fi

    export KUBECONFIG=${TF_VAR_data_dir}/kubeconfig
    _retry "❤ Trying to connect to cluster with kubectl" kubectl get cs
    _retry "❤ Ensure that the kube-system namespaces exists" kubectl get namespace kube-system
    _retry "❤ Ensure that ClusterRoles are available" kubectl get ClusterRole.v1.rbac.authorization.k8s.io
    _retry "❤ Ensure that ClusterRoleBindings are available" kubectl get ClusterRoleBinding.v1.rbac.authorization.k8s.io

elif [ "$CLOUD_CMD" = "packet-destroy" ] ; then
     cd ${DIR}/packet
     if [ "$BACKEND" = "s3" ]; then
         cp ../s3-backend.tf .
    terraform init \
              -backend-config "bucket=${AWS_BUCKET}" \
              -backend-config "key=packet-${TF_VAR_name}" \
              -backend-config "region=${AWS_DEFAULT_REGION}"
    time terraform destroy -force ${DIR}/packet

elif [ "$BACKEND" = "file" ]; then
         cp ../file-backend.tf .
         terraform init \
                   -backend-config "path=/cncf/data/${TF_VAR_name}/terraform.tfstate"
         time terraform destroy -force ${DIR}/packet
fi

elif [ "$CLOUD_CMD" = "gce-deploy" ] ; then
    cd ${DIR}/gce
    if [ "$BACKEND" = "s3" ]; then
        cp ../s3-backend.tf .
    terraform init \
              -backend-config "bucket=${AWS_BUCKET}" \
              -backend-config "key=gce-${TF_VAR_name}" \
              -backend-config "region=${AWS_DEFAULT_REGION}"
    # ensure kubeconfig is written to disk on infrastructure refresh
    terraform taint -module=kubeconfig null_resource.kubeconfig || true ${DIR}/gce
    time terraform apply -target module.vpc.google_compute_subnetwork.cncf -auto-approve ${DIR}/gce
    time terraform apply -auto-approve ${DIR}/gce

elif [ "$BACKEND" = "file" ]; then
        cp ../file-backend.tf .
        terraform init \
                  -backend-config "path=/cncf/data/${TF_VAR_name}/terraform.tfstate"
        # ensure kubeconfig is written to disk on infrastructure refresh
        terraform taint -module=kubeconfig null_resource.kubeconfig || true ${DIR}/gce
        time terraform apply -target module.vpc.google_compute_subnetwork.cncf -auto-approve ${DIR}/gce
        time terraform apply -auto-approve ${DIR}/gce
    fi

    export KUBECONFIG=${TF_VAR_data_dir}/kubeconfig
    _retry "❤ Trying to connect to cluster with kubectl" kubectl get cs
    _retry "❤ Ensure that the kube-system namespaces exists" kubectl get namespace kube-system
    _retry "❤ Ensure that ClusterRoles are available" kubectl get ClusterRole.v1.rbac.authorization.k8s.io
    _retry "❤ Ensure that ClusterRoleBindings are available" kubectl get ClusterRoleBinding.v1.rbac.authorization.k8s.io

elif [ "$CLOUD_CMD" = "gce-destroy" ] ; then
    cd ${DIR}/gce
    if [ "$BACKEND" = "s3" ]; then
        cp ../s3-backend.tf .
    terraform init \
              -backend-config "bucket=${AWS_BUCKET}" \
              -backend-config "key=gce-${TF_VAR_name}" \
              -backend-config "region=${AWS_DEFAULT_REGION}"
    time terraform destroy -force ${DIR}/gce || true # Allow to Fail and clean up network on next step
    time terraform destroy -force -target module.vpc.google_compute_subnetwork.cncf ${DIR}/gce
    time terraform destroy -force -target module.vpc.google_compute_network.cncf ${DIR}/gce
elif [ "$BACKEND" = "file" ]; then
        cp ../file-backend.tf .
        terraform init \
                  -backend-config "path=/cncf/data/${TF_VAR_name}/terraform.tfstate"
        time terraform destroy -force ${DIR}/gce || true # Allow to Fail and clean up network on next step
        time terraform destroy -force -target module.vpc.google_compute_subnetwork.cncf ${DIR}/gce
        time terraform destroy -force -target module.vpc.google_compute_network.cncf ${DIR}/gce
fi

elif [ "$CLOUD_CMD" = "gke-deploy" ] ; then
cd ${DIR}/gke
if [ "$BACKEND" = "s3" ]; then
    cp ../s3-backend.tf .
    terraform init \
              -backend-config "bucket=${AWS_BUCKET}" \
              -backend-config "key=gke-${TF_VAR_name}" \
              -backend-config "region=${AWS_DEFAULT_REGION}"
    time terraform apply -target module.vpc -auto-approve ${DIR}/gke && \
    time terraform apply -auto-approve ${DIR}/gke
elif [ "$BACKEND" = "file" ]; then
    cp ../file-backend.tf .
    terraform init \
              -backend-config "path=/cncf/data/${TF_VAR_name}/terraform.tfstate"
    time terraform apply -target module.vpc -auto-approve ${DIR}/gke && \
    time terraform apply -auto-approve ${DIR}/gke
fi

    export KUBECONFIG=${TF_VAR_data_dir}/kubeconfig
    echo $GOOGLE_CREDENTIALS > ${TF_VAR_data_dir}/keyfile.json
    gcloud auth activate-service-account $GOOGLE_AUTH_EMAIL --key-file ${TF_VAR_data_dir}/keyfile.json --project $GOOGLE_PROJECT
    gcloud container clusters get-credentials $TF_VAR_name --zone $GOOGLE_ZONE --project $GOOGLE_PROJECT

    echo "❤ Polling for cluster life - this could take a minute or more"
    _retry "❤ Trying to connect to cluster with kubectl" kubectl cluster-info 
    kubectl cluster-info

elif [ "$CLOUD_CMD" = "gke-destroy" ] ; then
cd ${DIR}/gke
if [ "$BACKEND" = "s3" ]; then
    cp ../s3-backend.tf .
    terraform init \
              -backend-config "bucket=${AWS_BUCKET}" \
              -backend-config "key=gke-${TF_VAR_name}" \
              -backend-config "region=${AWS_DEFAULT_REGION}"

    time terraform destroy -force -target module.cluster.google_container_cluster.cncf ${DIR}/gke || true 
    echo "sleep" && sleep 10 && \
    time terraform destroy -force -target module.vpc.google_compute_network.cncf ${DIR}/gke || true 
    time terraform destroy -force ${DIR}/gke || true

elif [ "$BACKEND" = "file" ]; then
    cp ../file-backend.tf .
    terraform init \
              -backend-config "path=/cncf/data/${TF_VAR_name}/terraform.tfstate" 
time terraform destroy -force -target module.cluster.google_container_cluster.cncf ${DIR}/gke || true 
echo "sleep" && sleep 10 && \
time terraform destroy -force -target module.vpc.google_compute_network.cncf ${DIR}/gke || true 
time terraform destroy -force ${DIR}/gke || true
fi


elif [ "$CLOUD_CMD" = "ibmcloud-deploy" ] ; then
cd ${DIR}/ibm
if [ "$BACKEND" = "s3" ]; then
    cp ../s3-backend.tf .
    terraform init \
              -backend-config "bucket=${AWS_BUCKET}" \
              -backend-config "key=ibm-${TF_VAR_name}" \
              -backend-config "region=${AWS_DEFAULT_REGION}"
    # ensure kubeconfig is written to disk on infrastructure refresh
    terraform taint null_resource.kubeconfig || true
    time terraform apply -auto-approve ${DIR}/ibm
elif [ "$BACKEND" = "file" ]; then
    cp ../file-backend.tf .
    terraform init \
              -backend-config "path=/cncf/data/${TF_VAR_name}/terraform.tfstate"
    # ensure kubeconfig is written to disk on infrastructure refresh
    terraform taint null_resource.kubeconfig || true
    time terraform apply -auto-approve ${DIR}/ibm
fi

    export KUBECONFIG=${TF_VAR_data_dir}/kubeconfig
    echo "❤ Polling for cluster life - this could take a minute or more"
    _retry "❤ Trying to connect to cluster with kubectl" kubectl cluster-info
    kubectl cluster-info
    _retry "❤ Installing Helm" helm init
    kubectl rollout status -w deployment/tiller-deploy --namespace=kube-system

elif [ "$CLOUD_CMD" = "ibmcloud-destroy" ] ; then
cd ${DIR}/ibm
if [ "$BACKEND" = "s3" ]; then
    cp ../s3-backend.tf .
    terraform init \
              -backend-config "bucket=${AWS_BUCKET}" \
              -backend-config "key=ibm-${TF_VAR_name}" \
              -backend-config "region=${AWS_DEFAULT_REGION}"
    time terraform destroy -force ${DIR}/ibm

elif [ "$BACKEND" = "file" ]; then
    cp ../file-backend.tf .
    terraform init \
              -backend-config "path=/cncf/data/${TF_VAR_name}/terraform.tfstate" 
time terraform destroy -force ${DIR}/ibm
fi

# Begin vSphere
elif [[ "$CLOUD_CMD" = "vsphere-deploy" || \
        "$CLOUD_CMD" = "vsphere-destroy" ]] ; then

    cd ${DIR}/vsphere

    if [ -n "$VSPHERE_SERVER" ]; then
        export TF_VAR_vsphere_server=$VSPHERE_SERVER
    fi
    if [ -n "$VSPHERE_USER" ]; then
        export TF_VAR_vsphere_user=$VSPHERE_USER
    fi
    if [ -n "$VSPHERE_PASSWORD" ]; then
        export TF_VAR_vsphere_password=$VSPHERE_PASSWORD
    fi
    if [ -n "$VSPHERE_AWS_ACCESS_KEY_ID" ]; then
        export TF_VAR_vsphere_aws_access_key_id=$VSPHERE_AWS_ACCESS_KEY_ID
    fi
    if [ -n "$VSPHERE_AWS_SECRET_ACCESS_KEY" ]; then
        export TF_VAR_vsphere_aws_secret_access_key=$VSPHERE_AWS_SECRET_ACCESS_KEY
    fi
    if [ -n "$VSPHERE_AWS_REGION" ]; then
        export TF_VAR_vsphere_aws_region=$VSPHERE_AWS_REGION
    fi

    # initialize based on the config type
    if [ "$BACKEND" = "s3" ] ; then
        cp ../s3-backend.tf .
        terraform init \
            -backend-config "bucket=${AWS_BUCKET}" \
            -backend-config "key=vsphere-${TF_VAR_name}" \
            -backend-config "region=${AWS_DEFAULT_REGION}"
    elif [ "$BACKEND" = "file" ] ; then
        cp ../file-backend.tf .
        terraform init -backend-config "path=/cncf/data/${TF_VAR_name}/terraform.tfstate"
    fi

    # deploy/destroy implementations
    if [ "$CLOUD_CMD" = "vsphere-deploy" ] ; then
        terraform taint -module=kubeconfig null_resource.kubeconfig || true
        time terraform apply -auto-approve ${DIR}/vsphere
    elif [ "$CLOUD_CMD" = "vsphere-destroy" ] ; then
        time terraform destroy -force ${DIR}/vsphere || true
        # Exit after destroying resources as further commands cause hang
        exit
    fi

    export KUBECONFIG=${TF_VAR_data_dir}/kubeconfig
    _retry "❤ Trying to connect to cluster with kubectl" kubectl get cs
    _retry "❤ Ensure that the kube-system namespaces exists" kubectl get namespace kube-system
    _retry "❤ Ensure that ClusterRoles are available" kubectl get ClusterRole.v1.rbac.authorization.k8s.io
    _retry "❤ Ensure that ClusterRoleBindings are available" kubectl get ClusterRoleBinding.v1.rbac.authorization.k8s.io

    kubectl create -f ../rbac/
    _retry "❤ Ensure that worker node is ready" kubectl get nodes
    kubectl create -f ../addons/

fi
# End vSphere
 
