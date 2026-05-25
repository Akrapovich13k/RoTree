# Security policy

The full security model lives in [`docs/SECURITY.md`](docs/SECURITY.md) —
read that first if you want to understand the boundaries (loopback-only HTTP,
single mutation point, backup before every patch, critical-system double
confirmation, no remote code execution).

## Reporting a vulnerability

**Don't file a public GitHub issue.** Instead:

1. Open a GitHub Security Advisory (the **Security** tab on this repo →
   _Report a vulnerability_), **or**
2. Email the repo owner directly via the address on their GitHub profile.

Please include:

- A description of the issue and impact
- Steps to reproduce
- The version (`rotree version`) and platform
- Whether the issue is exploitable remotely or only locally

You should expect an acknowledgement within a few days. Fixes for critical
issues will be released as a patch version.

## Supported versions

| Version | Supported |
|---------|-----------|
| 0.1.x   | ✅        |
| < 0.1   | ❌        |
