version: 2
ethernets:
  enp1s0:
%{ if static_ip != null ~}
    dhcp4: false
    dhcp6: false
    addresses:
      - ${static_ip}/24
    routes:
      - to: default
        via: ${gateway}
    nameservers:
      addresses:
        - 8.8.8.8
        - 1.1.1.1
%{ else ~}
    dhcp4: true
    dhcp6: false
    nameservers:
      addresses:
        - 8.8.8.8
        - 1.1.1.1
%{ endif ~}
