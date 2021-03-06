# Kvm-in-a-pod-demo
This demo showcases the use of a macvtap network backend for VMs using
kubevirt.

In this repo you'll find:
  - [start cluster script](start_cluster.sh)
  - [prepare nodes](prepare_node.sh)
  - [manifests](two_macvtap_fedora_vms.yaml)

We encourage prospective users to try out the demo, and use the provided
[manifests](two_macvtap_fedora_vms.yaml) as reference for more advanced
use cases.

# Requirements
  - kubectl: Please follow their installation guide, located
    [here](https://kubernetes.io/docs/tasks/tools/install-kubectl/).
  - virtctl: Please follow their installation guide, located
    [here](https://kubevirt.io/user-guide/docs/latest/administration/intro.html#client-side-virtctl-deployment).
  - [docker](https://docs.docker.com/install/) / [podman](https://podman.io/getting-started/installation)

# Installation
To be able to run the demo, you'll need to clone the following repos:
  - [kubevirt](https://github.com/kubevirt/kubevirt/):
    `git clone https://github.com/maiqueb/kubevirt/ -branch add_macvtap_binding_mech`
  - [macvtap-cni](https://github.com/maiqueb/macvtap-cni):
    `git clone https://github.com/maiqueb/macvtap-cni`
  - [macvtap-device-plugin](https://github.com/jcaamano/macvtap-device-plugin/):
    `git clone https://github.com/jcaamano/macvtap-device-plugin/`

# Usage
Once you've cloned the repositories described in [installation](#installation),
you can run the following scripts:

```bash
# start a kubernetes cluster w/ kubevirt / multus / macvtap device plugin
# already configured.
# It defaults to 2 nodes, and the k8s-multus-1.13.3 provider.
KUBEVIRT_REPO=<kubevirt_repo_location> \
    MACVTAP_PLUGIN_REPO=<macvtap_device_plugin_repo_location> \
    ./start_cluster.sh
```

Once your k8s cluster is started, you can execute the following script:
```bash
# Deploy the CNI plugin in the cluster nodes
# It defaults to the k8s-multus-1.13.3 provider.
KUBEVIRT_REPO=<kubevirt_repo_location> ./prepare_node.sh
```

Once the cluster is deployed, and the macvtap CNI plugin is installed in the
cluster nodes, the example scenario can be provisioned. That is done via
kubectl:

```bash
# export the k8s configuration
export KUBECONFIG=$(<kubevirt_repo_location>/cluster-up/kubeconfig.sh)

# run the scenario
kubectl create -f two_macvtap_fedora_vms.yaml
```

Afterwards, you'll have the virt-launcher pods and the vmi objects in the
default namespace:

```bash
# list all pods in the default namespace
kubectl get pods
NAME                                  READY   STATUS    RESTARTS   AGE
device-plugin-network-macvtap-44lbw   1/1     Running   0          3h8m
device-plugin-network-macvtap-9pglq   1/1     Running   0          3h8m
local-volume-provisioner-88sh9        1/1     Running   0          3h14m
local-volume-provisioner-vkcr4        1/1     Running   0          3h14m
virt-launcher-vm1-5jx2p               2/2     Running   0          14s
virt-launcher-vm2-x2hm4               2/2     Running   0          14s

# list all vmi objects in the default namespace
kubectl get vmis
NAME   AGE   PHASE     IP            NODENAME
vm1    33s   Running   10.244.1.18   node02
vm2    33s   Running   10.244.1.17   node02

# connect to a vm via virtctl
virtctl console --kubeconfig=<path to kubeconfig> vm1
```

# Configuration cookbook

## Configure the device plugin
The following yaml is an example of how to configure the device plugin to
expose a macvtap resource named `eth0`, whose lower device is `eth0`.
The macvtap interface will be configured in mode `bridge`, and kubelet will
schedule at most `50` macvtap interfaces on top of that lower device.

```yaml
kind: ConfigMap
apiVersion: v1
metadata:
  name: macvtapdp-config
data:
  DP_MACVTAP_CONF: >-
    [ {
        "name" : "eth0",
        "master" : "eth0",
        "mode": "bridge",
        "capacity" : 50
     } ]
```

## Request a macvtap resource from the device plugin
The network-attachment-definition defined in this demo's
[scenario](two_macvtap_fedora_vms.yaml) - copied below, for your convinience -
can be used to request a resource from the device plugin when a VMI is
scheduled.

Notice the requested resouce in the `annotations` section; there, a request
of type `macvtap.network.kubevirt.io` is requested, whose name is `eth0`. This
directly refers the resource exposed in the
[previous-section](#configure-the-device-plugin).

The `config` part of the spec has information about the required CNI plugin -
macvtap - and also allows for the configuration of the network's MTU.

```yaml
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: macvtap
  annotations:
    k8s.v1.cni.cncf.io/resourceName: macvtap.network.kubevirt.io/eth0
spec:
  config: '{
      "cniVersion": "0.3.1",
      "type": "macvtap",
      "mtu": 1500
    }'
```

# How this works
In this demo we spawn two fedora VMs using multus to plug an extra
macvtap interface into the pod.

The multus network-attachment-definition uses macvtap cni plus a resource
exposed by the macvtap device plugin to provide a macvtap interface which will
be used by the VMs.

Refer to the image below to better understand the flow.

![flow_diagram](/images/kvm-in-pod-flow-diagram.png)

The overall flow happens as follows:
  - KubeVirt takes the resource in the network attachment definition and places
    it as a resource request in the pod definition.
  - before the pod is spawned, kubelet requests the resource to the macvtap
    device plugin.
  - the macvtap device plugin allocates a new macvtap interface, and returns
    its name to kubelet, which grants the pod access to the corresponding
    /dev/tapX character device - via cgroups.
  - Multus CNI is then requested to add the interface; it learns the interface
    name from kubelet, and calls the macvtap CNI plugin, adding the `deviceID`
    parameter - in which it'll pass the name of the macvtap interface created
    by the device plugin.
  - the macvtap cni makes this interface available in the pod's namespace and
    performs further configuration on it.
  - KubeVirt generates the domxml libvirt will require to plug the character
    device into the VM as a virtio interface.
  - the virt-launcher process boots libvirt, whose domxml definition features
    the macvtap interface name, from which libvirt obtains the associated tap
    device, which is finally passed on to qemu.

## Example
[![asciicast](https://asciinema.org/a/qBNOF3twp5MO97CKTAHDnZtJq.png)](https://asciinema.org/a/qBNOF3twp5MO97CKTAHDnZtJq)

# Acknowledgements
TODO

