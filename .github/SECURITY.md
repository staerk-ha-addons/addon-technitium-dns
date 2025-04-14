# Security Policy

## Supported Versions

We maintain security updates for the following versions:

| Version | Supported          |
| ------- | ----------------- |
| 1.x.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

We take security issues seriously. Thank you for helping us maintain the security of our add-on.

### Where to Report

#### For Critical Vulnerabilities and For Non-Critical Issues

- Open a [GitHub Issue](https://github.com/staerk-ha-addons/addon-technitium-dns/issues/new)
- Use the "Security" label

### What to Include

- Detailed description of the vulnerability
- Steps to reproduce
- Impact assessment
- Possible mitigations
- Version affected
- Any relevant screenshots or logs

## Security Considerations

### Network Security

- The add-on exposes DNS ports (53, 443, 853)
- Uses encrypted DNS protocols (DoH, DoT, DoQ)
- Supports SSL/TLS certificates
- Implements DNSSEC validation

### Certificate Management

- Automatic certificate generation
- Support for Let's Encrypt integration
- PKCS#12 certificate handling
- Certificate monitoring and updates

### Authentication

- Web interface requires authentication
- Default credentials must be changed on first login
- API access requires authentication

### Best Practices

1. **Installation**
   - Change default password immediately
   - Use HTTPS for web interface
   - Enable encrypted DNS protocols

2. **Configuration**
   - Use Let's Encrypt certificates in production
   - Enable query logging for auditing
   - Regular backups of configuration

3. **Network**
   - Restrict access to management interface
   - Use firewall rules when exposed
   - Monitor DNS traffic patterns
