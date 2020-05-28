# Traefik 

## Intro
Traefik is a reverse proxy, this means it sits in-between your servers and the internet. Often these reverse proxies also, just like traefik, function as SSL endpoints, this means they encrypt the traffic comming from/to your servers.

Standalone without docker Traefik is quite a challenge to setup right. JailMan tries to make it as easy as possible for your, by doing most of the groundwork and tweaking for you.
This also means we don't support all features of traefik. We use traefik as a central reverse proxy and ssl termination endpoint for all our jails. Nothing more, Nothing less.

To make things as streamlined as possible we had to make choices. Hence we only support DNS-verification for certificate generation. No http(s) verification is included.

## Configuration Parameters

Traefik requires a little more variables to setup in config.yml than other jails.
Here is the list of configuration parameters:

- dns_provider: The DNS provider you are using to verify ownership of the domain. This is required to get a letsencrypt certificate. We only support DNS-verification for certificate generation.
- domain_name: The domain name you want to use to connect to traefik. Needs to be accessable at the DNS provider (cert_provider) with the DNS credentials (cert_env) provided.
- cert_email: The email adress to link to the Lets Encrypt certificate
- dashboard: set to "true" to enable the dashboard.
- cert_env: For DNS verification we need login credentials and need to write those in a way Traefik understands. You can find the requirements for your DNS provider at the traefik website: https://docs.traefik.io/https/acme/
You will need to use 2 spaces(!) in front and enter them below this configuration option. Like this:
```
	cert_env:
	  CF_API_EMAIL: fake@email.adress
	  CF_API_KEY: ftyhsfgufsgusfgjhsfghjsgfhj
```

### Advanced settings

These settings are normally not required or normally used, but might come in handy for advanced users.
- cert_staging: Set this to "true" if you want to test it out using the Lets Encrypt staging server. Set it to "false" or (preferable) just leave it out to use the production server.
- cert_wildcard_domain: If you want to generate wildcard certificates, please enter the domain name here, without `*.` (ex. `test.testdomain.com`)
- cert_strict_sni: set to "true" to enable strict SNI checking, set to false or (preferably) just leave it out to disable strict-SNI checking.


## Installing

Just do the usual install procedures, like any other JailMan jail.
If you have done it right, you can reach the Traefik admin dashboard using the domain_name you entered in the config file.

## Usages

Currently we haven't migrated all jails to sit behind the traefik reverse proxy yet. We also didn't add security for the dashboard yet.
Thus it is currently not usable out of the box, although the Traefik installation is fully configured.

Although the web interface shows port 9080 and 9443, Traefik is actually also listening on the (more common) port 80 and 443, also known as normal (without port in the URL) http and https ports.