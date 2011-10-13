class apache::mod_proxy {

	apache::module {"proxy_ajp":
  		ensure  => present,
	}


}