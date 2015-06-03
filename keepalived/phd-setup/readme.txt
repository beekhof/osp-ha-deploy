Assumptions:

1. We have a basic rhel7-base image. It is just a cloud image where we have manually injected a root ssh key, and allow direct root login (so the account is not locked). About the rest of the parameters:

  - NIC: default NAT
  - Disk: 60 GB, qcow2, virtio
  - CPU: 1
  - RAM: 4 GB

2. About SSH keys, it is important that the base image includes SSH keys in /root/.ssh/authorized_keys for:

  - The system running phd
  - The hypervisor that will run the VM

