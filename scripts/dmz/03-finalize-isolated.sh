#!/usr/bin/env bash
# Run on the Docker-DMZ VM as root, BEFORE removing the NAT adapter on the host.
#
# WHAT: switches the VM to its permanent, internet-free network configuration:
#       the DMZ address with pfSense-A (192.168.14.1) as the gateway, and no
#       second adapter.
# WHY:  the VM must never keep a route to the internet once DVWA and the
#       honeypot are running. After this, shut the VM down and run
#       scripts/remove-temp-nat.ps1 on the host to detach the NAT adapter.
set -euo pipefail

DMZ_IF="${1:-enp0s3}"

cat > /etc/netplan/60-lab.yaml <<EOF
network:
  version: 2
  ethernets:
    $DMZ_IF:
      dhcp4: false
      addresses: [192.168.14.10/24]
      routes:
        - to: default
          via: 192.168.14.1
EOF
chmod 600 /etc/netplan/60-lab.yaml
echo "Permanent network configuration written."
echo "Next: shut down (sudo poweroff), then on the host run:  .\\scripts\\remove-temp-nat.ps1 -Vm Docker-DMZ"
