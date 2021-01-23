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
# generate the wireguard config manually (before logging verbosely!!)
umask 077
echo '${data.template_file.wireguard_config.rendered}' > ~/wg0.conf
echo '${data.template_file.wireguard_hook_post_up.rendered}' > ~/wg0.PostUp.sh
echo '${data.template_file.wireguard_hook_post_down.rendered}' > ~/wg0.PostDown.sh

# enable verbose output (after secrets have been installed)
set -euo verbose

# Update packages and install dependencies.
apt-get update -qqy \
&& apt-get upgrade -qqy \
&& apt-get -qy install \
  wireguard iptables

# install digitalocean metrics
curl -sSLo - https://repos.insights.digitalocean.com/install.sh | bash -

# enable ipv4 forwarding for vpn peers to get to internet.
echo 'net.ipv4.ip_forward=1' >/etc/sysctl.d/99-custom.conf \
&& sysctl -p /etc/sysctl.d/99-custom.conf

# install the config and enable the service.
mv ~/wg0.* /etc/wireguard/ \
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


data "template_file" "wireguard_hook_post_up" {
  template = <<EOF
iptables -A FORWARD -i $1 -j ACCEPT
iptables -A FORWARD -o $1 -j ACCEPT
iptables -t nat -A POSTROUTING -o $2 -j MASQUERADE
EOF
}

data "template_file" "wireguard_hook_post_down" {
  template = <<EOF
iptables -D FORWARD -i $1 -j ACCEPT
iptables -D FORWARD -o $1 -j ACCEPT
iptables -t nat -D POSTROUTING -o $2 -j MASQUERADE
EOF
}

data "template_file" "wireguard_config" {
  template = <<EOF
[Interface]
Address     = ${local.wg_v4_subnet}, ${local.wg_v6_subnet}
ListenPort  = ${var.wireguard_port}
PrivateKey  = ${var.wireguard_private_key}
#PublicKey  = ${var.wireguard_public_key}
PostUp      = bash -xeu /etc/wireguard/wg0.PostUp.sh %i eth0
PostDown    = bash -xeu /etc/wireguard/wg0.PostDown.sh %i eth0

${join("\n", data.template_file.wireguard_peers.*.rendered)}
EOF
}

data "template_file" "wireguard_peers" {
  count    = length(var.wireguard_peers)
  template = <<EOF
[Peer]
PublicKey    = ${lookup(element(var.wireguard_peers, count.index), "public_key")}
PresharedKey = ${lookup(element(var.wireguard_peers, count.index), "preshared_key")}
AllowedIPs   = ${join(",", lookup(element(var.wireguard_peers, count.index), "allowed_ips"))}
EOF
}


# ---- <alternative-way> -------------------------------------------------------------
# # this is another way to provision the host. the disadvantage is that the ssh
# # port must be open. our solution doesn't require that.
# resource "null_resource" "bastion_provisioner" {
#   # Changes to any instance of the cluster requires re-provisioning
#   triggers = {
#     droplet_ids_changed        = sha1(join(",", digitalocean_droplet.bastion.*.id))
#     wireguard_template_changed = sha1(data.template_file.wireguard_config.rendered)
#   }
#
#   # Bootstrap script can run on any instance of the cluster
#   # So we just choose the first in this case
#   connection {
#     type        = "ssh"
#     user        = "root"
#     private_key = file("~/.ssh/digitalocean-terraform")
#     agent       = false
#     host        = element(digitalocean_droplet.bastion.*.ipv4_address, 0)
#   }
#
#   provisioner "remote-exec" {
#     # Bootstrap script called with private_ip of each node in the cluster
#     inline = [
#     ]
#   }
# }
# ------------------------------------------------------------ </alternative-way> ----
