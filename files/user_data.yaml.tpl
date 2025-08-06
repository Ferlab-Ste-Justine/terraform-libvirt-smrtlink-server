#cloud-config
%{ if admin_user_password != "" ~}
chpasswd:
  list: |
     ${ssh_admin_user}:${admin_user_password}
  expire: False
%{ endif ~}
preserve_hostname: false
hostname: ${hostname}
users:
  - default
  - name: ${ssh_admin_user}
    ssh_authorized_keys:
      - "${ssh_admin_public_key}"
%{ if install_dependencies ~}
  - name: ${user.name}
    lock_passwd: true
    shell: /bin/bash
%{ if length(user.ssh_authorized_keys) > 0 ~}
    ssh_authorized_keys:
%{ for key in user.ssh_authorized_keys ~}
      - "${key}"
%{ endfor ~}
%{ endif ~}
%{ endif ~}

runcmd:
  - mkdir /var/lib/smrtlink
  - chown ${user.name}:${user.name} /var/lib/smrtlink
