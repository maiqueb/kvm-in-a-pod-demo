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

# Usage
TODO

# Installation
TODO

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
