define apache::csr_file (
  $publish_csr,
  $csrfile  
  )
  {
    file { "public CSR file for $name":
          ensure  => $publish_csr ? {
            false   => "absent",
            default => "present",
          },
          path    => $publish_csr ? {
            true    => "${apache::params::root}/${name}/htdocs/${name}.csr",
            false   => "${apache::params::root}/${name}/htdocs/${name}.csr",
            default => $publish_csr,
          },
          source  => "file://$csrfile",
          mode    => 640,
          seltype => "httpd_sys_content_t",
        } 
        
  }