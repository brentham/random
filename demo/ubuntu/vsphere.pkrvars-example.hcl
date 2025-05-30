##################################################################################
# VARIABLES
##################################################################################

# Credentials

vcenter_username                = "administrator@vsphere.home"
vcenter_password                = "superSecretPassword"

# vSphere Objects

vcenter_insecure_connection     = true
vcenter_server                  = "192.168.110.110"
vcenter_datacenter              = "Datacenter"
vcenter_cluster                 = "cluster-01"
vcenter_host                    = "192.168.110.111"
vcenter_datastore               = "Datastore2_NonSSD"
vcenter_network                 = "VM Network"
vcenter_folder                  = "Templates"

# ISO Objects
iso_path                        = "[Datastore2_NonSSD] /packer_cache/ubuntu-20.04.3-live-server-amd64.iso"
