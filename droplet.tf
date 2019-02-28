resource "digitalocean_droplet" "node" {
  count = "${var.number_of_node}"
  image = "ubuntu-16-04-x64"
  name = "rancher-cluster-node-${count.index}"
  region = "${var.region}"
  size = "s-1vcpu-2gb"
  ssh_keys = ["${digitalocean_ssh_key.key.id}"]
  monitoring = true
  private_networking = true
  user_data = <<EOF
#!/bin/bash
curl https://releases.rancher.com/install-docker/17.03.sh | sh
EOF
}

resource "digitalocean_record" "rc" {
  count = "${var.number_of_node}"
  domain = "${var.domain_suffix}"
  type = "A"
  name = "rc"
  value = "${element(digitalocean_droplet.node.*.ipv4_address, count.index)}"
  ttl = 300
}

output "node0_address" {
  value = "${element(digitalocean_droplet.node.*.ipv4_address, 0)}"
}

output "node1_address" {
  value = "${element(digitalocean_droplet.node.*.ipv4_address, 1)}"
}

output "node2_address" {
  value = "${element(digitalocean_droplet.node.*.ipv4_address, 2)}"
}

output "node0_address_private" {
  value = "${element(digitalocean_droplet.node.*.ipv4_address_private, 0)}"
}

output "node1_address_private" {
  value = "${element(digitalocean_droplet.node.*.ipv4_address_private, 1)}"
}

output "node2_address_private" {
  value = "${element(digitalocean_droplet.node.*.ipv4_address_private, 2)}"
}
