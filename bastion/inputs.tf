/**
 * # DigitalOcean Wireguard Bastion
 * 
 * ## Features
 * - Provisions 1 droplet with configured wireguard peers/secrets.
 * - Generates **strict** vpc firewall rules to prevent unauthorized access.
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
 * module "bastion" {
 *   source                 = "./bastion"
 *   hostname               = "bastion"
 *   wireguard_private_key  = var.wg_key
 *   wireguard_public_key   = var.wg_pub
 *   wireguard_ipv4_address = "10.42.0.1"
 *   wireguard_peers        = jsondecode(file("./bastion.peers.json"))
 *   # OPTIONAL:
 *   # ssh_keys               = [digitalocean_ssh_key.example.id]
 * }
 *
 * output "bastion" {
 *   description = "outputs from bastion"
 *   value       = module.bastion
 * }
 *
 * resource "digitalocean_record" "bastion" {
 *   domain = digitalocean_domain.example.name
 *   type   = "A"
 *   name   = "bastion"
 *   value  = module.bastion.public_ipv4
 * }
 *
 * resource "digitalocean_record" "bastion_v6" {
 *   domain = digitalocean_domain.example.name
 *   type   = "AAAA"
 *   name   = "bastion"
 *   value  = module.bastion.public_ipv6
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
 * #### Example `terraform apply` Output
 * ```
 * bastion = {
 *  "public_ipv4" = "144.126.243.21"
 *  "public_ipv6" = "2604:a880:800:ba::cd9:f001"
 *  "wireguard" = {
 *    "example_config" = <<-EOT
 *    [Interface]
 *    ListenPort=27015
 *    PrivateKey=CHANGE_ME
 *    # CHANGEME: Dont forget to increment these IPs to match correct address for each client:
 *    Address=10.42.0.1/32,fcd9:281f:04d7:e99e::1/128
 *    [Peer]
 *    PublicKey=6jB77xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx=
 *    PresharedKey=CHANGEME
 *    AllowedIPs=10.42.0.1,fcd9:281f:04d7:e99e::1,0.0.0.0/0,::/0
 *    Endpoint=144.126.243.21:27015
 *    # PersistentKeepAlive=60

 *    EOT
 *    "num_peers" = 2
 *    "port" = 27015
 *    "protocol" = "udp"
 *    "public_key" = "6jB7xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx="
 *    "v4_addr" = "10.42.0.1"
 *    "v4_endpoint" = "144.126.243.21:27015"
 *    "v4_subnet" = "10.42.0.1/24"
 *    "v4_subnet_len" = 24
 *    "v6_addr" = "fcd9:281f:04d7:e99e::1"
 *    "v6_endpoint" = "[2604:a880:800:ba::cd9:f001]:27015"
 *    "v6_subnet" = "fcd9:281f:04d7:e99e::1/64"
 *    "v6_subnet_len" = 64
 *  }
 * }
 * ```
 * 
 * ### Step 6: Connect clients using the generated `example_config`
 *
 */

terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "2.3.0"
    }
  }
}

variable "ssh_keys" {
  type        = list(any)
  default     = []
  description = "digitalocean ssh keys to add to the droplet. note that SSH is blocked by the cloud firewall, by default."
}

locals {
  wg_v4_subnet = format("%s/%d", var.wireguard_ipv4_address, var.wireguard_ipv4_subnet_len)
  wg_v6_subnet = format("%s/%d", var.wireguard_ipv6_address, var.wireguard_ipv6_subnet_len)
  wg_key       = "/etc/wireguard/wg0.key"
  wg_pub       = "/etc/wireguard/wg0.pub"
  wg_conf      = "/etc/wireguard/wg0.conf"
}

variable "hostname" {
  description = "hostname to give the built droplet host"
  default     = "bastion"
}

variable "digitalocean_region" {
  description = "region to deploy into"
  default     = "nyc3"
}

variable "digitalocean_image_name" {
  description = "unique image name to deploy to digitalocean"
  default     = "ubuntu-18-04-x64"
}

variable "digitalocean_droplet_size" {
  description = "droplet size to deploy (defaults to cheapest option)"
  default     = "s-1vcpu-1gb"
}

variable "tags" {
  type        = list(string)
  description = "tags to add to the droplet/firewall/etc."
  default     = ["bastion"]
}

variable "wireguard_port" {
  description = "udp port to listen for vpn connections"
  default     = 1113
}

variable "wireguard_ipv4_address" {
  description = "ipv4 ip of bastion on wireguard interface"
  default     = "10.42.0.1"
}

variable "wireguard_ipv4_subnet_len" {
  description = "ipv4 subnet mask length (1-32)"
  default     = 24
}

variable "wireguard_ipv6_address" {
  description = "ipv6 ip of bastion on wireguard interface"
  default     = "fdc9:281f:04d7:9ee9::1"
}

variable "wireguard_ipv6_subnet_len" {
  description = "ipv6 subnet mask length (1-128)"
  default     = 64
}

variable "wireguard_private_key" {
  default     = "X change me XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX="
  sensitive   = true
  description = "valid wireguard \"PrivateKey=\" value. must match public key."
  type        = string
}

variable "wireguard_public_key" {
  description = "valid wireguard \"PublicKey=\" value. must match private key."
  type        = string
  default     = "X change me XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX="
}

variable "wireguard_peers" {
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
