require 'textual_mixins/device'
module TextualMixins::TextualDevices
  def textual_devices
    devices = devices_details
    h = {:label    => _("Devices"),
         :icon     => "fa fa-hdd-o",
         :explorer => true,
         :value    => devices.blank? ? _("None") : devices.length}
    unless devices.blank?
      h[:title] = _("Show VMs devices")
      h[:link]  = url_for_only_path(:action => 'show', :id => @record, :display => 'devices')
    end
    h
  end

  def processor_description
    description = if @record.num_cpu > 0 && @record.cpu_cores_per_socket > 0
                    _("%{total_cores} (%{num_sockets} Sockets x %{num_cores} Cores)") %
                      {:total_cores => @record.cpu_total_cores,
                       :num_sockets => @record.num_cpu,
                       :num_cores   => @record.cpu_cores_per_socket}
                  else
                    _("%{total_cores}") % {:total_cores => @record.cpu_total_cores}
                  end

    Device.new(_("Processors"), description, nil, :processor)
  end

  def cpu_attributes
    [[_("CPU Type"), :cpu_type, nil, :processor],
     [_("CPU Speed"), :cpu_speed, _("MHz"), :processor],
     [_("Memory"), :memory_mb, _("MB"), :memory]].map do |attribute|
       device = Device.new(*attribute)
       device.description_value(@record)
       device
     end
  end

  def disks_attributes
    disks = []
    return disks if @record.hardware.disks.empty?

    # HDDs
    disks = @record.hardware.hard_disks.map do |disk|
      device_name = _("Hard Disk")

      hd_name = disk.device_name.upcase
      location = disk.location.presence || _("N/A")
      size = disk.size.presence || _("N/A")
      pct_prov = disk.size_on_disk.nil? ? _("N/A") : disk.used_percent_of_provisioned
      filename = disk.filename.presence || _("N/A")
      mode = disk.mode.presence || _("N/A")
      description = _("Name: %{hd_name}, Location: %{location}, Size: %{size}, Percent Used Provisioned Space: %{prov}, " \
                      "Filename: %{filename}, Mode: %{mode}") % {:hd_name  => hd_name,
                                                                 :location => location,
                                                                 :size     => size,
                                                                 :prov     => pct_prov,
                                                                 :filename => filename,
                                                                 :mode     => mode}
      Device.new(device_name, description, nil, :disk)
    end

    # Floppies
    floppies = @record.hardware.floppies
    if floppies.present?
      disks += floppies.map do |floppy|
        name = floppy.controller_type.upcase
        connection = _("Connected at Power On = %{connect}") % {:connect => floppy.start_connected.to_s}
        location = floppy.location
        device_name = _("Floppy %{name} %{location} %{connection}") % {:name => name, :connection => connection, :location => location}
        Device.new(device_name, nil, nil, :floppy)
      end
    end

    # CD-ROMS
    cdroms = @record.hardware.cdroms
    if cdroms.present?
      disks += cdroms.map do |cd|
        name = cd.controller_type.upcase
        connection = _("Connected at Power On = %{connect}") % {:connect => cd.start_connected.to_s}
        location = cd.location
        device_name = _("CD-ROM (%{name} %{location}), %{connection}") % {:name => name, :location => location, :connection => connection}
        Device.new(device_name, nil, nil, :cdrom)
      end
    end
    disks.compact
  end

  def network_name(port)
    network = nil
    if port.lan&.switch
      network = _("Network:") + port.lan.name + lan_attribute(port)
    end
    network
  end

  def network_attributes
    networks = []
    return networks if @record.hardware.ports.empty?
    @record.hardware.ports.map do |port|
      name = "#{port.controller_type.capitalize} #{port.device_name}"
      location = port.location
      address = port.address
      filename = port.filename
      autodetect = port.auto_detect ? "" : _("Default Adapter")
      desc = [location, address, filename, autodetect, network_name(port)].compact.join(', ')
      Device.new(name, desc, nil, port.device_type)
    end
  end

  def lan_prefix(nic)
    nic.lan&.switch&.shared? ? _("Distributed ") : ''
  end

  def lan_attribute(nic)
    nic.lan&.switch&.name ? "(" + lan_prefix(nic) + _("Switch: ") + nic.lan.switch.name + ")" : ''
  end

  def devices_details
    devices = []
    return devices unless @record.try(:hardware)
    devices << processor_description
    devices += cpu_attributes
    devices += disks_attributes
    devices += network_attributes
    devices
  end
end
