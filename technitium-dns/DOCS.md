# 🏠 Home Assistant Add-on: Technitium DNS Server

## 📝 TL;DR

Quick setup and best practices:

### DNS Server Setup

- Use this add-on as your primary DNS server
- Configure your router DNS to use `homeassistant.local` (or Home Assistant IP)
- All ports (53, 443, 853) enabled by default
- Self-signed certificates generated automatically

### Secure DNS

- Use encrypted forwarding (DoH/DoT/DoQ) to Cloudflare
- Standard endpoints:
  - DNS: `homeassistant.local:53` or `<Home Assistant IP>`
  - DoH: `https://homeassistant.local/dns-query:443`
  - DoT: `tls://homeassistant.local:853`
  - DoQ: `quic://homeassistant.local:853`

### Local DNS Zone

```plaintext
# Quick zone setup
1. Access via the Web UI
2. Add zone: home.lab
3. Add records:
   nas.home.lab.     A     192.168.1.10
   printer.home.lab  A     192.168.1.20
```

## DNS Flow and Protocol Options

> This diagram illustrates how DNS queries flow through your network, showing both unencrypted (🔓) and encrypted (🔐) paths. Local devices can use either standard DNS or secure protocols (DoH/DoT/DoQ) to query the Technitium DNS Server, which then forwards requests to Cloudflare using selected forwarders.

![DNS flow diagram](images/flowchart-dns.svg)

### Key Points

- 🏡 **Local Network**: Devices and router can use any supported protocol
- 🔒 **Security Options**: Choose between standard DNS or encrypted protocols
- 🌐 **Flexible Forwarding**: All protocols supported for external queries
- ⚡ **Modern Standards**: Full support for DoH, DoT, and DoQ
- 🛡️ **End-to-End**: Possible to encrypt entire DNS path

> [!NOTE]
> Port 53 (DNS) is always available for compatibility with standard clients, while ports 443 (DoH) and 853 (DoT/DoQ) provide encrypted options for supported devices.

## 🔧 Configuration

> [!NOTE]
> When accessing the web interface for the first time:
>
> - **Username:** `admin`
> - **Password:** `admin`
>
> You will be required to change the password on your first login for security purposes.

### 🎯 Best Practices

This add-on is designed to be your primary DNS server, acting as a secure forwarding DNS server that queries external DNS providers using encrypted protocols (DoH or DoT).

Recommended setup:

1. Configure your router to use this DNS server (typically `homeassistant.local` or the IP of your Home Assistant)
2. Or configure individual devices to use this DNS server
3. Use encrypted forwarding (DoH, DoT, or DoQ) to upstream DNS providers
4. Keep query logging enabled for troubleshooting
5. Optionally, set up local DNS zones for your home lab (e.g., `home.lab`, `internal`)

> [!TIP]
> By using this add-on as your DNS server, you get:
>
> - Encrypted DNS queries to external providers
> - Local DNS resolution for your network
> - Query logging for troubleshooting
> - Ability to block unwanted domains
> - Faster response times through caching
> - Custom domain names for local devices
> - Service discovery through DNS records

### ⚙️ Add-on Configuration

The add-on can be configured via the Home Assistant frontend:

1. Navigate to Settings → Add-ons → Technitium DNS Server
2. Click the "Configuration" tab
3. Update the configuration as needed
4. Click "Save" to apply changes
5. Restart the add-on for the changes to take effect

### 🤖 Automatic Server Configuration

The add-on automatically configures Technitium DNS Server on startup using its API. This includes:

- DNS protocol settings (DoH, DoT, DoQ)
- SSL certificate paths and configurations
- DNS forwarder settings
- Query logging preferences
- Port configurations
- Web interface settings

> [!NOTE]
> Any manual changes made in the Technitium DNS Server web interface may be overwritten on add-on restart.

### 🔌 Port Configuration

| Port | Protocol | Description                        |
| ---- | -------- | ---------------------------------- |
| 53   | UDP      | Standard DNS service               |
| 853  | TCP      | DNS-over-TLS                       |
| 853  | UDP      | DNS-over-QUIC                      |
| 443  | TCP      | DNS-over-HTTPS (HTTP/1.1 + HTTP/2) |
| 443  | UDP      | DNS-over-HTTPS (HTTP/3)            |

