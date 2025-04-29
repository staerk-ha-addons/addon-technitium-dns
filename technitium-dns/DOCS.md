# 🏠 Home Assistant Add-on: Technitium DNS Server

## 📝 TL;DR

Quick setup and best practices:

### DNS Server Setup

- Use this add-on as your primary DNS server
- Configure your router DNS to use `homeassistant.local` (or Home Assistant IP)

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

> This diagram illustrates how DNS queries flow through your network, showing both unencrypted (🔓) and encrypted (🔐) paths. Local devices can use either standard DNS or secure protocols (DoH/DoT/DoQ) to query the Technitium DNS Server, which then forwards requests to Cloudflare using selected dns_forwarders.

![DNS flow diagram][dns-diagram]

### Key Points

- 🏡 **Local Network**: Devices and router can use any supported protocol
- 🔒 **Security Options**: Choose between standard DNS or encrypted protocols
- 🌐 **Flexible Forwarding**: All protocols supported for external queries
- ⚡ **Modern Standards**: Full support for DoH, DoT, and DoQ

> [!NOTE]
> Port 53 (DNS) is always available for compatibility with standard clients.

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
> Only port 53 are enabled by default.

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

#### Reverse DNS Zone

```plaintext
# Create reverse zone for 192.168.1.0/24
Zone name: 1.168.192.in-addr.arpa

# PTR Records
10    PTR    server1.home.lab.
20    PTR    nas.home.lab.
30    PTR    printer.home.lab.
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

   - Ensure no other services use ports
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

[dns-diagram]: https://raw.githubusercontent.com/staerk-ha-addons/addon-technitium-dns/refs/heads/main/images/flowchart-dns.svg
[frenck]: https://github.com/frenck
[issue]: https://github.com/staerk-ha-addons/addon-technitium-dns/issues
[repository]: https://github.com/staerk-ha-addons/repository
[staerk]: https://github.com/staerk-ha-addons
[ha-addons]: https://addons.community/
[duckdns-link]: https://github.com/home-assistant/addons/tree/master/duckdns
[security-link]: https://www.home-assistant.io/docs/configuration/securing/#remote-access
