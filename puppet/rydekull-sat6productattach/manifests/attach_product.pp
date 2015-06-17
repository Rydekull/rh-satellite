  define sat6productattach::attach_product {
    $product = $name
    $script = $sat6productattach::script
    $state_file = $sat6productattach::state_file

    exec { "${script}":
      command => "${script} ${product}",
      path    => '/usr/sbin:/sbin:/usr/bin:/bin',
      require => File["${script}"],
      unless  => "grep -c ${product} ${state_file}"
    }
  }

