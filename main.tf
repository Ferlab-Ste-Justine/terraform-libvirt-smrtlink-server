locals {
  fluentbit_updater_etcd = var.fluentbit.enabled && var.fluentbit_dynamic_config.enabled && var.fluentbit_dynamic_config.source == "etcd"
  fluentbit_updater_git = var.fluentbit.enabled && var.fluentbit_dynamic_config.enabled && var.fluentbit_dynamic_config.source == "git"
  cloud_init_volume_name = var.cloud_init_volume_name == "" ? "${var.name}-cloud-init.iso" : var.cloud_init_volume_name
  network_interfaces = concat(
    [for libvirt_network in var.libvirt_networks: {
      network_name = libvirt_network.network_name != "" ? libvirt_network.network_name : null
      network_id = libvirt_network.network_id != "" ? libvirt_network.network_id : null
      macvtap = null
      addresses = null
      mac = libvirt_network.mac
      hostname = null
    }],
    [for macvtap_interface in var.macvtap_interfaces: {
      network_name = null
      network_id = null
      macvtap = macvtap_interface.interface
      addresses = null
      mac = macvtap_interface.mac
      hostname = null
    }]
  )
  volumes = var.data_volume_id != "" ? [var.volume_id, var.data_volume_id] : [var.volume_id]
}

module "network_configs" {
  source             = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//network?ref=v0.46.3"
  network_interfaces = concat(
    [for idx, libvirt_network in var.libvirt_networks: {
      ip = libvirt_network.ip
      gateway = libvirt_network.gateway
      prefix_length = libvirt_network.prefix_length
      interface = "libvirt${idx}"
      mac = libvirt_network.mac
      dns_servers = libvirt_network.dns_servers
    }],
    [for idx, macvtap_interface in var.macvtap_interfaces: {
      ip = macvtap_interface.ip
      gateway = macvtap_interface.gateway
      prefix_length = macvtap_interface.prefix_length
      interface = "macvtap${idx}"
      mac = macvtap_interface.mac
      dns_servers = macvtap_interface.dns_servers
    }]
  )
}

module "smrtlink_configs" {
  source                  = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//smrtlink?ref=v0.46.3"
  install_dependencies    = var.install_dependencies
  domain_name             = var.smrtlink.domain_name
  tls_custom              = var.smrtlink.tls_custom
  user                    = var.smrtlink.user.name
  revio                   = var.smrtlink.revio
  release_version         = var.smrtlink.release_version
  install_lite            = var.smrtlink.install_lite
  workers_count           = var.smrtlink.workers_count
  keycloak_user_passwords = var.smrtlink.keycloak_user_passwords
  keycloak_users          = var.smrtlink.keycloak_users
  smtp                    = var.smrtlink.smtp
  db_backups              = var.smrtlink.db_backups
  restore_db              = var.s3_backups.restore
}

locals {
  s3_backups_paths = flatten([
    var.smrtlink.revio.srs_transfer.dest_path != "" ? [
      {
        fs = var.smrtlink.revio.srs_transfer.dest_path,
        s3 = "data"
      }
    ] : [],
    [
      {
        fs = "/var/lib/smrtlink/userdata/db_datadir/backups",
        s3 = "userdata/db_datadir/backups"
      },
      {
        fs = "/var/lib/smrtlink/userdata/jobs_root",
        s3 = "userdata/jobs_root"
      },
      {
        fs = "/var/lib/smrtlink/userdata/uploads",
        s3 = "userdata/uploads"
      }
    ]
  ])
}

module "s3_mounts" {
  source               = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//s3-mounts?ref=v0.46.3"
  mounts               = var.s3_mounts
  install_dependencies = var.install_dependencies
}

module "s3_backups" {
  source       = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//s3-syncs?ref=v0.46.3"
  object_store = {
    url                    = var.s3_backups.url
    region                 = var.s3_backups.region
    access_key             = var.s3_backups.access_key
    secret_key             = var.s3_backups.secret_key
    server_side_encryption = var.s3_backups.server_side_encryption
    ca_cert                = var.s3_backups.ca_cert
  }
  outgoing_sync = {
    calendar        = var.s3_backups.calendar
    bucket          = var.s3_backups.bucket
    paths           = local.s3_backups_paths
    symlinks        = "copy"
  }
  incoming_sync = {
    sync_once       = true
    calendar        = var.s3_backups.calendar
    bucket          = var.s3_backups.bucket
    paths           = var.s3_backups.restore ? local.s3_backups_paths : []
    symlinks        = "copy"
  }
  user                 = var.smrtlink.user.name
  install_dependencies = var.install_dependencies
}

