# 🏠 Home Assistant Add-on: Technitium DNS Server

[![GitHub Release][releases-shield]][releases]
![Project Stage][project-stage-shield]
[![License][license-shield]](LICENSE.md)

> [!TIP]
> ⭐ Love this add-on? Show your support by giving a [star on GitHub!][repository] Every star helps make this project more visible and encourages continued development.

## 🌐 Modern DNS Solution for Home Assistant

A fully featured DNS server for Home Assistant that acts as a secure forwarding DNS server, querying external providers using modern encrypted protocols. Perfect for improving your home network's privacy and security.

## ✨ Features

A fully featured DNS server for Home Assistant that:

- 🔒 Securely forwards DNS queries using DoH/DoT/DoQ
- 🌐 Supports local DNS zones and custom domains
- 🔄 Auto-configures with Home Assistant
- 📋 Manages SSL certificates automatically
- 🚀 Uses Cloudflare DNS with modern protocols
- ⚡ Provides fast DNS caching
- 🛡️ Includes DNS filtering and blocking

## 🏃 Quick Start

1. Click the Home Assistant My button below to add the repository to your Home Assistant instance.

   [![Open your Home Assistant instance and show the add add-on repository dialog with a specific repository URL pre-filled.](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2Fstaerk-ha-addons%2Frepository)

2. Find the "Technitium DNS Server" add-on in the add-on store.
3. Click "Install" to download the add-on.
4. Click "Start" to start the add-on.
5. Check the logs of the add-on to see if everything went well.
6. Click "Open Web Ui" and login.

> [!NOTE]
> When accessing the web interface for the first time:
>
> - **Username:** `admin`
> - **Password:** `admin`
>
> You will be required to change the password on your first login for security purposes.

## 📖 Documentation

Want to get the most out of this add-on? Our comprehensive documentation covers:

- Detailed setup guides
- Configuration options
- Best practices
- Local DNS hosting
- Troubleshooting
- Client setup examples

Check the [:books: DOCS.md][docs] for full details.

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

MIT License

Copyright (c) 2025 Jeppe Stærk

[docs]: https://github.com/staerk-ha-addons/addon-technitium-dns/blob/main/technitium-dns/DOCS.md
[frenck]: https://github.com/frenck
[issue]: https://github.com/staerk-ha-addons/addon-technitium-dns/issues
[releases-shield]: https://img.shields.io/github/release/staerk-ha-addons/addon-technitium-dns.svg
[releases]: https://github.com/staerk-ha-addons/addon-technitium-dns/releases
[repository]: https://github.com/staerk-ha-addons/repository
[staerk]: https://github.com/jepestaerk
[project-stage-shield]: https://img.shields.io/badge/project%20stage-experimental-yellow.svg
[license-shield]: https://img.shields.io/github/license/staerk-ha-addons/addon-technitium-dns.svg
[ha-addons]: https://addons.community/
