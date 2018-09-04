#
# Cookbook:: chefserver
# Recipe:: default
#
# Copyright:: 2018, The Authors, All Rights Reserved.

apt_update 'all platforms' do
  frequency 86400
  action :periodic
end

# this depends on the version of postgresql installed as part of chef-server
postgres_version = '9.6'
pg_config_path = "/opt/opscode/embedded/postgresql/#{postgres_version}/bin/pg_config"

chef_ingredient 'chef-server' do
  version '12.17.33'
  action :install
  not_if { ::File.exists?(pg_config_path) }
end

chef_gem 'knife-ec-backup' do
  options "-- --with-pg-config=#{pg_config_path}"
  action :install
end

chef_gem 'knife-tidy' do
  action :install
end

directory '/root/bin' do
  recursive true
end

node.default['backups']['chef-server']['location'] = '/backups/chef-server'
node.default['backups']['chef-server']['s3bucket'] = 'tekno-fire-backups'

directory node['backups']['chef-server']['location'] do
  recursive true
end

backup_script = '/root/bin/chef-server-backup.sh'
template backup_script do
  source 'backup.sh.erb'
  owner 'root'
  group 'root'
  mode '0744'
  variables(
    backup_location: node['backups']['chef-server']['location'],
    backup_s3bucket: node['backups']['chef-server']['s3bucket']
  )
  action :create
end

cron_d 'backup chef-server' do
  minute '0'
  hour '*'
  path '$PATH:/usr/local/bin:/opt/opscode/embedded/bin'
  command backup_script
  action :create
end