module "prometheus_node_exporter_configs" {
  source               = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//prometheus-node-exporter?ref=v0.46.3"
  install_dependencies = var.install_dependencies
}

module "chrony_configs" {
  source               = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//chrony?ref=v0.46.3"
  install_dependencies = var.install_dependencies
  chrony               = {
    servers  = var.chrony.servers
    pools    = var.chrony.pools
    makestep = var.chrony.makestep
  }
}

module "fluentbit_updater_etcd_configs" {
  source = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//configurations-auto-updater?ref=v0.46.3"
  install_dependencies = var.install_dependencies
  filesystem = {
    path = "/etc/fluent-bit-customization/dynamic-config"
    files_permission = "700"
    directories_permission = "700"
  }
  etcd = {
    key_prefix = var.fluentbit_dynamic_config.etcd.key_prefix
    endpoints = var.fluentbit_dynamic_config.etcd.endpoints
    connection_timeout = "60s"
    request_timeout = "60s"
    retry_interval = "4s"
    retries = 15
    auth = {
      ca_certificate = var.fluentbit_dynamic_config.etcd.ca_certificate
      client_certificate = var.fluentbit_dynamic_config.etcd.client.certificate
      client_key = var.fluentbit_dynamic_config.etcd.client.key
      username = var.fluentbit_dynamic_config.etcd.client.username
      password = var.fluentbit_dynamic_config.etcd.client.password
    }
  }
  notification_command = {
    command = ["/usr/local/bin/reload-fluent-bit-configs"]
    retries = 30
  }
  naming = {
    binary = "fluent-bit-config-updater"
    service = "fluent-bit-config-updater"
  }
  user = "fluentbit"
}

module "fluentbit_updater_git_configs" {
  source = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//gitsync?ref=v0.46.3"
  install_dependencies = var.install_dependencies
  filesystem = {
    path = "/etc/fluent-bit-customization/dynamic-config"
    files_permission = "700"
    directories_permission = "700"
  }
  git = var.fluentbit_dynamic_config.git
  notification_command = {
    command = ["/usr/local/bin/reload-fluent-bit-configs"]
    retries = 30
  }
  naming = {
    binary = "fluent-bit-config-updater"
    service = "fluent-bit-config-updater"
  }
  user = "fluentbit"
}

module "fluentbit_configs" {
  source = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//fluent-bit?ref=v0.46.3"
  install_dependencies = var.install_dependencies
  fluentbit = {
    metrics = var.fluentbit.metrics
    systemd_services = concat(var.s3_backups.enabled ? [
      {
        tag     = var.fluentbit.s3_backup_tag
        service = "s3-outgoing-sync.service"
      },
      {
        tag     = var.fluentbit.s3_restore_tag
        service = "s3-incoming-sync.service"
      }
    ] : [],
    [
      {
        tag     = var.fluentbit.smrtlink_tag
        service = "smrtlink.service"
      },
      {
        tag = var.fluentbit.node_exporter_tag
        service = "node-exporter.service"
      }
    ])
    log_files = []
    forward   = var.fluentbit.forward
  }
  dynamic_config = {
    enabled = var.fluentbit_dynamic_config.enabled
    entrypoint_path = "/etc/fluent-bit-customization/dynamic-config/index.conf"
  }
}

module "vault_agent_configs" {
  source               = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//vault-agent?ref=v0.46.3"
  install_dependencies = var.install_dependencies
  vault_agent          = {
    auth_method            = var.vault_agent.auth_method
    vault_address          = var.vault_agent.vault_address
    vault_ca_cert          = var.vault_agent.vault_ca_cert
    extra_config           = ""
  }
}

module "data_volume_configs" {
  source  = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//data-volumes?ref=v0.46.3"
  volumes = [{
    label         = "smrtlink_data"
    device        = "vdb"
    filesystem    = "ext4"
    mount_path    = "/var/lib/smrtlink"
    mount_options = "defaults"
  }]
}

