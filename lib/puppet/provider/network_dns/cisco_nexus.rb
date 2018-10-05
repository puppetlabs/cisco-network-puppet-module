require 'puppet/resource_api/simple_provider'

# Implementation for the network_dns type using the Resource API.
class Puppet::Provider::NetworkDns::CiscoNexus < Puppet::ResourceApi::SimpleProvider
  def get(_context)
    @domain ||= Cisco::DomainName.domainnames
    @searches ||= Cisco::DnsDomain.dnsdomains || {}
    @servers ||= Cisco::NameServer.nameservers || {}
    @hostname ||= Cisco::HostName.hostname || {}

    current_state = {
      name:     'settings',
      ensure:   'present',
      domain:   @domain.keys.first,
      hostname: @hostname.keys.first,
      search:   @searches.keys,
      servers:  @servers.keys,
    }

    [current_state]
  end

  def update(context, name, should)
    validate_name(name)

    context.notice("Updating '#{name}' with #{should.inspect}")
    @domain ||= Cisco::DomainName.domainnames
    @searches ||= Cisco::DnsDomain.dnsdomains || {}
    @servers ||= Cisco::NameServer.nameservers || {}
    @hostname ||= Cisco::HostName.hostname || {}

    handle_hostname(should[:hostname])
    handle_domain(should[:domain])
    handle_servers(should[:servers])
    handle_searches(should[:search])
  end

  def delete(_context, _name)
    raise Puppet::ResourceError, 'This provider does not support ensure => absent'
  end

  def handle_servers(values)
    @servers ||= Cisco::NameServer.nameservers || {}
    to_remove = @servers.keys - values
    to_create = values - @servers.keys
    to_remove.each do |server|
      @servers[server].destroy
    end
    to_create.each do |server|
      Cisco::NameServer.new(server)
    end
  end

  def handle_searches(values)
    @searches ||= Cisco::DnsDomain.dnsdomains || {}
    to_remove = @searches.keys - values
    to_create = values - @searches.keys
    to_remove.each do |search|
      @searches[search].destroy
    end
    to_create.each do |search|
      Cisco::DnsDomain.new(search)
    end
  end

  # handle the hostname, i.e. if '' then destroy
  # all hostnames and do not create one
  def handle_hostname(value)
    @hostname ||= Cisco::HostName.hostname || {}
    if value == ''
      @hostname[@hostname.keys.first].destroy
    else
      @hostname[value].destroy if @hostname[value]
      Cisco::HostName.new(value)
    end
  end

  # handle the domain, i.e. if '' then destroy
  # all domains and do not create one
  def handle_domain(value)
    @domain ||= Cisco::DomainName.domainnames
    if value == ''
      @domain[@domain.keys.first].destroy
    else
      @domain[value].destroy if @domain[value]
      Cisco::DomainName.new(value)
    end
  end

  def validate_name(name)
    raise Puppet::ResourceError, '`name` must be `settings`' if name != 'settings'
  end
end
