# About

This package provisions a [PacBio SMRT Link](https://www.pacb.com/smrt-link/) server.

# Usage

## Input

The module takes the following variables as input:

- **name**: Name to give to the vm.

- **vcpus**: Number of vcpus to assign to the vm. Defaults to **4**.

- **memory**: Amount of memory to assign to the vm in MiB. Defaults to **16 * 1024** (16 GiB).

- **volume_id**: Id of the disk volume to attach to the vm.

- **data_volume_id**: Id for an optional separate disk volume to attach to the vm on smrt-link's data path

- **libvirt_networks**: Parameters to connect to libvirt networks. Each entry has the following keys:
  - **network_name**: Name of the libvirt network to connect to (in which case **network_id** should be an empty string).
  - **network_id**: Id (ie, uuid) of the libvirt network to connect to (in which case **network_name** should be an empty string).
  - **ip**: Ip of interface connecting to the libvirt network.
  - **mac**: Mac address of interface connecting to the libvirt network.
  - **gateway**: Ip of the network's gateway. Usually the gateway the first assignable address of a libvirt's network.
  - **dns_servers**: Dns servers to use. Usually the dns server is first assignable address of a libvirt's network.

- **macvtap_interfaces**: List of macvtap interfaces to connect the vm to if you opt for macvtap interfaces. Each entry in the list is a map with the following keys:
  - **interface**: Host network interface that you plan to connect your macvtap interface with.
  - **prefix_length**: Length of the network prefix for the network the interface will be connected to. For a **192.168.1.0/24** for example, this would be 24.
  - **ip**: Ip associated with the macvtap interface. 
  - **mac**: Mac address associated with the macvtap interface
  - **gateway**: Ip of the network's gateway for the network the interface will be connected to.
  - **dns_servers**: Dns servers for the network the interface will be connected to. If there aren't dns servers setup for the network your vm will connect to, the ip of external dns servers accessible from the network will work as well.

- **cloud_init_volume_pool**: Name of the volume pool that will contain the cloud-init volume of the vm.

- **cloud_init_volume_name**: Name of the cloud-init volume that will be generated by the module for your vm. If left empty, it will default to ``<vm name>-cloud-init.iso``.

- **ssh_admin_user**: Username of the default sudo user in the image. Defaults to **ubuntu**.

- **admin_user_password**: Optional password for the default sudo user of the image. Note that this will not enable ssh password connections, but it will allow you to log into the vm from the host using the **virsh console** command.

- **ssh_admin_public_key**: Public part of the ssh key that will be used to login as the admin on the vm.

- **chrony**: Optional chrony configuration for when you need a more fine-grained ntp setup on your vm. It is an object with the following fields:
  - **enabled**: If set to false (the default), chrony will not be installed and the vm ntp settings will be left to default.
  - **servers**: List of ntp servers to sync from with each entry containing two properties, **url** and **options** (see: https://chrony.tuxfamily.org/doc/4.2/chrony.conf.html#server)
  - **pools**: A list of ntp server pools to sync from with each entry containing two properties, **url** and **options** (see: https://chrony.tuxfamily.org/doc/4.2/chrony.conf.html#pool)
  - **makestep**: An object containing remedial instructions if the clock of the vm is significantly out of sync at startup. It is an object containing two properties, **threshold** and **limit** (see: https://chrony.tuxfamily.org/doc/4.2/chrony.conf.html#makestep)

- **fluentbit**: Fluent Bit configuration for log routing and metrics collection. It is an object with the following fields:
  - **enabled**: If set to false (the default), Fluent Bit will not be installed.
  - **smrtlink_tag**: Tag to assign to logs coming from Smrt-link.
  - **node_exporter_tag**: Tag for logs from the Prometheus node exporter.
  - **metrics**: Configuration for metrics collection.
  - **forward**: Configuration for the forward plugin to communicate with a remote Fluentbit node.

- **fluentbit_dynamic_config**: Configuration for dynamic Fluent Bit setup. It is an object with the following fields:
  - **enabled**: Whether dynamic config is enabled.
  - **source**: The source of dynamic configuration (e.g., 'etcd', 'git').
  - **etcd**: Configuration for etcd as a source.
  - **git**: Configuration for Git as a source.

- **install_dependencies**: Whether cloud-init should install external dependencies (should be set to false if you already provide an image with the external dependencies built-in). Defaults to **true**.

- **smrtlink**: Smrt-link configuration. It has the following keys:
  - **domain_name**: Fully qualified domain name of the server.
  - **user**: Smrt-link **name** + **ssh_authorized_keys** of the install user.
  - **sequencing_system**: Sequencing system to use for the smrt-link installation.
  - **revio**: Revio sequencing system settings. **sequencing_system** needs to be set to **revio**. It has the following keys:
    - **srs_transfer**: File Transfer Location settings (**name** + **description** + **host** + **dest_path** + **username** + **ssh_key**).
    - **instrument**: Intrument (connected to the File Transfer Location) settings (**name** + **ip_address** + **secret_key**).
  - **release_version**: Smrt-link release version to install.
  - **install_lite**: Whether to install smrt-link lite edition.
  - **workers_count**: Maximum number of simultaneous analysis jobs.
  - **keycloak_user_passwords**: Keycloak **admin** + **pbicsuser** + **pbinstrument** user passwords to change from defaults.
  - **smtp**: Smtp configuration (**host** + **port** + **user** + **password**) for email notifications of analysis jobs.