locals {
  cloudinit_templates = concat(
    # Base first so it's up-and-running before the rest (where the 'user' is needed)
    [
      {
        filename     = "base.cfg"
        content_type = "text/cloud-config"
        content      = templatefile(
          "${path.module}/files/user_data.yaml.tpl", 
          {
            hostname             = var.name
            ssh_admin_public_key = var.ssh_admin_public_key
            ssh_admin_user       = var.ssh_admin_user
            admin_user_password  = var.admin_user_password
            install_dependencies = var.install_dependencies
            user                 = var.smrtlink.user
          }
        )
      }
    ],
    # Data Volume + S3 Backups (including a potential restore) + Vault Agent then so it's up-and-running before SMRT Link starts
    var.data_volume_id != "" ? [{
      filename     = "data_volume.cfg"
      content_type = "text/cloud-config"
      content      = module.data_volume_configs.configuration
    }] : [],
    var.s3_backups.enabled ? [{
      filename     = "s3_backups.cfg"
      content_type = "text/cloud-config"
      content      = module.s3_backups.configuration
    }] : [],
    var.vault_agent.enabled ? [{
      filename     = "vault_agent.cfg"
      content_type = "text/cloud-config"
      content      = module.vault_agent_configs.configuration
    }] : [],
    [
      {
        filename     = "smrtlink.cfg"
        content_type = "text/cloud-config"
        content      = module.smrtlink_configs.configuration
      },
      {
        filename     = "s3_mounts.cfg"
        content_type = "text/cloud-config"
        content      = module.s3_mounts.configuration
      },
      {
        filename     = "node_exporter.cfg"
        content_type = "text/cloud-config"
        content      = module.prometheus_node_exporter_configs.configuration
      }
    ],
    var.chrony.enabled ? [{
      filename     = "chrony.cfg"
      content_type = "text/cloud-config"
      content      = module.chrony_configs.configuration
    }] : [],
    local.fluentbit_updater_etcd ? [{
      filename     = "fluent_bit_updater.cfg"
      content_type = "text/cloud-config"
      content      = module.fluentbit_updater_etcd_configs.configuration
    }] : [],
    local.fluentbit_updater_git ? [{
      filename     = "fluent_bit_updater.cfg"
      content_type = "text/cloud-config"
      content      = module.fluentbit_updater_git_configs.configuration
    }] : [],
    var.fluentbit.enabled ? [{
      filename     = "fluent_bit.cfg"
      content_type = "text/cloud-config"
      content      = module.fluentbit_configs.configuration
    }] : []
  )
}

data "template_cloudinit_config" "user_data" {
  gzip          = false
  base64_encode = false
  dynamic "part" {
    for_each = local.cloudinit_templates
    content {
      filename     = part.value["filename"]
      content_type = part.value["content_type"]
      content      = part.value["content"]
    }
  }
}

resource "libvirt_cloudinit_disk" "smrtlink_node" {
  name           = local.cloud_init_volume_name
  user_data      = data.template_cloudinit_config.user_data.rendered
  network_config = module.network_configs.configuration
  pool           = var.cloud_init_volume_pool
}

resource "libvirt_domain" "smrtlink_node" {
  name = var.name

  cpu {
    mode = "host-passthrough"
  }

  vcpu   = var.vcpus
  memory = var.memory

  dynamic "disk" {
    for_each = local.volumes
    content {
      volume_id = disk.value
    }
  }

  dynamic "network_interface" {
    for_each = local.network_interfaces
    content {
      network_id   = network_interface.value["network_id"]
      network_name = network_interface.value["network_name"]
      macvtap      = network_interface.value["macvtap"]
      addresses    = network_interface.value["addresses"]
      mac          = network_interface.value["mac"]
      hostname     = network_interface.value["hostname"]
    }
  }

  autostart = true

  cloudinit = libvirt_cloudinit_disk.smrtlink_node.id

  //https://github.com/dmacvicar/terraform-provider-libvirt/blob/main/examples/v0.13/ubuntu/ubuntu-example.tf#L61
  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  console {
    type        = "pty"
    target_type = "virtio"
    target_port = "1"
  }
}