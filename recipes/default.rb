#
# Cookbook Name:: rsyslog
# Recipe:: default
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

#already made on client/server recipe, but in case default recipe is include
if node["syslog_ng"] 
	if (node["syslog_ng"]["isrunning"] == true)
		Chef::Log.info("RSYSLOG default:This server is a syslog-ng, rsyslog is not installed")
		return
	end
end

Chef::Log.info("RSYSLOG default:Rsyslog is being installed now.")
package 'rsyslog'
package 'rsyslog-relp' if node['rsyslog']['use_relp']

directory '/etc/rsyslog.d' do
	owner 'root'
	group 'root'
	mode  '0755'
end

directory '/var/spool/rsyslog' do
	owner 'syslog'
	group 'adm'
	mode  '0755'
end

# Our main stub which then does its own rsyslog-specific
# include of things in /etc/rsyslog.d/*
template '/etc/rsyslog.conf' do
	source  'rsyslog.conf.erb'
	owner   'root'
	group   'root'
	mode    '0644'
	notifies :restart, "service[#{node['rsyslog']['service_name']}]"
end

template '/etc/rsyslog.d/50-default.conf' do
	source  '50-default.conf.erb'
	owner   'root'
	group   'root'
	mode    '0644'
	notifies :restart, "service[#{node['rsyslog']['service_name']}]"
end

# syslog needs to be stopped before rsyslog can be started on RHEL versions before 6.0
if platform_family?('rhel') && node['platform_version'].to_i < 6
	service 'syslog' do
		action [:stop, :disable]
	end
end

service node['rsyslog']['service_name'] do
	supports :restart => true, :reload => true, :status => true
	action   [:enable, :start]
end
