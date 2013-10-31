# https://github.com/elasticsearch/puppet-elasticsearch
# Usage: class { 'ixaelastic': clustername => 'ELASTICCLUSTER' }

class ixaelastic($clustername) {

  package { 'openjdk-7-jdk':
    ensure => latest,
  }

## Plugins

  # You can view info at http://HOSTNAME:9200/_plugin/head/
  elasticsearch::plugin{'mobz/elasticsearch-head': module_dir => 'head'}

  # Performance information can be viewed at http://HOSTNAME:9200/_plugin/bigdesk/
  elasticsearch::plugin{'lukas-vlcek/bigdesk':     module_dir => 'bigdesk'}

## Main configuration

# Version can be locked with version => '0.90.3'

  class { 'elasticsearch':

    service_settings         => { 'ES_USER' => 'elasticsearch', 'ES_GROUP' => 'elasticsearch', 'RESTART_ON_UPGRADE' => 'true' },
    config                   => {
      'node'                 => {
        'name'               => $hostname
      },
      'index'                => {
        'number_of_replicas' => '1',
        'number_of_shards'   => '5'
      },
      'network'              => {
        'host'               => $::ipaddress
      },

      'cluster'             => {
        'name'              => $clustername,
      }
    }
  }
}
