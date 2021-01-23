# DigitalOcean Wireguard Bastion

## Features
- Provisions 1 droplet with configured wireguard peers/secrets.
- Generates **strict** vpc firewall rules to prevent unauthorized access.

## Obtaining Wireguard Key(s)
- **NOTE** _always_ restrict file permissions with `umask 077` before starting..
- PrivateKey can be obtained with `wg genkey`.
- PresharedKey can be obtained with `wg genpsk`.
- PublicKey can be obtained with `cat <private-key> | wg pubkey`.

## Example Usage

### Step 1: create a `bastion.tf`  
_Something roughly like this should work..._

```hcl
variable "wg_key" {}
variable "wg_pub" {}

module "bastion" {
  source                 = "./bastion"
  hostname               = "bastion"
  wireguard_private_key  = var.wg_key
  wireguard_public_key   = var.wg_pub
  wireguard_ipv4_address = "10.42.0.1"
  wireguard_peers        = jsondecode(file("./bastion.peers.json"))
  # OPTIONAL:
  # ssh_keys               = [digitalocean_ssh_key.example.id]
}

output "bastion" {
  description = "outputs from bastion"
  value       = module.bastion
}

resource "digitalocean_record" "bastion" {
  domain = digitalocean_domain.example.name
  type   = "A"
  name   = "bastion"
  value  = module.bastion.public_ipv4
}

resource "digitalocean_record" "bastion_v6" {
  domain = digitalocean_domain.example.name
  type   = "AAAA"
  name   = "bastion"
  value  = module.bastion.public_ipv6
}
```

### Step 2: create a `bastion.peers.json`  
in a json file, named like in `bastion.tf` above, configure your wireguard  
keys (as described above) **individually** for each host you'd like to  
connect:

```json
[
    {
        "preshared_key": "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX=",
        "public_key": "YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY=",
        "allowed_ips": [
            "10.42.0.2"
        ]
    }
]
```

### Step 3: update your _"tfvars"_  
Add 2 variables to your `terraform.tfvars` *(or how ever you do it in your project ...)*:
 - `wg_key`: the `PrivateKey=` portion of the wireguard config (obtainable by `wg genkey`).
 - `wg_pub`: the `PublicKey=` portion of the wireguard config (obtainable by `wg genkey | wg pubkey`).

### Step 4: examine `terraform plan` output  
Run `terraform plan` and examine the output. Carefully. Does it do what you'd expect?! Seriously. Look.

### Step 5: apply with `terraform apply`  
Run `terraform apply` and examine the output again, then approve the  
changes. Note that a `terraform apply` will take a couple minutes to  
initialize and install packages, configurations, etc. before the vpn will be  
available. In my testing this is usually less than 5 minutes but I wouldn't  
get worried until about 10 minutes..

#### Example `terraform apply` Output
```
bastion = {
 "public_ipv4" = "144.126.243.21"
 "public_ipv6" = "2604:a880:800:ba::cd9:f001"
 "wireguard" = {
   "example_config" = <<-EOT
   [Interface]
   ListenPort=27015
   PrivateKey=CHANGE_ME
   # CHANGEME: Dont forget to increment these IPs to match correct address for each client:
   Address=10.42.0.1/32,fcd9:281f:04d7:e99e::1/128
   [Peer]
   PublicKey=6jB77xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx=
   PresharedKey=CHANGEME
   AllowedIPs=10.42.0.1,fcd9:281f:04d7:e99e::1,0.0.0.0/0,::/0
   Endpoint=144.126.243.21:27015
   # PersistentKeepAlive=60
```

## Providers

| Name | Version |
|------|---------|
| digitalocean | 2.3.0 |
| template | n/a |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| digitalocean_droplet_size | droplet size to deploy (defaults to cheapest option) | `string` | `"s-1vcpu-1gb"` | no |
| digitalocean_image_name | unique image name to deploy to digitalocean | `string` | `"ubuntu-18-04-x64"` | no |
| digitalocean_region | region to deploy into | `string` | `"nyc3"` | no |
| hostname | hostname to give the built droplet host | `string` | `"bastion"` | no |
| ssh_keys | digitalocean ssh keys to add to the droplet. note that SSH is blocked by the cloud firewall, by default. | `list(any)` | `[]` | no |
| tags | tags to add to the droplet/firewall/etc. | `list(string)` | <pre>[<br>  "bastion"<br>]</pre> | no |
| wireguard_ipv4_address | ipv4 ip of bastion on wireguard interface | `string` | `"10.42.0.1"` | no |
| wireguard_ipv4_subnet_len | ipv4 subnet mask length (1-32) | `number` | `24` | no |
| wireguard_ipv6_address | ipv6 ip of bastion on wireguard interface | `string` | `"fdc9:281f:04d7:9ee9::1"` | no |
| wireguard_ipv6_subnet_len | ipv6 subnet mask length (1-128) | `number` | `64` | no |
| wireguard_peers | n/a | <pre>list(object({<br>    public_key    = string<br>    preshared_key = string<br>    allowed_ips   = list(string)<br>  }))</pre> | <pre>[<br>  {<br>    "allowed_ips": [<br>      "10.42.0.2/32",<br>      "fdc9:281f:04d7:9ee9::2/128"<br>    ],<br>    "preshared_key": "X change me XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX=",<br>    "public_key": "X change me XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX="<br>  }<br>]</pre> | no |
| wireguard_port | udp port to listen for vpn connections | `number` | `1113` | no |
| wireguard_private_key | valid wireguard "PrivateKey=" value. must match public key. | `string` | `"X change me XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX="` | no |
| wireguard_public_key | valid wireguard "PublicKey=" value. must match private key. | `string` | `"X change me XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX="` | no |

## Outputs

| Name | Description |
|------|-------------|
| public_ipv4 | publicly routeable ipv4 address |
| public_ipv6 | publicly routeable ipv6 address |
| wireguard | internal wireguard subnet |

