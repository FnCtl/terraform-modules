/**
 * # Wireguard Config
 * 
 * ## Obtaining Wireguard Key(s)
 * - **NOTE** _always_ restrict file permissions with `umask 077` before starting..
 * - PrivateKey can be obtained with `wg genkey`.
 * - PresharedKey can be obtained with `wg genpsk`.
 * - PublicKey can be obtained with `cat <private-key> | wg pubkey`.
 *
 * ## Example Usage
 *
 * ### Step 1: create a `bastion.tf`
 * _Something roughly like this should work..._
 *
 * ```hcl
 * variable "wg_key" {}
 * variable "wg_pub" {}
 *
 * module "wg0" {
 *   source       = "./wireguard-config"
 *   hostname     = "bastion"
 *   domain       = "example.com"
 *   private_key  = var.wg_key
 *   public_key   = var.wg_pub
 *   ipv4_address = "10.42.0.1"
 *   peers        = jsondecode(file("./bastion.peers.json"))
 * }
 *
 * output "config_file" {
 *   description = "outputs wireguard config"
 *   value       = module.wg0.rendered
 * }
 * ```
 *
 * ### Step 2: create a `bastion.peers.json`
 * in a json file, named like in `bastion.tf` above, configure your wireguard
 * keys (as described above) **individually** for each host you'd like to
 * connect:
 *
 * ```json
 * [
 *     {
 *         "preshared_key": "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX=",
 *         "public_key": "YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY=",
 *         "allowed_ips": [
 *             "10.42.0.2"
 *         ]
 *     }
 * ]
 * ```
 *
 * ### Step 3: update your _"tfvars"_
 * Add 2 variables to your `terraform.tfvars` *(or how ever you do it in your project ...)*:
 *  - `wg_key`: the `PrivateKey=` portion of the wireguard config (obtainable by `wg genkey`).
 *  - `wg_pub`: the `PublicKey=` portion of the wireguard config (obtainable by `wg genkey | wg pubkey`).
 *
 * ### Step 4: examine `terraform plan` output
 * Run `terraform plan` and examine the output. Carefully. Does it do what you'd expect?! Seriously. Look.
 *
 * ### Step 5: apply with `terraform apply`
 * Run `terraform apply` and examine the output again, then approve the
 * changes. Note that a `terraform apply` will take a couple minutes to
 * initialize and install packages, configurations, etc. before the vpn will be
 * available. In my testing this is usually less than 5 minutes but I wouldn't
 * get worried until about 10 minutes..
 *
 * 
 * ### Step 6: Connect clients using the generated `example_config`
 *
 */

locals {
  wg_v4_subnet = format("%s/%d", var.ipv4_address, var.ipv4_subnet_len)
  wg_v6_subnet = format("%s/%d", var.ipv6_address, var.ipv6_subnet_len)
}

variable "hostname" {
  description = "hostname to give the built droplet host"
  default     = "wg0"
}

variable "domain" {
  description = "domain to give the built droplet host"
  default     = "example.com"
}

variable "port" {
  description = "udp port to listen for vpn connections"
  default     = 1113
}

variable "ipv4_address" {
  description = "ipv4 ip of bastion on wireguard interface"
  default     = "10.42.0.1"
}

variable "ipv4_subnet_len" {
  description = "ipv4 subnet mask length (1-32)"
  default     = 24
}

variable "ipv6_address" {
  description = "ipv6 ip of bastion on wireguard interface"
  default     = "fdc9:281f:04d7:9ee9::1"
}

variable "ipv6_subnet_len" {
  description = "ipv6 subnet mask length (1-128)"
  default     = 64
}

variable "private_key" {
  default     = "X change me XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX="
  sensitive   = true
  description = "valid wireguard \"PrivateKey=\" value. must match public key."
  type        = string
}

variable "public_key" {
  description = "valid wireguard \"PublicKey=\" value. must match private key."
  type        = string
  default     = "X change me XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX="
}

variable "peers" {
  type = list(object({
    public_key    = string
    preshared_key = string
    allowed_ips   = list(string)
  }))
  default = [
    {
      public_key    = "X change me XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX="
      preshared_key = "X change me XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX="
      allowed_ips   = ["10.42.0.2/32", "fdc9:281f:04d7:9ee9::2/128"]
    }
  ]
}
locals {
  post_up_hook = [
    "iptables -A FORWARD -i %i -j ACCEPT",
    "iptables -A FORWARD -o %i -j ACCEPT",
    "iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE",
  ]
  post_down_hook = [
    "iptables -D FORWARD -i %i -j ACCEPT",
    "iptables -D FORWARD -o %i -j ACCEPT",
    "iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE",
  ]
}

data "template_file" "config" {
  template = <<EOF
[Interface]
Address     = ${local.wg_v4_subnet}, ${local.wg_v6_subnet}
ListenPort  = ${var.port}
PrivateKey  = ${var.private_key}
#PublicKey  = ${var.public_key}
PostDown    = ${join("; ", local.post_down_hook)}
PostUp      = ${join("; ", local.post_up_hook)}

${join("\n\n", data.template_file.config_peers.*.rendered)}

EOF
}

data "template_file" "config_peers" {
  count    = length(var.peers)
  template = <<EOF
[Peer]
PublicKey    = ${lookup(element(var.peers, count.index), "public_key")}
PresharedKey = ${lookup(element(var.peers, count.index), "preshared_key")}
AllowedIPs   = ${join(",", lookup(element(var.peers, count.index), "allowed_ips"))}
EOF
}

output "rendered" {
  description = "rendered wireguard config file"
  value       = data.template_file.config.rendered
}

output "example_peer" {
  description = "example wireguard peer configuration for this endpoint"
  value       = <<EOF
[Interface]
ListenPort=${var.port}
# CHANGEME: Dont forget to increment these IPs to match correct address for
# each client:
Address=${var.ipv4_address}/32,${var.ipv6_address}/128
PrivateKey=CHANGE_ME

[Peer]
PublicKey=${var.public_key}
PresharedKey=CHANGEME
AllowedIPs=${var.ipv4_address},${var.ipv6_address},0.0.0.0/0,::/0
Endpoint=${digitalocean_floating_ip.main.ip_address}:${var.port}
# PersistentKeepAlive=60
EOF
}

output "sha1" {
  value = sha1(data.template_file.config.rendered)
}
