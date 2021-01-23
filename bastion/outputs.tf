output "public_ipv4" {
  description = "publicly routeable ipv4 address"
  value       = digitalocean_floating_ip.bastion.ip_address
}

output "public_ipv6" {
  description = "publicly routeable ipv6 address"
  value       = digitalocean_droplet.bastion.ipv6_address
}

output "wireguard" {
  description = "internal wireguard subnet"
  value = {
    num_peers      = length(var.wireguard_peers)
    port           = var.wireguard_port
    protocol       = "udp"
    public_key     = var.wireguard_public_key
    v4_addr        = var.wireguard_ipv4_address
    v4_endpoint    = format("%s:%d", digitalocean_floating_ip.bastion.ip_address, var.wireguard_port)
    v4_subnet      = local.wg_v4_subnet
    v4_subnet_len  = var.wireguard_ipv4_subnet_len
    v6_addr        = var.wireguard_ipv6_address
    v6_endpoint    = format("[%s]:%d", digitalocean_droplet.bastion.ipv6_address, var.wireguard_port)
    v6_subnet      = local.wg_v6_subnet
    v6_subnet_len  = var.wireguard_ipv6_subnet_len
    example_config = <<EOF
[Interface]
ListenPort=${var.wireguard_port}
PrivateKey=CHANGE_ME
# CHANGEME: Dont forget to increment these IPs to match correct address for each client:
Address=${var.wireguard_ipv4_address}/32,${var.wireguard_ipv6_address}/128
[Peer]
PublicKey=${var.wireguard_public_key}
PresharedKey=CHANGEME
AllowedIPs=${var.wireguard_ipv4_address},${var.wireguard_ipv6_address},0.0.0.0/0,::/0
Endpoint=${digitalocean_floating_ip.bastion.ip_address}:${var.wireguard_port}
# PersistentKeepAlive=60
EOF
  }
}
