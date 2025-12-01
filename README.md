# Automatic Minecraft Server deployment using Terraform in Proxmox

Automatically deploy Minecraft Java Edition servers using Proxmox, Terraform, cloud init, and a fully automated VM template workflow.  
Current a work in progress project
<p align="center">
  <img alt="Terraform" src="https://img.shields.io/badge/Terraform-AE3BFF?logo=terraform&logoColor=white&style=for-the-badge" />
  <img alt="Proxmox" src="https://img.shields.io/badge/Proxmox-E57000?logo=proxmox&logoColor=white&style=for-the-badge" />
  <img alt="Cloud Init" src="https://img.shields.io/badge/Cloud%20Init-7834FF?logo=cloudflare&logoColor=white&style=for-the-badge" />
  <img alt="Minecraft" src="https://img.shields.io/badge/Minecraft-3C8527?logo=minecraft&logoColor=white&style=for-the-badge" />
  <img alt="Linux" src="https://img.shields.io/badge/Linux-000000?logo=linux&logoColor=white&style=for-the-badge" />
</p>

---

## Current Setup:

- Using Ubuntu VM template with cloud init in Proxmox
- Terraform config that cloans templates
- Automatic install of Java
- Automatic download of latest PaperMC server jar
- Automatic systemd service creation for MC
- Automatic firewall configuration
- Automatic static IP assignment per server
- Automatic SSH Key install

---

The goal of my first terraform project was to automatically deploy Minecraft Java servers using Proxmox, Terraform and cloud init.  
Create a hands free server setup that is highly repeatable, and potentially could be connected to n8n instance for completely automated server creation process

# Problems I ran into so far

- Cloud init's weird behavior in Proxmox
  > Cloud init works a bit differently in Proxmox compared to cloud providers. To setup a good template, cloud init packages have to be installed,
  a cloud init drive attached, and the guest agent installed. Even 1 missing step ment having to recreate the template
- SSH key auth
  > Terraform can't upload clould init snippets unless it can SSH into the Proxmox node. So having to setup SSH alongside using the API
- Systemd service creation process
  > Nested heredocs inside cloud init need very careful formatting, ended up moving the entire clould init YAML into a snippet file.

  ---

# Things learned

- Basics of Terraform & Cloud init + Proxmox setup
- How Proxmox handles cloud init differently from other environments
- How the BPG Terraform provider uploads files through SSH
- Just how important a correctly built cloud init template is
- How to automatically configure systemd services through cloud init
- How to structure a Terraform project that provisions cloud ready VMs
- How to create reproducible builds of servers
- How to manage static IP allocation through Terraform templates
- How to use Terraform state management to replace or rebuild machines

  
