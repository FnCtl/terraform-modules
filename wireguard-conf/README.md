# Wireguard Config

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

module "wg0" {
  source       = "./wireguard-config"
  hostname     = "bastion"
  domain       = "example.com"
  private_key  = var.wg_key
  public_key   = var.wg_pub
  ipv4_address = "10.42.0.1"
  peers        = jsondecode(file("./bastion.peers.json"))
}

output "config_file" {
  description = "outputs wireguard config"
  value       = module.wg0.rendered
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

### Step 6: Connect clients using the generated `example_config`

## Providers

| Name | Version |
|------|---------|
| template | n/a |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| domain | domain to give the built droplet host | `string` | `"fnctl.io"` | no |
| hostname | hostname to give the built droplet host | `string` | `"udx"` | no |
| ipv4_address | ipv4 ip of bastion on wireguard interface | `string` | `"10.42.0.1"` | no |
| ipv4_subnet_len | ipv4 subnet mask length (1-32) | `number` | `24` | no |
| ipv6_address | ipv6 ip of bastion on wireguard interface | `string` | `"fdc9:281f:04d7:9ee9::1"` | no |
| ipv6_subnet_len | ipv6 subnet mask length (1-128) | `number` | `64` | no |
| peers | n/a | <pre>list(object({<br>    public_key    = string<br>    preshared_key = string<br>    allowed_ips   = list(string)<br>  }))</pre> | <pre>[<br>  {<br>    "allowed_ips": [<br>      "10.42.0.2/32",<br>      "fdc9:281f:04d7:9ee9::2/128"<br>    ],<br>    "preshared_key": "X change me XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX=",<br>    "public_key": "X change me XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX="<br>  }<br>]</pre> | no |
| port | udp port to listen for vpn connections | `number` | `1113` | no |
| private_key | valid wireguard "PrivateKey=" value. must match public key. | `string` | `"X change me XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX="` | no |
| public_key | valid wireguard "PublicKey=" value. must match private key. | `string` | `"X change me XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX="` | no |

## Outputs

| Name | Description |
|------|-------------|
| example_peer | example wireguard peer configuration for this endpoint |
| rendered | rendered wireguard config file |
| sha1 | n/a |

