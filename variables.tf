variable "name" {
  description = "Name to give to the vm"
  type        = string
}

variable "vcpus" {
  description = "Number of vcpus to assign to the vm"
  type        = number
  default     = 4
}

variable "memory" {
  description = "Amount of memory in MiB"
  type        = number
  default     = 16 * 1024
}

variable "volume_id" {
  description = "Id of the disk volume to attach to the vm"
  type        = string
}

variable "data_volume_id" {
  description = "Id for an optional separate disk volume to attach to the vm on smrt-link's data path"
  type        = string
  default     = ""
}

variable "libvirt_networks" {
  description = "Parameters of libvirt network connections if a libvirt networks are used"
  type = list(object({
    network_name = string
    network_id = string
    prefix_length = string
    ip = string
    mac = string
    gateway = string
    dns_servers = list(string)
  }))
  default = []
}

variable "macvtap_interfaces" {
  description = "List of macvtap interfaces"
  type        = list(object({
    interface     = string
    prefix_length = string
    ip            = string
    mac           = string
    gateway       = string
    dns_servers   = list(string)
  }))
  default = []
}

variable "cloud_init_volume_pool" {
  description = "Name of the volume pool that will contain the cloud init volume"
  type        = string
}

variable "cloud_init_volume_name" {
  description = "Name of the cloud init volume"
  type        = string
  default     = ""
}

variable "ssh_admin_user" { 
  description = "Pre-existing ssh admin user of the image"
  type        = string
  default     = "ubuntu"
}

variable "admin_user_password" { 
  description = "Optional password for admin user"
  type        = string
  sensitive   = true
  default     = ""
}

variable "ssh_admin_public_key" {
  description = "Public ssh part of the ssh key the admin will be able to login as"
  type        = string
}

variable "chrony" {
  description = "Chrony configuration for ntp. If enabled, chrony is installed and configured, else the default image ntp settings are kept"
  type        = object({
    enabled = bool,
    //https://chrony.tuxfamily.org/doc/4.2/chrony.conf.html#server
    servers = list(object({
      url     = string,
      options = list(string)
    })),
    //https://chrony.tuxfamily.org/doc/4.2/chrony.conf.html#pool
    pools = list(object({
      url     = string,
      options = list(string)
    })),
    //https://chrony.tuxfamily.org/doc/4.2/chrony.conf.html#makestep
    makestep = object({
      threshold = number,
      limit     = number
    })
  })
  default = {
    enabled  = false
    servers  = []
    pools    = []
    makestep = {
      threshold  = 0,
      limit      = 0
    }
  }
}

variable "fluentbit" {
  description = "Fluent-bit configuration"
  type = object({
    enabled = bool
    smrtlink_tag = string
    s3_backup_tag = string
    s3_restore_tag = string
    node_exporter_tag = string
    metrics = object({
      enabled = bool
      port    = number
    })
    forward = object({
      domain = string
      port = number
      hostname = string
      shared_key = string
      ca_cert = string
    })
  })
  default = {
    enabled = false
    smrtlink_tag = ""
    s3_backup_tag = ""
    s3_restore_tag = ""
    node_exporter_tag = ""
    metrics = {
      enabled = false
      port = 0
    }
    forward = {
      domain = ""
      port = 0
      hostname = ""
      shared_key = ""
      ca_cert = ""
    }
  }
}

variable "fluentbit_dynamic_config" {
  description = "Parameters for fluent-bit dynamic config if it is enabled"
  type = object({
    enabled = bool
    source  = string
    etcd    = object({
      key_prefix     = string
      endpoints      = list(string)
      ca_certificate = string
      client         = object({
        certificate = string
        key         = string
        username    = string
        password    = string
      })
    })
    git     = object({
      repo             = string
      ref              = string
      path             = string
      trusted_gpg_keys = list(string)
      auth             = object({
        client_ssh_key         = string
        client_ssh_user        = string
        server_ssh_fingerprint = string
      })
    })
  })
  default = {
    enabled = false
    source = "etcd"
    etcd = {
      key_prefix     = ""
      endpoints      = []
      ca_certificate = ""
      client         = {
        certificate = ""
        key         = ""
        username    = ""
        password    = ""
      }
    }
    git  = {
      repo             = ""
      ref              = ""
      path             = ""
      trusted_gpg_keys = []
      auth             = {
        client_ssh_key         = ""
        client_ssh_user        = ""
        server_ssh_fingerprint = ""
      }
    }
  }

  validation {
    condition     = contains(["etcd", "git"], var.fluentbit_dynamic_config.source)
    error_message = "fluentbit_dynamic_config.source must be 'etcd' or 'git'."
  }
}

variable "install_dependencies" {
  description = "Whether to install all dependencies in cloud-init"
  type        = bool
  default     = true
}

variable "s3_backups" {
  description = "Configuration to continuously backup the data paths in s3"
  sensitive   = true
  type        = object({
    enabled                = bool
    restore                = bool
    url                    = string
    region                 = string
    access_key             = string
    secret_key             = string
    server_side_encryption = string
    calendar               = string
    bucket                 = string
    ca_cert                = string
  })
  default = {
    enabled                = false
    restore                = false
    url                    = ""
    region                 = ""
    access_key             = ""
    secret_key             = ""
    server_side_encryption = ""
    calendar               = ""
    bucket                 = ""
    ca_cert                = ""
  }
}

