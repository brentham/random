# Packer Ubuntu 20.04 Image in VMware
Create Ubuntu 20.04 images in VMware

## To generate a hashed password for identity in user-data
Using mkpasswd
On Ubuntu you need to install whois package to get mkpasswd utility.

```sh
apt-get install whois
mkpasswd -m sha-512 --rounds=4096
```

If PASSWORD is missing then it is asked interactively.

Example:
```sh
Password:
$6$KU2P9m78xF3n$noEN/CV.0R4qMLdDh/TloUplmJ0DLnqi6/cP7hHgfwUu.D0hMaD2sAfxDT3eHP5BQ3HdgDkKuIk8zBh0mDLzO1
```

## Running packer build with hcl
Both hcl and json work
```sh
packer build -force -on-error=ask -var-file variables.pkrvars100GBdisk.hcl -var-file vsphere.pkrvars.hcl ubuntu-20.04.pkr.hcl
```

## Run packer build with json

```sh
packer build -force -on-error=ask -var-file variables-100GBdisk.json -var-file variables-secrets.json ubuntu-20.04.json
```

## Troubleshooting
- If packer gets stuck on `Waiting for IP` you may want to check your DHCP server. I'm using a home router and it had too many leases from running packer many times. I had to flush inactive DHCP clients, or reboot the router which is faster.

## Credits
https://efkan-isazade.com/p/automating-ubuntu-20.04-live-server-template-generation-with-packer-vsphere-iso-build./).