To change port mappings:

1. Go to the add-on configuration page
2. Scroll to "Network" section
3. Click the port number you want to change
4. Enter new port number (e.g., `8853` for DNS-over-TLS)
5. Click "Save"

> [!NOTE]
> All ports are enabled by default. You only need to change ports if you have conflicts with other services.

### 🔒 SSL Certificate Setup

The add-on supports three certificate options for secure DNS protocols (DoH, DoT, and DoQ):

#### Option 1: Self-Signed Certificates (Default)

If no certificates are specified, the add-on automatically:

1. Generates self-signed certificates
2. Creates PKCS#12 file for Technitium DNS
3. Configures all necessary paths

> [!NOTE]
> Self-signed certificates are perfect for testing but may trigger security warnings in browsers and clients.

#### Option 2: Let's Encrypt Integration (Recommended for Production)

For secure remote access, Home Assistant recommends using Let's Encrypt certificates.

##### Duck DNS Add-on with Let's Encrypt

- Free alternative
- Requires manual setup
- [Duck DNS Add-on documentation][duckdns-link]

> [!IMPORTANT]
> For detailed information about securing remote access, see the [Home Assistant Security Documentation][security-link].

#### Option 3: Custom Certificates

You can use your own certificates by:

1. Placing them in the `/ssl` directory
2. Update path in configuration
3. Restart this add-on

> [!TIP]
> Regardless of the option chosen, the add-on handles:
>
> - PKCS#12 conversion
> - File permissions
> - Certificate monitoring
> - Service restarts

### 🌐 DNS Protocol Configuration

#### DNS-over-HTTPS (DoH)

1. Default ports:

   - 443/TCP for HTTP/1.1 + HTTP/2
   - 443/UDP for HTTP/3

2. Endpoint URLs:
   - Standard: `https://homeassistant.local:443/dns-query`
   - Custom domain: `https://your-domain:443/dns-query`
   - Custom port: `https://homeassistant.local:port/dns-query`

Example client configurations:

```bash
# Chrome/Brave/Edge browsers
chrome://settings/security → Use secure DNS → Custom → Enter DoH URL:
https://homeassistant.local/dns-query

# Firefox
Settings → Network Settings → Enable DNS over HTTPS → Custom:
https://homeassistant.local/dns-query

# iOS/macOS
Settings → Wi-Fi → DNS → Configure DNS:
https://homeassistant.local/dns-query

# Android 9+
Settings → Network & Internet → Private DNS → Enter hostname:
homeassistant.local

# Windows 11
Settings → Network & Internet → Wi-Fi/Ethernet → Hardware Properties → DNS:
https://homeassistant.local/dns-query

# Ubuntu/Debian (systemd-resolved)
sudo tee /etc/systemd/resolved.conf << EOF
[Resolve]
DNS=homeassistant.local
DNSOverTLS=yes
EOF
sudo systemctl restart systemd-resolved

# Pi-hole
Settings → DNS → Upstream DNS Servers → Add Custom:
tls://homeassistant.local:853

# OPNsense/pfSense
System → Settings → General → DNS Server Settings:
https://homeassistant.local/dns-query

# AdGuard Home
Settings → DNS Settings → Upstream DNS Servers:
quic://homeassistant.local:853
```

#### DNS-over-TLS (DoT)

1. Default port: 853/TCP

2. Endpoint format:
   - Standard: `tls://homeassistant.local:853`
   - Custom domain: `tls://your-domain:853`
   - Custom port: `tls://homeassistant.local:port`

#### DNS-over-QUIC (DoQ)

1. Default port: 853/UDP

2. Endpoint format:
   - Standard: `quic://homeassistant.local:853`
   - Custom domain: `quic://your-domain:853`
   - Custom port: `quic://homeassistant.local:port`

> [!TIP]
> Test your DNS endpoints:
>
> ```bash
> # Test DoH
> curl -H 'accept: application/dns-json' \
>   'https://homeassistant.local/dns-query?name=example.com&type=A'
>
> # Test DoT
> kdig @853 example.com +tls-host=homeassistant.local
>
> # Test DoQ
> dog example.com @quic://homeassistant.local:853
> ```

