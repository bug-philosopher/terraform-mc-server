# MC Server

terraform {
  required_version = ">= 0.14"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.80.0"
    }
  }
}


# Variables

variable "proxmox_endpoint" {
  type        = string
  description = "Proxmox API endpoint"
}

variable "proxmox_api_token_id" {
  type        = string
  description = "Proxmox API token ID"
  sensitive   = true
}

variable "proxmox_api_token_secret" {
  type        = string
  description = "Proxmox API token secret"
  sensitive   = true
}

variable "minecraft_count" {
  type        = number
  description = "How many Minecraft VMs to create"
  default     = 1
}

# Base IP for Minecraft VMs.
# Example: 192.168.0.50 -> first VM 192.168.0.50, second 51, etc.
variable "minecraft_base_ip" {
  type        = string
  description = "Base IPv4 address for the first minecraft VM"
  default     = "192.168.0.50"
}

variable "minecraft_gateway" {
  type        = string
  description = "IPv4 gateway for the minecraft VMs"
  default     = "192.168.0.1"
}

variable "minecraft_cidr_prefix" {
  type        = number
  description = "CIDR prefix length"
  default     = 24
}

variable "minecraft_jar_url" {
  type        = string
  description = "URL for the Minecraft server jar"
  # Server jar file download
  default     = "https://fill-data.papermc.io/v1/objects/d5f47f6393aa647759f101f02231fa8200e5bccd36081a3ee8b6a5fd96739057/paper-1.21.10-115.jar"
}

variable "proxmox_node_name" {
  type        = string
  description = "Proxmox node to host these VMs"
  default     = "celestra2"
}

variable "proxmox_template_vm_id" {
  type        = number
  description = "VM ID of the Ubuntu cloud-init template"
  default     = 9005
}

variable "proxmox_disk_datastore" {
  type        = string
  description = "Datastore ID for VM disks and cloud init drive (for example local-lvm)"
  default     = "local-lvm"
}

# Storage that has snippets enabled
variable "proxmox_snippets_datastore" {
  type        = string
  description = "Datastore ID with snippets content enabled (for example local)"
  default     = "local"
}

variable "minecraft_vm_cores" {
  type        = number
  description = "CPU cores per VM"
  default     = 2
}

variable "minecraft_vm_memory_mb" {
  type        = number
  description = "RAM per VM (MB)"
  default     = 4096
}

variable "ssh_username" {
  type        = string
  description = "Cloud init SSH user name"
  default     = "ubuntu"
}

variable "ssh_public_key_path" {
  type        = string
  description = "Path to your SSH pub key"
  default     = "~/.ssh/id_ed25519.pub"
}

# Locals

locals {
  # Convert base IP string into list [a, b, c, d]
  base_ip_octets = split(".", var.minecraft_base_ip)

  # Convert the last octet to number and add count.index
  ip_for_index = [
    for i in range(var.minecraft_count) :
    format(
      "%s.%s.%s.%d",
      local.base_ip_octets[0],
      local.base_ip_octets[1],
      local.base_ip_octets[2],
      tonumber(local.base_ip_octets[3]) + i
    )
  ]
}


# Provider

provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = "${var.proxmox_api_token_id}=${var.proxmox_api_token_secret}"
  insecure  = true

  ssh {
    username    = "root"
    agent       = true
    # To not use agent comment agent out and use private_key:
    # private_key = file("~/.ssh/id_ed25519")
}
}


# Cloud init snippet file

resource "proxmox_virtual_environment_file" "minecraft_cloud_init" {
  content_type = "snippets"
  datastore_id = var.proxmox_snippets_datastore
  node_name    = var.proxmox_node_name

  source_raw {
    file_name = "minecraft-cloud-init.yaml"
    data      = <<EOF
#cloud-config
package_update: true
packages:
  - openjdk-17-jre-headless
  - ufw

write_files:
  - path: /etc/systemd/system/minecraft.service
    permissions: "0644"
    owner: root:root
    content: |
      [Unit]
      Description=Minecraft Server
      After=network.target

      [Service]
      WorkingDirectory=/opt/minecraft
      User=minecraft
      Group=minecraft
      Restart=on-failure
      ExecStart=/usr/bin/java -Xms2G -Xmx4G -jar /opt/minecraft/server.jar nogui

      [Install]
      WantedBy=multi-user.target

runcmd:
  # Create user and directory
  - useradd -r -m -d /opt/minecraft minecraft || true
  - mkdir -p /opt/minecraft
  - chown -R minecraft:minecraft /opt/minecraft

  # Download server jar
  - sudo -u minecraft wget -O /opt/minecraft/server.jar ${var.minecraft_jar_url}

  # Run once to generate eula.txt
  - sudo -u minecraft java -Xmx1024M -Xms1024M -jar /opt/minecraft/server.jar nogui || true

  # Accept EULA
  - sed -i 's/eula=false/eula=true/' /opt/minecraft/eula.txt || echo 'eula=true' > /opt/minecraft/eula.txt

  # Firewall rules
  - ufw allow 25565/tcp || true
  - ufw --force enable || true

  # Enable and start Minecraft service
  - systemctl daemon-reload
  - systemctl enable minecraft
  - systemctl start minecraft
EOF
  }
}

# Main VM resource for Minecraft servers

resource "proxmox_virtual_environment_vm" "minecraft" {
  count       = var.minecraft_count
  name        = "mc-${count.index + 1}"
  description = "Terraform created Minecraft server ${count.index + 1}"
  node_name   = var.proxmox_node_name

  on_boot = true
  started = true

  tags = ["minecraft", "terraform"]

  agent {
    enabled = true
  }

  # Clone from cloud init template
  clone {
    node_name    = var.proxmox_node_name
    vm_id        = var.proxmox_template_vm_id
    full         = true
    datastore_id = var.proxmox_disk_datastore
  }

  cpu {
    cores = var.minecraft_vm_cores
  }

  memory {
    dedicated = var.minecraft_vm_memory_mb
  }

  network_device {
    bridge  = "vmbr0"   # default network bridge
    model   = "virtio"
    enabled = true
  }

  # Disk size override
  disk {
    datastore_id = var.proxmox_disk_datastore
    interface    = "scsi0"
    size         = 20
  }

  initialization {
    datastore_id = var.proxmox_disk_datastore

    ip_config {
      ipv4 {
        address = "${local.ip_for_index[count.index]}/${var.minecraft_cidr_prefix}"
        gateway = var.minecraft_gateway
      }
    }

    dns {
      servers = [var.minecraft_gateway, "192.168.0.1"]
    }

    user_account {
      username = var.ssh_username
      keys     = [file(var.ssh_public_key_path)]
    }

    # Point this VM at the cloud init snippet file
    user_data_file_id = proxmox_virtual_environment_file.minecraft_cloud_init.id
  }
}


# Outputs

output "minecraft_vm_ips" {
  description = "IPv4 addresses of all Minecraft VMs"
  value       = [for vm in proxmox_virtual_environment_vm.minecraft : vm.initialization[0].ip_config[0].ipv4[0].address]
}
