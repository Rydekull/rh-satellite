# == Class: apache
#
# Full description of class apache here.
#
# === Parameters
#
# Document parameters here.
#
# [*sample_parameter*]
#   Explanation of what this parameter affects and what it defaults to.
#   e.g. "Specify one or more upstream ntp servers as an array."
#
# === Variables
#
# Here you should define a list of variables that this module would require.
#
# [*sample_variable*]
#   Explanation of how this variable affects the funtion of this class and if
#   it has a default. e.g. "The parameter enc_ntp_servers must be set by the
#   External Node Classifier as a comma separated list of hostnames." (Note,
#   global variables should be avoided in favor of class parameters as
#   of Puppet 2.6.)
#
# === Examples
#
#  class { apache:
#    servers => [ 'pool.ntp.org', 'ntp.local.company.com' ],
#  }
#
# === Authors
#
# Author Name <author@domain.com>
#
# === Copyright
#
# Copyright 2015 Your name here, unless otherwise noted.
#
class apache (
  $content = 'Welcome to the site!',
  $running = 'running' 
) {

  package { 'httpd':
      ensure => installed,
  }

  file { '/var/www/html/index.html':
      owner => root,
      group => root,
      mode => 0644,
      content => $content,
      require => Package['httpd'],
  }

  service { 'httpd':
    ensure => $running,
    enable => true,
    require => Package['httpd'],
  }
}