The add-on automatically configures all enabled protocols based on your settings. No manual configuration in the Technitium web interface is required.

### 🏠 Local DNS Zones

Technitium DNS Server can host your own DNS zones for your home lab environment.

#### Setting up a Local Zone

1. Access the web interface at `http://homeassistant.local:5380`
2. Navigate to Zones → Add Zone
3. Enter your desired domain (e.g., `home.lab`, `local.network`)
4. Click "Add"

Example records for your home lab:

```plaintext
# A Records (IPv4)
server1.home.lab.    A    192.168.1.10
nas.home.lab.        A    192.168.1.20
printer.home.lab.    A    192.168.1.30

# CNAME Records (Aliases)
www.home.lab.        CNAME    server1.home.lab.
files.home.lab.      CNAME    nas.home.lab.

# TXT Records (Service Information)
home.lab.            TXT    "v=spf1 ip4:192.168.1.0/24 -all"
_service.home.lab.   TXT    "location=basement rack=1"
```

### 🏗️ Advanced Configuration

1. **Reverse DNS Zone**

   ```plaintext
   # Create reverse zone for 192.168.1.0/24
   Zone name: 1.168.192.in-addr.arpa

   # PTR Records
   10    PTR    server1.home.lab.
   20    PTR    nas.home.lab.
   30    PTR    printer.home.lab.
   ```

2. **Split DNS**

   - Create different views for internal/external access
   - Navigate to DNS Server → Settings → Advanced
   - Add networks under "Allow Recursion Networks"

3. **Dynamic DNS Updates**

   ```bash
   # Update record using curl
   curl -X POST "http://homeassistant.local:5380/api/zones/updateRecord" \
     -H "Content-Type: application/json" \
     -d '{
       "token": "your-api-token",
       "domain": "device.home.lab",
       "type": "A",
       "value": "192.168.1.100"
     }'
   ```

> [!TIP]
> Best practices for local zones:
>
> - Use a dedicated domain suffix (e.g., `.home.lab`, `.internal`)
> - Document all DNS records
> - Use meaningful naming conventions
> - Set appropriate TTL values
> - Regular backups of zone files

## 🔍 Troubleshooting

### ❌ Common Issues

1. **Certificate Issues**

   - Check certificate paths are correct
   - Verify certificate permissions
   - Check logs for certificate conversion errors

2. **Port Conflicts**

   - Ensure no other services use ports 53, 443, or 853
   - Try alternative ports if needed
   - Check firewall settings

3. **DNS Resolution Problems**
   - Verify forwarder settings
   - Check DNS server logs
   - Test with `dig` or `nslookup`

## 💡 Support

Got questions?

- Create an [issue on GitHub][issue] for bug reports, feature requests, or questions
- Add a ⭐️ [star on GitHub][repository] to support the project

## 🤝 Contributing

This is an active open-source project. We welcome contributions from anyone interested in using or improving the code:

- Fork the repository
- Make your changes
- Submit a pull request
- Follow the coding standards

## 👥 Authors & Contributors

The original setup of this repository is by [Jeppe Stærk][staerk].

## 🙏 Acknowledgments

Special thanks to [Franck Nijhof][frenck] and the [Home Assistant Community Add-ons][ha-addons] project for their invaluable work. This add-on heavily relies on their foundation:

- Base container images
- CI, workflows and best practices
- Readme and docs templates

Their open-source contributions make add-ons like this possible.

## ⚠️ Disclaimer

This is a third-party add-on for Home Assistant and not an official add-on. It is provided as-is, without warranty of any kind. While care has been taken in its development, use it at your own risk. Always ensure you have proper backups before making changes to your Home Assistant DNS settings. This add-on is not affiliated with Technitium Software.

## 📄 License

MIT License - Copyright (c) 2025 Jeppe Stærk

[frenck]: https://github.com/frenck
[issue]: https://github.com/staerk-ha-addons/addon-technitium-dns/issues
[repository]: https://github.com/staerk-ha-addons/repository
[staerk]: https://github.com/staerk-ha-addons
[ha-addons]: https://addons.community/
[duckdns-link]: https://github.com/home-assistant/addons/tree/master/duckdns
[security-link]: https://www.home-assistant.io/docs/configuration/securing/#remote-access
