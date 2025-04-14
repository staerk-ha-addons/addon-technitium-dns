# Home Assistant Add-on: Technitium DNS Server

## Configuration

### Add-on Configuration

The add-on can be configured via the Home Assistant frontend:

1. Navigate to Settings → Add-ons → Technitium DNS Server.
2. Click the "Configuration" tab.
3. Update the configuration as needed.
4. Click "Save" to apply changes.
5. Restart the add-on for the changes to take effect.

### Port Configuration

> [!NOTE]
> By default, only port 53/UDP is enabled.

The add-on provides the following ports:

| Port | Protocol | Description                        |
| ---- | -------- | ---------------------------------- |
| 53   | UDP      | Standard DNS service               |
| 853  | UDP      | DNS-over-QUIC                      |
| 853  | TCP      | DNS-over-TLS                       |
| 443  | UDP      | DNS-over-HTTPS (HTTP/3)            |
| 443  | TCP      | DNS-over-HTTPS (HTTP/1.1 + HTTP/2) |

To enable additional ports or change port mappings:

1. Go to the add-on configuration page in Home Assistant.
2. Scroll down to the "Network" section.
3. Click "Show disabled ports."
4. Enable the desired ports by clicking the toggle switch.
5. To use a different port number:
   - Click on the port number.
   - Enter your desired port number (e.g., change `853` to `8853` to run DNS-over-TLS on port 8853).
6. Click "Save" to apply changes.

> [!IMPORTANT]
> After enabling or changing ports, you'll also need to configure the corresponding services (DoH, DoT, DoQ) in the Technitium DNS web interface.

The web interface is available via Ingress in your Home Assistant frontend.

### SSL Certificate Setup

> [!WARNING]
> If you're only using standard DNS or other protocols, you can skip this section.
>
> This section covers advanced setup for DNS-over-HTTPS (DoH), DNS-over-TLS (DoT) and DNS-over-QUIC (DoQ). Only proceed if you're comfortable with SSL certificates and DNS configuration.
>
> If you plan to use DNS-over-HTTPS (DoH), DNS-over-TLS (DoT) and/or DNS-over-QUIC (DoQ), ensure that port 443 and/or 853 is not already in use by Home Assistant or other services. Home Assistant typically uses port 443 for its own HTTPS access, so you may need to:
>
> - Run on a different port see: [Port Configuration](#port-configuration)
> - Configure a reverse proxy to handle the routing

To set up SSL certificates using the Home Assistant Let's Encrypt add-on:

1. Install the Let's Encrypt add-on from the official add-on store.
2. Open the Let's Encrypt add-on configuration page.
3. Click the "Configuration" tab.
4. Configure the following settings:
   - **Domain:** Enter your domain (e.g., `your.domain.com`)
   - **Email:** Enter your email address for certificate notifications
   - **Certificate File:** Leave as default (`fullchain.pem`)
   - **Private Key File:** Leave as default (`privkey.pem`)
5. Select your preferred challenge type:
   - **DNS challenge:** If you're using a DNS provider (like Cloudflare)
6. Click "Save" to apply the configuration.
7. Start the Let's Encrypt add-on.
8. Check the add-on logs to confirm certificate generation.

Once the certificates are generated, you have two options to use them with Technitium DNS:

#### Automatic PKCS #12 Certificate Generation (Recommended)

1. Go to the Technitium DNS Server add-on configuration.
2. Enable `generate_ssl_pfx` by setting it to `true`.
3. Set a secure `ssl_pfx_password` (recommended).
4. (Optional) Override certificate paths if needed:
   - **certfile:** Path to your full chain certificate (default: `/ssl/fullchain.pem`)
   - **keyfile:** Path to your private key (default: `/ssl/privkey.pem`)
   - **pkcs12file:** Output path for generated PKCS #12 certificate (default: `/config/ssl/technitium.pfx`)
5. Save the configuration and restart the add-on.
6. The PKCS #12 certificate will be automatically generated at the configured `pkcs12file` location.

This add-on includes built-in automatic management of your TLS/SSL certificate used by Technitium DNS Server.

When enabled, the add-on will:

- Automatically generate a PKCS #12 certificate (`.pfx` file) from your configured `certfile` and `keyfile` (usually provided by the Home Assistant Let's Encrypt add-on).
- Monitor the certificate files for changes.
- Automatically regenerate the `.pfx` file when certificates are renewed or about to expire.
- Automatically restart Technitium DNS Server to ensure it loads the updated certificate without manual intervention.

This ensures Technitium DNS Server always uses the latest valid certificate with no manual steps required after initial configuration.

#### Manual Certificate Setup

If you prefer to manage certificates manually, you can convert the Let's Encrypt certificates yourself and place them in the appropriate location.

### Configuring DNS-over-HTTPS

After generating the PKCS #12 certificate, follow these steps to configure DNS-over-HTTPS:

1. Enable the HTTPS port in the add-on:

   - Go to the add-on's configuration page.
   - Scroll down to the "Network" section.
   - Click "Show disabled ports."
   - Enable port 443 (both TCP and UDP).
   - Click "Save."
   - Restart the add-on.

2. Configure the web service settings in Technitium DNS Server:

   - Go to Settings → Web Service.
   - Under "HTTPS Options":
     - Enable HTTPS.
     - Enable HTTP/3 (optional).
     - ⚠️ **Do NOT enable** "HTTP to HTTPS Redirect" as it will break the Home Assistant ingress functionality.
   - Set "TLS Certificate File Path" to the value of `pkcs12file` (default: `/config/ssl/technitium.pfx`).
   - Enter your certificate password in "TLS Certificate Password."
   - Click "Save" to apply changes.

3. Enable DNS-over-HTTPS in Settings → Optional Protocols:
   - Enable DNS over HTTPS (DoH).
   - Click "Save."

Your DNS-over-HTTPS service should now be ready to use. The default ports are:

- **DNS-over-HTTPS:** 443 (TCP/UDP)

Note: The DoH endpoint will be available at `https://your.domain.com/dns-query`.

## Support

Got questions? You have several options to get them answered:

- The [Home Assistant Discord Chat Server][discord].
- The Home Assistant [Community Forum][forum].
- Join the [Reddit subreddit][reddit] in [/r/homeassistant][reddit].

In case you've found a bug, please [open an issue on our GitHub][issue].

## Contributing

This is an active open-source project. We welcome contributions from anyone interested in using or improving the code.

## Authors & Contributors

The original setup of this repository is by [Jeppe Stærk][staerk].

## Acknowledgments

Special thanks to [Franck Nijhof][frenck] and the [Home Assistant Community Add-ons][ha-addons] project for their invaluable work. This add-on heavily relies on their foundation:

- Base container images
- CI, workflows and best practices
- Readme and docs templates

Their open-source contributions make add-ons like this possible.

## License

MIT License

Copyright (c) 2025 Jeppe Stærk

[discord]: https://discord.gg/c5DvZ4e
[forum]: https://community.home-assistant.io
[frenck]: https://github.com/frenck
[issue]: https://github.com/staerk-ha-addons/addon-technitium-dns/issues
[reddit]: https://reddit.com/r/homeassistant
[staerk]: https://github.com/staerk-ha-addons
[ha-addons]: https://addons.community/
