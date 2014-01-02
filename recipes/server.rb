#
# Cookbook Name:: rsyslog
# Recipe:: server
#
# Copyright 2009-2013, Opscode, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# Manually set this attribute
if node["syslog-ng"]
	Chef::Log.info("RSYSLOG :This server is a syslog-ng, rsyslog is not installed")
	return
end

#if (node["chef_environment"] == "qa")
#	Chef::Log.info("RSYSLOG :This environnement is not good, rsyslog is not installed")
#	return
#end

node.set['rsyslog']['server'] = true
Chef::Log.info("RSYSLOG server:This server is a rsyslog server")

include_recipe 'rsyslog::default'

directory node['rsyslog']['log_dir'] do
	owner    node['rsyslog']['user']
	group    node['rsyslog']['group']
	mode     '0755'
	recursive true
end

#node which have log over imfile module
imfilenode = search(:node, "imfile:files AND chef_environment:#{node.chef_environment}")
runitnode = search(:node, "runit:apps AND chef_environment:#{node.chef_environment}")
apps = []
db = []
apps = search(:apps) 

template '/etc/rsyslog.d/35-server-default-per-host.conf' do
	source   '35-server-default-per-host.conf.erb'
	owner    'root'
	group    'root'
	mode     '0644'
	notifies :restart, "service[#{node['rsyslog']['service_name']}]"
end
template '/etc/rsyslog.d/30-server-apps-per-host.conf' do
	source   '30-server-apps-per-host.conf.erb'
	owner    'root'
	group    'root'
	mode     '0644'
	variables :imfilenode => imfilenode, :runitnode => runitnode, :apps => apps
	notifies :restart, "service[#{node['rsyslog']['service_name']}]"
end

template '/etc/rsyslog.d/10-template.conf' do
	source   '10-template.conf.erb'
	owner    'root'
	group    'root'
	mode     '0644'
	notifies :restart, "service[#{node['rsyslog']['service_name']}]"
end

file '/etc/rsyslog.d/remote.conf' do
	action   :delete
	notifies :reload, "service[#{node['rsyslog']['service_name']}]"
	only_if  { ::File.exists?('/etc/rsyslog.d/remote.conf') }
end

logrotate_app 'kbrw_dotlog-rotate' do
	cookbook  'logrotate'
	path    "#{node['rsyslog']['log_dir']}/*/*/*/*/*/*.log"
	frequency 'daily'
	sharedscripts
	postrotate '	/usr/sbin/service rsyslog reload >/dev/null 2>&1'
	rotate    30
	options   ['missingok','notifempty','compress', 'dateext' ]
	create    '644 syslog adm'
end


logrotate_app 'kbrw_sysloglog-rotate' do
	cookbook  'logrotate'
	path    "#{node['rsyslog']['log_dir']}/*/*/*/*/*/syslog"
	frequency 'daily'
	sharedscripts
	postrotate '	/usr/sbin/service rsyslog reload >/dev/null 2>&1'
	rotate    30
	options   ['missingok','notifempty','compress', 'dateext' ]
	create    '644 syslog adm'
end
logrotate_app 'kbrw_messagelog-rotate' do
	cookbook  'logrotate'
	path    "#{node['rsyslog']['log_dir']}/*/*/*/*/*/messages"
	frequency 'daily'
	sharedscripts
	postrotate '	/usr/sbin/service rsyslog reload >/dev/null 2>&1'
	rotate    30
	options   ['missingok','notifempty','compress', 'dateext' ]
	create    '644 syslog adm'
end

cron 'today_systemlogs' do
	minute "1"
	hour "0"
	shell "/bin/bash"
	path "/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin"
	command "rm -f #{node['rsyslog']['log_dir']}/System_today && ln -s `date +\\%Y/\\%m/\\%d`/SYSTEM #{node['rsyslog']['log_dir']}/System_today"
end

cron 'today_appslogs' do
	minute "1"
	hour "0"
	shell "/bin/bash"
	path "/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin"
	command "rm -f #{node['rsyslog']['log_dir']}/Apps_today && ln -s `date +\\%Y/\\%m/\\%d`/APPS #{node['rsyslog']['log_dir']}/Apps_today"
end
