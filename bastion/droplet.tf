module "wg0" {
  source          = "../wireguard-conf"
  hostname        = var.hostname
  domain          = var.domain
  private_key     = var.wireguard_private_key
  public_key      = var.wireguard_public_key
  port            = var.wireguard_port
  ipv4_address    = var.wireguard_ipv4_address
  ipv6_address    = var.wireguard_ipv6_address
  ipv4_subnet_len = var.wireguard_ipv4_subnet_len
  ipv6_subnet_len = var.wireguard_ipv6_subnet_len
  peers           = var.wireguard_peers
}

resource "digitalocean_droplet" "bastion" {
  image              = var.digitalocean_image_name
  name               = var.hostname
  region             = var.digitalocean_region
  size               = var.digitalocean_droplet_size
  tags               = concat(var.tags, list(var.digitalocean_region, var.digitalocean_image_name, "monitored", "no-backups", "ipv6-enabled", "private-networking", "terraform-managed"))
  ipv6               = true
  monitoring         = true
  backups            = false
  private_networking = true
  ssh_keys           = var.ssh_keys
  user_data          = <<EOF
#!/bin/bash
set -eu; umask 077; echo '${module.wg0.rendered}' > ~/wg0.conf

# Update packages and install dependencies.
apt-get update -qqy && apt-get upgrade -qqy \
&& apt-get -qy install wireguard iptables

# install digitalocean metrics
curl -sSLo - https://repos.insights.digitalocean.com/install.sh | bash -

# enable ipv4 forwarding for vpn peers to get to internet.
echo 'net.ipv4.ip_forward=1' >/etc/sysctl.d/99-custom.conf \
&& sysctl -p /etc/sysctl.d/99-custom.conf

# install the config and enable the service.
mv ~/wg0.conf /etc/wireguard/ \
&& systemctl enable --now wg-quick@wg0.service

# give it a restart, just for good measure...
sleep 2 && systemctl restart wg-quick@wg0.service

# output conf information once at the end.
wg
EOF
}

resource "digitalocean_floating_ip" "bastion" {
  droplet_id = digitalocean_droplet.bastion.id
  region     = digitalocean_droplet.bastion.region
}


