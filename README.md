whitera.in — Production Server Build & Hardening
A public-facing production server built from scratch on AlmaLinux 8.10, covering DNS, web, and database services with full system-level security hardening. Built as a practical, real-world exercise in owning infrastructure end-to-end — not a tutorial walkthrough, but a live server that had to actually work, stay secure, and recover from failure.

	
Stack Layer	Technology
OS		AlmaLinux 8.10
DNS		BIND9 with DNSSEC/NSEC3 signing
Web		Apache + PHP-FPM
Database	MySQL 8.0
Security	firewalld, SSH (non-standard port), Fail2Ban, SELinux (enforcing), auditd
Monitoring	Custom health-check script, Lynis

Build:
DNSSEC with NSEC3, not plain DNSSEC. Plain DNSSEC signs records but leaves zone enumeration possible — an attacker can walk the zone and discover every record even without guessing them. NSEC3 hashes the records instead, closing that gap. Most builds skip this because it's more complex to set up correctly; it's included here because "secure DNS" should mean secure, not just signed.
MySQL 8.0, not MariaDB. The original plan used MariaDB, in line with the rest of the AlmaLinux ecosystem. Mid-build, the hardening spec required default_password_lifetime enforcement — a feature MariaDB 10.3 doesn't support. Rather than skip that hardening requirement, the database layer was migrated to MySQL 8.0 without breaking services that already depended on it.
SELinux stayed in enforcing mode throughout. It would have been faster to set it to permissive and move on whenever it blocked something. It didn't get disabled — every SELinux-related failure was traced to its actual context mismatch and fixed properly, which is also where most of the debugging time on this project went.

Troubleshooting done:
Real infrastructure breaks. Here's what actually happened during this build, not a sanitized success story:
•	OpenDKIM socket conflict — mail signing silently failed after a config change. Traced to a socket permission conflict between OpenDKIM and Postfix at the daemon log level, not surfaced by any high-level error message.
•	Dovecot authentication failures — users couldn't authenticate after a config update. Root cause was a malformed syntax error in the Dovecot auth worker config that failed silently instead of throwing a clear error.
•	SELinux context mismatches — both PHP-FPM and MySQL log files hit SELinux denials after directory changes. Fixed by correcting the security context (semanage fcontext + restorecon), not by disabling enforcement.
•	Apache SSL vhost ordering — the wrong virtual host was being served over HTTPS due to vhost load order. Fixed by explicitly ordering the SSL vhost configuration.
Each of these was diagnosed by reading logs at the daemon level — journalctl -u <service>, service-specific logs — rather than guessing or restarting services until something worked.
Verifying it actually works
A backup script isn't proof of anything until it's actually used to restore something. This build's nightly mysqldump backups (with 30-day rotation via cron) were tested with a full restore — completed in under 15 minutes.
A Lynis security audit was run against the server and the findings were remediated, raising the hardening index from 70 to 90+.
What I'd do differently
Everything here was rebuilt manually, service by service. Knowing what I know now, the next version of this build would start as an Ansible playbook from day one — not because the manual build was wrong, but because doing it manually first is what taught me what actually needs automating, and in what order.

Files in this repo
•	configs/ — sanitized configuration files (firewalld rules, BIND9 zone files, Apache vhost config, MySQL hardening config) — passwords, IPs, and domain-specific values replaced with placeholders
•	scripts/health-check.sh — the automated health-check script covering service status, disk usage, and log monitoring
•	scripts/backup.sh — the nightly backup script with rotation
•	docs/cronjob — Automated 

