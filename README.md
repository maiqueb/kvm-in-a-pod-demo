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

# How this works
In this demo we spawn two fedora VMs using multus to plug an extra
macvtap interface into the pod.

The multus network-attachment-definition uses macvtap cni plus a resource
exposed by the macvtap device plugin to provide a macvtap interface which will
be used by the VMs.

The overall flow happens as follows:
  - KubeVirt takes the resource in the network attachment definition and places
    it as a resource request in the pod definition.
  - before the pod is spawned, kubelet requests the resource to the macvtap
    device plugin.
  - the macvtap device plugin allocates a new macvtap interface, and grants the
    pod access to the corresponding /dev/tapX character device - via cgroups.
  - Multus obtains the macvtap resource allocated to the pod from kubelet - via
    the macvtap interface name - and passes it to macvtap CNI as `deviceID`
    attribute.
  - the macvtap cni makes this interface available in the pods namespace and
    performs further configuration on it.
  - KubeVirt generates the domxml libvirt will require to plug the character
    device into the VM as a virtio interface.
  - the virt-launcher process boots libvirt, whose domxml definition features
    the macvtap interface name, from which libvirt obtains the associated tap
    device, which is finally passed on to qemu.

# Acknowledgements
TODO

# Requirements
TODO
