This is a [Vagrant](https://www.vagrantup.com/) Environment for an Intercepting and Caching Web Proxy using the [Squid Cache](http://www.squid-cache.org/) daemon.

This will configure Squid Cache as an Forward Proxy to:

* Cache resources.
* Proxy HTTP connections.
* Proxy HTTPS connections.
  * In order to cache resources, it will also intercept proxied HTTPS connections (aka intercept CONNECT tunnels). 
  * It uses its own "man in the middle" Certification Authority (CA) that you have to trust.


# Usage

Build and install the [Ubuntu Base Box](https://github.com/rgl/ubuntu-vagrant).

If you want to try a Windows client, you also need to build and install the Windows Base Box with:

```bash
git clone https://github.com/joefitzgerald/packer-windows
cd packer-windows
# this will take ages to build, so leave it running over night...
packer build windows_2012_r2.json
vagrant box add windows_2012_r2 windows_2012_r2_virtualbox.box
rm *.box
cd ..
```

Add the following entry to your `/etc/hosts` file:

```
10.10.10.222 proxy.example.com
```

Run `vagrant up proxy` to launch the proxy.

Once the proxy is up, configure the clients as described bellow.

Run `vagrant up ubuntu` to launch a pre-configured Ubuntu Linux that uses the proxy (see the [provision-ubuntu.sh](provision-ubuntu.sh) file).

Run `vagrant up windows` to launch a pre-configured Windows that uses the proxy (see the [provision-windows.ps1](provision-windows.ps1) file).


## Client Configuration

Most of the (unix) applications will look into the environment variables to figure out which proxy
should be used, for those, set the `http_proxy` and `https_proxy` environment variables as:

```bash
export http_proxy=http://proxy.example.com:3128
export https_proxy=$http_proxy
```

You can also set the `no_proxy` environment variable to prevent the proxy from being used to access specific domains, e.g.:

```bash
export no_proxy='localhost,127.0.0.1,localaddress,.localdomain.com'
```

You can also configure the proxy system-wise by placing the environment variables declarations inside a file, e.g. at `/etc/profile.d/proxy.sh`.

For Python and Java examples see the [provision-ubuntu.sh](provision-ubuntu.sh) file.


Under Windows, setting the Proxy is somewhat complicated... for the gory details see the [provision-windows-proxy.ps1](provision-windows-proxy.ps1) file.


## Trusting the Proxy CA

In order to use the proxy for HTTPS connections you also need to configure your system to trust the "man in the middle" proxy CA.

Under Ubuntu Linux this is done with:

```bash
cp /vagrant/tmp/squid-cache-ca.pem /usr/local/share/ca-certificates/squid-cache-ca.crt
update-ca-certificates
```

Under Windows this can be done with a PowerShell script:

```powershell
Import-Certificate `
    -FilePath C:/vagrant/tmp/squid-cache-ca.der `
    -CertStoreLocation Cert:/LocalMachine/Root
```


# References

* [Squid Cache: FAQ](http://wiki.squid-cache.org/SquidFaq)
* [Squid Cache: Configuration Examples](http://wiki.squid-cache.org/CategoryConfigExample)
* [Squid Cache: Dynamic SSL Certificate Generation](http://wiki.squid-cache.org/Features/DynamicSslCert)
* [Client Proxy Settings (Arch Linux Wiki)](https://wiki.archlinux.org/index.php/proxy_settings)
* [Ubuntu update-ca-certificates(8) man](http://manpages.ubuntu.com/manpages/xenial/man8/update-ca-certificates.8.html)
* [Squid Cache blog](https://squidproxy.wordpress.com/)
* [Squid Cache Continuous Integration (Jenkins) server](http://build.squid-cache.org/)
