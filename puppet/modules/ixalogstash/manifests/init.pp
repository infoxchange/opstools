# Class: ixalogstash
#
# Installs & configures logstash, RabbitMQ, Kibana
# Tested on Debian 7, Puppet 3.3
#
# Requirements:
#
# https://github.com/bloonix/logstash-delete-index
# https://github.com/puppetlabs/puppetlabs-rabbitmq (optional)
# https://github.com/logstash/puppet-logstash
# https://github.com/puppetlabs/puppetlabs-vcsrepo
# A webserver class of some sort
# Some initiative and a good strong coffee

class ixalogstash($domain = 'KIBANA.SOMECOMPANY.com', $logserver = 'LOGSTASH.SOMECOMPANY.com', $kibanarepo = 'GIT.SOMECOMPANY.com/kibana.git', $elasticcluster = 'ELASTICCLUSTER', $wwwpath = '/usr/share/nginx/html') {

  # required by logstash-delete-index.pl
  package { 'libjson-perl':
    ensure => latest,
  }

  # source: https://github.com/bloonix/logstash-delete-index
  file { '/usr/local/bin/logstash-delete-index.pl':
    ensure => present,
    source => 'puppet:///modules/ixalogstash/logstash-delete-index.pl',
    owner  => 'root',
    group  => 'root',
    mode   => '0700',
  }

  # delete logstash indexes in elasticsearch older than 5 days
  cron { 'logstash-delete-index':
    command  => "/usr/local/bin/logstash-delete-index.pl logstash-delete-index -H $logserver:9200 -d 5 -r",
    user     => 'root',
    month    => '*',
    monthday => '*',
    hour     => '23',
    minute   => '59',
  }

  file { "$wwwpath/$domain/config.js":
    ensure  => file,
    source  => 'puppet:///modules/ixalogstash/config.js',
    owner   => 'root',
    group   => 'root',
    require => Vcsrepo["$wwwpath/$domain"],
  }

  # kibana website deployment
  vcsrepo { "$wwwpath/$domain":
    ensure   => present,
    provider => git,
    source   => "ssh://$kibanarepo",
    notify   => Service['nginx'],
  }

  # We have an Nginx class for hosting basic websites, I'm assuming you have something similar
  ixanginx::staticsite { $domain: ensure => 'enabled', doc_root => "$wwwpath/$domain" }


  # RabbitMQ Server (Optional)
  # https://github.com/puppetlabs/puppetlabs-rabbitmq
  class { 'rabbitmq':
    port                      => '5672',
    environment_variables     => {
      'RABBITMQ_NODENAME'     => $logserver,
      'RABBITMQ_SERVICENAME'  => 'RabbitMQ',
    }
  }

  # https://github.com/logstash/puppet-logstash
  class { 'logstash':
    java_install  => true,
    provider      => 'package',
  }

  # Example RabbitMQ Input
  logstash::input::rabbitmq { 'logstash':
    exchange  => 'amq.direct',
    type      => 'rabbitmq',
    exclusive => false,
    key       => 'logstash',
    host      => '127.0.0.1',
    queue     => 'logstash'
  }

  # Example Apache Combined Log Format Input
  logstash::input::tcp { 'apachecombined':
    type => 'apachecombined',
    port => '5544',
  }

  logstash::filter::grok { ['apachecombined']:
    pattern => ["%{COMBINEDAPACHELOG}"],
  }

  # Example Generic TCP Input
  logstash::input::tcp { 'tcplogs':
    type => 'tcplogs',
    port => '5547',
  }

  # Example Generic Syslog Input
  logstash::input::syslog { 'rsyslog':
    type => 'rsyslog',
    port => '5548',
  }

  # Example Mail Log Input
  logstash::input::syslog { 'maillog':
    type => 'maillog',
    port => '5549',
  }

  # Output everything to elasticsearch
  logstash::output::elasticsearch { 'logstash-elasticsearch':
    cluster   => $elasticcluster,
  }

}