variable "s3_mounts" {
  description = "Parameters of s3 mounts to have access to buckets from the filesystem"
  sensitive   = true
  type        = list(object({
    bucket_name   = string
    access_key    = string
    secret_key    = string
    non_amazon_s3 = optional(object({
      url     = string
      ca_cert = optional(string, "")
    }), {
      url     = ""
      ca_cert = ""
    })
    folder = optional(object({
      owner = optional(string, "smrtanalysis")
      umask = optional(string, "0007")
    }), {
      owner = "smrtanalysis"
      umask = "0007"
    })
  }))
  default = []
}

variable "vault_agent" {
  type = object({
    enabled     = bool
    auth_method = object({
      config = object({
        role_id   = string
        secret_id = string
      })
    })
    vault_address = string
    vault_ca_cert = string
  })
  default = {
    enabled = false
    auth_method = {
      config = {
        role_id   = ""
        secret_id = ""
      }
    }
    vault_address = ""
    vault_ca_cert = ""
  }
}

variable "smrtlink" {
  description = "Configuration for the smrt-link server"
  type        = object({
    domain_name = optional(string, "")
    tls_custom  = optional(object({
      cert                    = string
      key                     = string
      vault_agent_secret_path = string
    }), {
      cert                    = ""
      key                     = ""
      vault_agent_secret_path = ""
    })
    user = optional(object({
      name                = optional(string, "smrtanalysis")
      ssh_authorized_keys = list(string)
    }), {
      name                = "smrtanalysis"
      ssh_authorized_keys = []
    })
    revio = optional(object({
      srs_transfer = optional(object({
        name          = string
        description   = string
        host          = string
        dest_path     = string
        relative_path = optional(string, "")
        username      = string
        ssh_key       = string
      }), {
        name          = ""
        description   = ""
        host          = ""
        dest_path     = ""
        relative_path = ""
        username      = ""
        ssh_key       = ""
      })
      s3compatible_transfer = optional(object({
        name        = string
        description = string
        endpoint    = string
        bucket      = string
        region      = optional(string, "")
        path        = optional(string, "")
        access_key  = string
        secret_key  = string
      }), {
        name        = ""
        description = ""
        endpoint    = ""
        bucket      = ""
        region      = ""
        path        = ""
        access_key  = ""
        secret_key  = ""
      })
      instrument = object({
        name          = string
        ip_address    = string
        secret_key    = string
        transfer_name = string
      })
    }), {
      srs_transfer = {
        name          = ""
        description   = ""
        host          = ""
        dest_path     = ""
        relative_path = ""
        username      = ""
        ssh_key       = ""
      },
      s3compatible_transfer = {
        name        = ""
        description = ""
        endpoint    = ""
        bucket      = ""
        region      = ""
        path        = ""
        access_key  = ""
        secret_key  = ""
      },
      instrument = {
        name          = ""
        ip_address    = ""
        secret_key    = ""
        transfer_name = ""
      }
    })
    release_version         = optional(string, "25.1.0.257715"),
    install_lite            = optional(bool, true)
    workers_count           = optional(number, 4)
    keycloak_user_passwords = object({
      admin        = string
      pbinstrument = string
    })
    keycloak_users = optional(list(object({
      id         = string
      password   = string
      role       = string
      first_name = string
      last_name  = string
      email      = string
    })), [])
    smtp = optional(object({
      host     = string
      port     = number
      user     = string
      password = string
    }), {
      host     = ""
      port     = 25
      user     = ""
      password = ""
    }),
    db_backups = optional(object({
      enabled         = bool
      cron_expression = string
      retention_days  = number
    }), {
      enabled         = false
      cron_expression = "0 0 * * *"  # daily at midnight
      retention_days  = 7
    })
  })
  default = {
    domain_name = ""
    tls_custom  = {
      cert                    = ""
      key                     = ""
      vault_agent_secret_path = ""
    }
    user = {
      name                = "smrtanalysis"
      ssh_authorized_keys = []
    }
    revio = {
      srs_transfer = {
        name          = ""
        description   = ""
        host          = ""
        dest_path     = ""
        relative_path = ""
        username      = ""
        ssh_key       = ""
      }
      s3compatible_transfer = {
        name        = ""
        description = ""
        endpoint    = ""
        bucket      = ""
        region      = ""
        path        = ""
        access_key  = ""
        secret_key  = ""
      }
      instrument = {
        name          = ""
        ip_address    = ""
        secret_key    = ""
        transfer_name = ""
      }
    }
    release_version         = "25.1.0.257715"
    install_lite            = true
    workers_count           = 4
    keycloak_user_passwords = {
      admin        = ""
      pbinstrument = ""
    }
    keycloak_users = []
    smtp           = {
      host     = ""
      port     = 25
      user     = ""
      password = ""
    }
    db_backups = {
      enabled         = false
      cron_expression = "0 0 * * *"  # daily at midnight
      retention_days  = 7
    }
  }

  validation {
    condition = (
      var.smrtlink.revio == null ||
      var.smrtlink.revio.instrument.transfer_name == var.smrtlink.revio.srs_transfer.name ||
      var.smrtlink.revio.instrument.transfer_name == var.smrtlink.revio.s3compatible_transfer.name
    )
    error_message = "If 'smrtlink.revio' is provided, at least one of 'srs_transfer' or 's3compatible_transfer' must be provided with a 'name' matching 'instrument.transfer_name'."
  }
}
