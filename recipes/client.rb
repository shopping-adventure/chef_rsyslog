#
# Cookbook Name:: rsyslog
# Recipe:: client
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

#if (node.chef_environment == "qa")
#	Chef::Log.info("RSYSLOG :This environnement is not good, rsyslog is not installed")
#	return
#end


# Do not run this recipe if the server attribute is set
if node["syslog_ng"]
	if node["syslog_ng"]["isrunning"] 
		Chef::Log.info("RSYSLOG :This server is a syslog-ng, rsyslog is not installed")
		return
	end
end

if node['rsyslog']['server']
	Chef::Log.info("RSYSLOG client :This server is a rsyslog server, client rsyslog is not installed, you probably include recipes client/server on the same node")
	return
end

Chef::Log.info("RSYSLOG client :Server is a rsyslog client")

include_recipe 'rsyslog::default'
# On Chef Solo, we use the node['rsyslog']['server_ip'] attribute, and on
# normal Chef, we leverage the search query.
if Chef::Config[:solo]
	if node['rsyslog']['server_ip']
		rsyslog_servers = Array(node['rsyslog']['server_ip'])
	else
		Chef::Application.fatal!("Chef Solo does not support search. You must set node['rsyslog']['server_ip']!")
	end
else
	results = search(:node, "chef_environment:#{node.chef_environment} AND #{node['rsyslog']['server_search']}").map { 
		#|n| n['ipaddress'] 
		|n| (n.attribute?('cloud') && n['cloud']['local_ipv4']) ? n['cloud']['local_ipv4'] : n['ipaddress']

	}
	rsyslog_servers = Array(node['rsyslog']['server_ip']) + Array(results)
end

if rsyslog_servers.empty?
	Chef::Application.fatal!('The rsyslog::client recipe was unable to determine the remote syslog server. Checked both the server_ip attribute and search!')
end

remote_type = node['rsyslog']['use_relp'] ? 'relp' : 'remote'

#unless (node.chef_environment == "qa")
template '/etc/rsyslog.d/49-client-remote.conf' do
	source    "49-client-#{remote_type}.conf.erb"
	owner     'root'
	group     'root'
	mode      '0644'
	variables :servers => rsyslog_servers
	notifies  :restart, "service[#{node['rsyslog']['service_name']}]"
	only_if   { node['rsyslog']['remote_logs'] }
end


db = []
search(:apps) do |app|
	(app["server_roles"] & node.run_list.roles).each do |app_role|
	#db << data_bag_item("apps",app)
	db << app
	end
end
template '/etc/rsyslog.d/20-client-file-send.conf' do
	source    "20-client-file-send.conf.erb"
	owner     'root'
	group     'root'
	mode      '0644'
	variables :db => db 
	notifies  :restart, "service[#{node['rsyslog']['service_name']}]"
end
#end

file '/etc/rsyslog.d/server.conf' do
	action   :delete
	notifies :reload, "service[#{node['rsyslog']['service_name']}]"
end
