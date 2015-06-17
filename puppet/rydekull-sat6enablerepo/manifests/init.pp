# == Class: sat6enablerepo
#
# Full description of class sat6enablerepo here.
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
#   Explanation of how this variable affects the function of this class and if
#   it has a default. e.g. "The parameter enc_ntp_servers must be set by the
#   External Node Classifier as a comma separated list of hostnames." (Note,
#   global variables should be avoided in favor of class parameters as
#   of Puppet 2.6.)
#
# === Examples
#
#  class { 'sat6enablerepo':
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
class sat6enablerepo {
  $script = '/root/scripts/sat6enablerepo.sh',
  $state_file = '/root/scripts/.sat6enablerepo.sh/state',
  $product_repos = 'Product-Name'
) {
  file { "${script}":
    owner  => root,
    group  => root,
    mode   => '0700',
    source => 'puppet:///modules/sat6enablerepo/sat6enablerepo.sh'
  }

  exec { 'sat6enablerepo.sh':
    command => "/root/scripts/sat6enablerepo.sh ${product_repos}",
    path    => '/usr/sbin:/sbin:/usr/bin:/bin',
    require => File["${script}"],
    unless  => "grep -c ${product_repos} ${state_file}"
  }
}
