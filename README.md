# Home Assistant Add-on: Technitium DNS Server

[![GitHub Release][releases-shield]][releases]
![Project Stage][project-stage-shield]
[![License][license-shield]](LICENSE.md)

![Supports aarch64 Architecture][aarch64-shield]
![Supports amd64 Architecture][amd64-shield]

A fully featured DNS server for Home Assistant with advanced capabilities including DNS-over-HTTPS, DNS-over-TLS, and DNS-over-QUIC.

## Disclaimer

This is a third-party add-on for Home Assistant and not an official add-on. It is provided as-is, without warranty of any kind. While care has been taken in its development, use it at your own risk. Always ensure you have proper backups before making changes to your Home Assistant DNS settings. This add-on is not affiliated with Technitium Software.

## About

Technitium DNS Server is a cross-platform open source DNS server that can be used for self-hosting a DNS server for privacy & security. This add-on integrates it seamlessly with Home Assistant, providing a feature-rich DNS solution for your home network.

## Features

- Complete DNS solution for your home network
- Modern DNS protocols support:
  - DNS-over-HTTPS (DoH)
  - DNS-over-TLS (DoT)
  - DNS-over-QUIC
- Built-in DNS filtering and blocking
- DNS caching for improved performance
- Custom DNS records and zones
- DNSSEC validation
- Web interface for easy management
- Integration with Home Assistant's SSL certificates

## Installation

1. Click the Home Assistant My button below to add the repository to your Home Assistant instance.

   [![Open your Home Assistant instance and show the add add-on repository dialog with a specific repository URL pre-filled.](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2Fstaerk-ha-addons%2Faddon-technitium-dns)

2. Find the "Technitium DNS Server" add-on in the add-on store.
3. Click install to download the add-on.
4. Click Start to start the add-on.
5. Check the logs of the add-on to see if everything went well.

### Default Credentials

When accessing the web interface for the first time, use these credentials:

- Username: `admin`
- Password: `admin`

⚠️ **Important**: You will be required to change the password on your first login for security purposes.

## Support

Got questions?

You have several options to get them answered:

- The [Home Assistant Discord Chat Server][discord].
- The Home Assistant [Community Forum][forum].
- Join the [Reddit subreddit][reddit] in [/r/homeassistant][reddit]

In case you've found a bug, please [open an issue on our GitHub][issue].

## Contributing

This is an active open-source project. We are always open to people who want to use the code or contribute to it.

## Authors & contributors

The original setup of this repository is by [Jeppe Stærk][staerk].

## Acknowledgments

Special thanks to the [Home Assistant Community Add-ons][ha-addons] project for their invaluable work. This add-on heavily relies on their foundation:

- Base container images
- CI workflows and best practices

Their open-source contributions make add-ons like this possible.

## License

MIT License

Copyright (c) 2024 Jeppe Stærk

[aarch64-shield]: https://img.shields.io/badge/aarch64-yes-green.svg
[amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg
[discord]: https://discord.gg/c5DvZ4e
[forum]: https://community.home-assistant.io
[issue]: https://github.com/staerk-ha-addons/addon-technitium-dns/issues
[reddit]: https://reddit.com/r/homeassistant
[releases-shield]: https://img.shields.io/github/release/staerk-ha-addons/addon-technitium-dns.svg
[releases]: https://github.com/staerk-ha-addons/addon-technitium-dns/releases
[staerk]: https://github.com/staerk-ha-addons
[project-stage-shield]: https://img.shields.io/badge/project%20stage-experimental-yellow.svg
[license-shield]: https://img.shields.io/github/license/staerk-ha-addons/addon-technitium-dns.svg
[ha-addons]: https://addons.community/
