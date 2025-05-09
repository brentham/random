

packer {
  required_plugins {
    vsphere = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/vsphere"
    }
  }
}


##################################################################################
# LOCALS
##################################################################################

locals {
  buildtime = formatdate("YYYY-MM-DD hh:mm ZZZ", timestamp())
}

##################################################################################
# SOURCE
##################################################################################

source "vsphere-iso" "linux-ubuntu-server" {
  vcenter_server = var.vcenter_server
  username = var.vcenter_username
  password = var.vcenter_password
  datacenter = var.vcenter_datacenter
  datastore = var.vcenter_datastore
  host = var.vcenter_host
  cluster = var.vcenter_cluster
  folder = var.vcenter_folder
  insecure_connection = var.vcenter_insecure_connection
  tools_upgrade_policy = true
  remove_cdrom = true
  convert_to_template = true
  guest_os_type = var.vm_guest_os_type
  vm_version = var.vm_version
  notes = "Built by HashiCorp Packer on ${local.buildtime}."
  vm_name = var.vm_name
  firmware = var.vm_firmware
  CPUs = var.vm_cpu_sockets
  cpu_cores = var.vm_cpu_cores
  CPU_hot_plug = false
  RAM = var.vm_mem_size
  RAM_hot_plug = false
  cdrom_type = var.vm_cdrom_type
  disk_controller_type = var.vm_disk_controller_type
  storage {
    disk_size = var.vm_disk_size
    disk_controller_index = 0
    disk_thin_provisioned = var.thin_provision
    disk_eagerly_scrub = var.disk_eagerly_scrub
  }
  network_adapters {
    network = var.vcenter_network
    network_card = var.vm_network_card
  }
  # iso_url = var.iso_url
  // iso_paths = ["[${ var.vcenter_datastore }] /${ var.iso_path }/${ var.iso_file }"]
  # iso_checksum = "${var.iso_checksum_type}:${var.iso_checksum}"
  iso_paths            = [ "[SSD] ISO/ubuntu-iso/ubuntu-20.04.6-live-server-amd64.iso" ]
  iso_target_extension = "iso"
  http_directory = var.http_directory
  boot_order = "disk,cdrom"
  boot_wait = var.vm_boot_wait
  cd_files = [
        "./${var.http_directory}/meta-data",
        "./${var.http_directory}/user-data"]
  cd_label = "cidata"
  boot_command = [
    "<esc><esc><esc>",
    "<enter><wait>",
    "/casper/vmlinuz ",
    "initrd=/casper/initrd ",
    "autoinstall ",
    "boot<enter>"
  ]
  ip_wait_timeout = "20m"
  ssh_password = var.ssh_password
  ssh_username = var.ssh_username
  ssh_port = 22
  ssh_timeout = "30m"
  ssh_handshake_attempts = "100"
  shutdown_command = "echo '${var.ssh_password}' | sudo -S -E shutdown -P now"
  shutdown_timeout = "15m"
}

##################################################################################
# BUILD
##################################################################################

build {
  sources = [
    "source.vsphere-iso.linux-ubuntu-server"]
  provisioner "shell" {
    execute_command = "echo '${var.ssh_password}' | {{.Vars}} sudo -S -E bash '{{.Path}}'"
    environment_vars = [
      "BUILD_USERNAME=${var.ssh_username}",
    ]
    scripts = var.shell_scripts
    expect_disconnect = true
  }
 }
