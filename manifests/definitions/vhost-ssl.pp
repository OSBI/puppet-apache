/*

== Definition: apache::vhost-ssl

Creates an SSL enabled virtualhost.

As it calls apache::vhost, most of the parameters are the same. A few
additional parameters are used to configure the SSL specific stuff.

An "ssl" subdirectory will be created in the virtualhost's directory. By
default, 3 files will be created in this subdirectory using the
generate-ssl-cert.sh script: $name.key (the private key), $name.crt (the
self-signed certificate) and $name.csr (the certificate signing request). An
additional file, ssleay.cnf, is used as a template by generate-ssl-cert.sh.

Parameters:
- *$name*: the name of the virtualhost. Will be used as the CN in the generated
  ssl certificate.
- *$ensure*: see apache::vhost
- *$config_file*: see apache::vhost
- *$config_content*: see apache::vhost
- *$htdocs*: see apache::vhost
- *$conf*: see apache::vhost
- *$readme*: see apache::vhost
- *$docroot*: see apache::vhost
- *$cgibin*: see apache::vhost
- *$user*: see apache::vhost
- *$admin*: see apache::vhost
- *$group*: see apache::vhost
- *$mode*: see apache::vhost
- *$aliases*: see apache::vhost. The generated SSL certificate will have this
  list as DNS subjectAltName entries.
- *$enable_default*: see apache::vhost
- *$ip_address*: the ip address defined in the <VirtualHost> directive.
  Defaults to "*".
- *$cert*: optional source URL of the certificate (see examples below), if the
  default self-signed generated one doesn't suit. This the certificate passed
  to the SSLCertificateFile directive.
- *$certkey*: optional source URL of the private key, if the default generated
  one doesn't suit. This the private key passed to the SSLCertificateKeyFile
  directive.
- *$cacert*: optional source URL of the CA certificate, if the defaults bundled
  with your distribution don't suit. This the certificate passed to the
  SSLCACertificateFile directive.
- *$certchain*: optional source URL of the CA certificate chain, if needed.
  This the certificate passed to the SSLCertificateChainFile directive.
- *$certcn*: set a custom CN field in your SSL certificate. Note that
  the CN field must match the FQDN of your virtualhost to avoid "certificate
  name mismatch" errors in the users browsers. Defaults to false, which means
  that $name will be used as the CN.
- *$days*: validity of the key/cert generated by generate-ssl-cert.sh. Defaults
  to 10 years.
- *$publish_csr*: if set to "true", the CSR will be copied in htdocs/$name.csr.
  If set to a path, the CSR will be copied into the specified file. Defaults to
  "false", which means dont copy the CSR anywhere.
- *$sslonly*: if set to "true", only the https virtualhost will be configured.
  Defaults to "false", which means the virtualhost will be reachable unencrypted
  on port 80, as well as encrypted on port 443.
- *ports*: array specifying the ports on which the non-SSL vhost will be
  reachable. Defaults to "*:80".
- *sslports*: array specifying the ports on which the SSL vhost will be
  reachable. Defaults to "*:443".
- *accesslog_format*: format string for access logs. Defaults to "combined".

Requires:
- Class["apache-ssl"]

Example usage:

  $sslcert_country="US"
  $sslcert_state="CA"
  $sslcert_locality="San Francisco"
  $sslcert_organisation="Snake Oil, Ltd."

  include apache::ssl

  apache::vhost-ssl { "foo.example.com":
    ensure => present,
    ip_address => "10.0.0.2",
    publish_csr => "/home/webmaster/foo.example.com.csr",
    days="30",
  }

  # go to https://bar.example.com/bar.example.com.csr to retrieve the CSR.
  apache::vhost-ssl { "bar.example.com":
    ensure => present,
    ip_address => "10.0.0.3",
    cert => "puppet:///exampleproject/ssl-certs/bar.example.com.crt",
    certchain => "puppet:///exampleproject/ssl-certs/quovadis.chain.crt",
    publish_csr => true,
    sslonly => true,
  }

*/
define apache::vhost-ssl (
  $ensure=present,
  $config_file="",
  $config_content=false,
  $htdocs=false,
  $conf=false,
  $readme=false,
  $docroot=false,
  $cgibin=true,
  $user="",
  $admin=$admin,
  $group="root",
  $mode=2570,
  $aliases=[],
  $ip_address="*",
  $cert=false,
  $certkey=false,
  $cacert=false,
  $certchain=false,
  $certcn=false,
  $days="3650",
  $publish_csr=false,
  $sslonly=false,
  $enable_default=true,
  $ports=['*:80'],
  $sslports=['*:443'],
  $accesslog_format="combined"
) {

  # these 2 values are required to generate a valid SSL certificate.
  if (!$sslcert_country) { $sslcert_country = "??" }
  if (!$sslcert_organisation) { $sslcert_organisation = "undefined organisation" }

  if ($certcn != false ) { $sslcert_commonname = $certcn }
  else { $sslcert_commonname = $name }

  include apache::params

  $wwwuser = $user ? {
    ""      => $apache::params::user,
    default => $user,
  }

  # used in ERB templates
  $wwwroot = $apache::params::root

  $documentroot = $docroot ? {
    false   => "${wwwroot}/${name}/htdocs",
    default => $docroot,
  }

  $cgipath = $cgibin ? {
    true    => "${wwwroot}/${name}/cgi-bin/",
    false   => false,
    default => $cgibin,
  }

  # define variable names used in vhost-ssl.erb template
  $certfile      = "${apache::params::root}/$name/ssl/$name.crt"
  $certkeyfile   = "${apache::params::root}/$name/ssl/$name.key"
  $csrfile       = "${apache::params::root}/$name/ssl/$name.csr"

  # By default, use CA certificate list shipped with the distribution.
  if $cacert != false {
    $cacertfile = "${apache::params::root}/$name/ssl/cacert.crt"
  } else {
    $cacertfile = $operatingsystem ? {
      /RedHat|CentOS/ => "/etc/pki/tls/certs/ca-bundle.crt",
      /Debian|Ubuntu/ => "/etc/ssl/certs/ca-certificates.crt",
    }
  }

  if $certchain != false {
    $certchainfile = "${apache::params::root}/$name/ssl/certchain.crt"
  }


  # call parent definition to actually do the virtualhost setup.
  apache::vhost {$name:
    ensure         => $ensure,
    config_file    => $config_file,
    config_content => $config_content ? {
      false => $sslonly ? {
        true => template("apache/vhost-ssl.erb"),
        default => template("apache/vhost.erb", "apache/vhost-ssl.erb"),
      },
      default      => $config_content,
    },
    aliases        => $aliases,
    htdocs         => $htdocs,
    conf           => $conf,
    readme         => $readme,
    docroot        => $docroot,
    user           => $wwwuser,
    admin          => $admin,
    group          => $group,
    mode           => $mode,
    enable_default => $enable_default,
    ports          => $ports,
    accesslog_format => $accesslog_format,
  }

  if $ensure == "present" {
    file { "${apache::params::root}/${name}/ssl":
      ensure => directory,
      owner  => "root",
      group  => "root",
      mode   => 700,
      seltype => "cert_t",
      require => [File["${apache::params::root}/${name}"]],
    }

    # template file used to generate SSL key, cert and csr.
    file { "${apache::params::root}/${name}/ssl/ssleay.cnf":
      ensure  => present,
      owner   => "root",
      mode    => 0640,
      content => template("apache/ssleay.cnf.erb"),
      require => File["${apache::params::root}/${name}/ssl"],
    }

    # The certificate and the private key will be generated only if $name.crt
    # or $name.key are absent from the "ssl/" subdir.
    # The CSR will be re-generated each time this resource is triggered.
    exec { "generate-ssl-cert-$name":
      command => "/usr/local/sbin/generate-ssl-cert.sh ${name} ${apache::params::root}/${name}/ssl/ssleay.cnf ${apache::params::root}/${name}/ssl/ ${days}",
      creates => $csrfile,
      notify  => Exec["apache-graceful"],
      require => [
        File["${apache::params::root}/${name}/ssl/ssleay.cnf"],
        File["/usr/local/sbin/generate-ssl-cert.sh"],
      ],
    }

    # The virtualhost's certificate.
    # Manage content only if $cert is set, else use the certificate generated
    # by generate-ssl-cert.sh
    file { $certfile:
      owner => "root",
      group => "root",
      mode  => 640,
      source  => $cert ? {
        false   => undef,
        default => $cert,
      },
      seltype => "cert_t",
      notify  => Exec["apache-graceful"],
      require => [File["${apache::params::root}/${name}/ssl"], Exec["generate-ssl-cert-${name}"]],
    }

    # The virtualhost's private key.
    # Manage content only if $certkey is set, else use the key generated by
    # generate-ssl-cert.sh
    file { $certkeyfile:
      owner => "root",
      group => "root",
      mode  => 600,
      source  => $certkey ? {
        false   => undef,
        default => $certkey,
      },
      seltype => "cert_t",
      notify  => Exec["apache-graceful"],
      require => [File["${apache::params::root}/${name}/ssl"], Exec["generate-ssl-cert-${name}"]],
    }

    if $cacert != false {
      # The certificate from your certification authority. Defaults to the
      # certificate bundle shipped with your distribution.
      file { $cacertfile:
        owner   => "root",
        group   => "root",
        mode    => 640,
        source  => $cacert,
        seltype => "cert_t",
        notify  => Exec["apache-graceful"],
        require => File["${apache::params::root}/${name}/ssl"],
      }
    }


    if $certchain != false {

      # The certificate chain file from your certification authority's. They
      # should inform you if you need one.
      file { $certchainfile:
        owner => "root",
        group => "root",
        mode  => 640,
        source  => $certchain,
        seltype => "cert_t",
        notify  => Exec["apache-graceful"],
        require => File["${apache::params::root}/${name}/ssl"],
      }
    }

    # put a copy of the CSR in htdocs, or another location if $publish_csr
    # specifies so.
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
     require => File[$csrfile],
    }
    
  }
}
