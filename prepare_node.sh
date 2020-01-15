#!/bin/bash

# constants
GO_PKG="go1.13.4.linux-amd64"

# overrideable stuff
KUBEVIRT_REPO_ROOT="${KUBEVIRT_REPO:-$HOME/kubernetes/kubevirt}"
PROVIDER="${PROVIDER:-k8s-multus-1.13.3}"

NODES=$(
    kubectl get nodes --template='{{range .items}}{{.metadata.name}} {{end}}'
)

export KUBEVIRT_PROVIDER=$PROVIDER
export KUBEVIRT_NUM_SECONDARY_NICS=1
export KUBECONFIG=$($KUBEVIRT_REPO_ROOT/cluster-up/kubeconfig.sh)


function install_dependencies {
    "$KUBEVIRT_REPO_ROOT"/cluster-up/ssh.sh $1 "
        sudo yum install -y git wget
    "
}

function install_golang {
    "$KUBEVIRT_REPO_ROOT"/cluster-up/ssh.sh $1 "
        wget https://dl.google.com/go/$GO_PKG.tar.gz && \
	    sudo tar -C /usr/local -xzf $GO_PKG.tar.gz && \
            echo \"export PATH=$PATH:/usr/local/go/bin\" >> ~/.bashrc
    "
}

function install_macvtap_cni {
    "$KUBEVIRT_REPO_ROOT"/cluster-up/ssh.sh $1 "
        git clone https://github.com/maiqueb/macvtap-cni && \
	        cd macvtap-cni && \
	        go build && \
                sudo mv macvtap-cni /opt/cni/bin/macvtap && \
		sudo chown root:root /opt/cni/bin/macvtap
    "
}

for node_name in $NODES; do
    echo "Will install macvtap CNI for $node_name."
    install_dependencies $node_name
    install_golang $node_name
    install_macvtap_cni $node_name
    echo "Installed macvtap cni for $node_name."
done

echo "Finished installing macvtap CNI plugin across cluster."

