terraform {
  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

# Base image volume
resource "libvirt_volume" "ubuntu_base" {
  name   = "ubuntu-noble-base.qcow2"
  pool   = "default"
  target = {
    format = {
      type = "qcow2"
    }
  }

  create = {
    content = {
      url = "/home/soufian/Downloads/"
    }
  }
}

# Writable disk overlay
resource "libvirt_volume" "ubuntu_vm_disk" {
  name     = "ubuntu-vm-disk.qcow2"
  pool     = "default"
  target = {
    format = {
      type = "qcow2"
    }
  }
  capacity = 10737418240 # 10 GiB

  backing_store = {
    path   = libvirt_volume.ubuntu_base.path
    format = {
      type = "qcow2"
    }
  }
}

# Cloud-init ISO (meta_data is required)
resource "libvirt_cloudinit_disk" "ubuntu_init" {
  name      = "ubuntu-init.iso"
  user_data = <<-EOF
#cloud-config
hostname: ubuntu-vm
manage_etc_hosts: true
users:
  - name: ubuntu
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    passwd: $6$rounds=4096$3XxKvQdQzXs$lV9QqgKQgFvgkWRtPQQGqKFhVckC3lqQwQxQxQxQx
runcmd:
  - apt-get update
  - apt-get install -y qemu-guest-agent
  - systemctl enable qemu-guest-agent --now
EOF

  meta_data = <<-EOF
instance-id: ubuntu-vm
local-hostname: ubuntu-vm
EOF

  network_config = <<-EOF
version: 2
ethernets:
  eth0:
    dhcp4: true
EOF
}

# Cloud-init disk volume (attachable ISO)
resource "libvirt_volume" "ubuntu_init_volume" {
  name = "ubuntu-init.iso"
  pool = "default"

  create = {
    content = {
      url = libvirt_cloudinit_disk.ubuntu_init.path
    }
  }

  
}

# Virtual machine
resource "libvirt_domain" "ubuntu_vm" {
  name   = "ubuntu-vm"
  memory = 2097152 # 2 GiB in KiB
  vcpu   = 2
  type   = "kvm"

  os = {
    type         = "hvm"
    type_arch    = "x86_64"
    type_machine = "q35"
    boot_devices = [
    { dev = "hd" },      # Boot from hard disk first
    { dev = "network" }  # Then try network boot
  ]  # This is actually correct per doc
  }

  cpu = {
    mode = "host-passthrough"
  }

  devices = {
    disks = [
      {
        source = {
          volume = {
            pool   = libvirt_volume.ubuntu_vm_disk.pool
            volume = libvirt_volume.ubuntu_vm_disk.name
          }
        }
        target = {
          dev = "vda"
          bus = "virtio"
        }
      },
      {
        device = "cdrom"
        source = {
          volume = {
            pool   = libvirt_volume.ubuntu_init_volume.pool
            volume = libvirt_volume.ubuntu_init_volume.name
          }
        }
        target = {
          dev = "sdb"
          bus = "sata"
        }
      }
    ]
    
    interfaces = [
      {
        model = {
          type = "virtio"
        }
        source = {
          network = {
            network = "default"
          }
        }
        wait_for_ip = {
          timeout = 300
          source  = "lease"
        }
      }
    ]
    
  }
}

data "libvirt_domain_interface_addresses" "ubuntu_vm" {
  domain = libvirt_domain.ubuntu_vm.name
  source = "lease"

  depends_on = [libvirt_domain.ubuntu_vm]
}

output "vm_ip" {
  value = length(data.libvirt_domain_interface_addresses.ubuntu_vm.interfaces) > 0 ? try(data.libvirt_domain_interface_addresses.ubuntu_vm.interfaces[0].addrs[0].addr, "No IP assigned yet") : "No interfaces found"
}

output "vm_all_ips" {
  value = flatten([
    for iface in data.libvirt_domain_interface_addresses.ubuntu_vm.interfaces : [
      for addr in iface.addrs : addr.addr
    ]
  ])
}