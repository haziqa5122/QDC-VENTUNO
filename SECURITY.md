# Reporting security issues

Do not publish credentials in an issue. Revoke exposed project API keys in Edge
Impulse Studio and replace compromised SSH keys through your QDC account.
Use the repository owner's private GitHub security advisory channel if enabled.

The board helpers execute package installation with sudo and use the official
NodeSource repository and npm registry. Review the setup script before running it.
The tested CLI is pinned to 1.25.2 for reproducibility; that pin is not an assurance
that its transitive dependencies have no vulnerabilities. Check upstream updates
before using this demonstration beyond an isolated evaluation session.

The runner's HTTP server is for a temporary QDC test session. Its listen address is
controlled by the installed runner; the script's use of 127.0.0.1 for requests does
not guarantee that the server itself binds only to loopback. Do not expose its port
publicly. The batch helper stops the runner process it starts.
