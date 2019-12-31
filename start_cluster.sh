#!/bin/bash
set -e

# constants
MACVTAP_DEV_PLUGIN="device-plugin-network-macvtap"

# overrideable stuff
KUBEVIRT_REPO_ROOT="${KUBEVIRT_REPO:-$HOME/kubernetes/kubevirt}"
NUM_NODES="${NODE_NUMBER:-2}"
PROVIDER="${PROVIDER:-k8s-multus-1.13.3}"
MACVTAP_DEVICE_PLUGIN_ROOT="${MACVTAP_PLUGIN_REPO:-$HOME/kubernetes/kubernetes-device-plugins/}"

export GOPATH=~/go/
export KUBEVIRT_PROVIDER=$PROVIDER
export KUBEVIRT_NUM_NODES=$NUM_NODES
export KUBEVIRT_NUM_SECONDARY_NICS=1
export KUBECONFIG=$($KUBEVIRT_REPO_ROOT/cluster-up/kubeconfig.sh)

function launch_cluster {
    cluster_containers=$(docker ps -q -f name="^$PROVIDER*")
    if [ -z "$cluster_containers" ]; then
        echo "K8s cluster not started. Booting it up w/ provider: $PROVIDER"
        cd $KUBEVIRT_REPO_ROOT
        make cluster-up && make cluster-sync
    else
	echo "K8s cluster already started w/ provider $PROVIDER"
    fi
}

function build_macvtap_device_plugin {
    cd $MACVTAP_DEVICE_PLUGIN_ROOT
    REGISTRY="$(get_registry)" make docker-build-network-macvtap
    REGISTRY="$(get_registry)" make docker-push-network-macvtap
}

function get_registry {
    host_port=$(
        docker inspect \
		--format='{{(index (index .NetworkSettings.Ports "5000/tcp") 0).HostPort}}' \
		"$PROVIDER-dnsmasq"
	)
    echo "localhost:$host_port/kubevirt"
}

function install_macvtap_device_plugin {
    is_macvtap_dev_plugin_installed=$(
        docker images -q $REGISTRY/$MACVTAP_DEV_PLUGIN
    )
    if [ -z $is_macvtap_dev_plugin_installed ]; then
        build_macvtap_device_plugin
    fi
    kubectl create configmap \
	    device-plugin-network-macvtap --from-literal=masters="eth0"
    kubectl apply -f \
	    https://raw.githubusercontent.com/jcaamano/kubernetes-device-plugins/master/manifests/macvtap-ds.yml
}

echo "Starting k8s + kubevirt cluster ..."
launch_cluster
echo "Installing macvtap device plugin ..."
install_macvtap_device_plugin
echo "Finished installing macvtap device plugin ."

