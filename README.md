# Scripts
Scripts by Nico L & MrSmith9 (update 2026).

# News about update
__I have been update node.js to v25, I will doing next others too. Have a nice day/evening.__

# Our Wiki
> You can open our Wiki here:
https://github.com/nicolaeser/small-scripts/wiki


### Server Installer

#### Docker
```
wget https://github.com/MrSmith9/small-scripts/raw/main/installer/docker.sh && chmod +x docker.sh && ./docker.sh
```


#### NodeJS
```
wget https://github.com/MrSmith9/small-scripts/raw/main/installer/nodejs.sh && chmod +x nodejs.sh && ./nodejs.sh
```

#### Ngnix
```
wget https://github.com/MrSmith9/small-scripts/raw/main/installer/nginx.sh && chmod +x ngnix.sh && ./ngnix.sh
```

#### Apache
```
wget https://github.com/MrSmith9/small-scripts/raw/main/installer/apache.sh && chmod +x apache.sh && ./apache.sh
```

#### MariaDB
```
wget https://github.com/MrSmith9/small-scripts/raw/main/installer/mariadb.sh && chmod +x mariadb.sh && ./mariadb.sh
```

#### PHP
```
wget https://github.com/MrSmith9/small-scripts/raw/main/installer/php.sh && chmod +x php.sh && ./php.sh
```

#### Git
```
wget https://github.com/MrSmith9/small-scripts/raw/main/installer/git.sh && chmod +x git.sh && ./git.sh
```

#### Keyhelp
```
wget https://github.com/MrSmith9/small-scripts/raw/main/installer/keyhelp.sh && chmod +x keyhelp.sh && ./keyhelp.sh
```

#### Adguard Home
```
wget https://github.com/MrSmith9/small-scripts/raw/main/installer/adguardhome.sh && chmod +x adguardhome.sh && ./adguardhome.sh
```

#### Pi Hole
```
wget https://github.com/MrSmith9/small-scripts/raw/main/installer/pihole.sh && chmod +x pihole.sh && ./pihole.sh
```

#### Pterodactyl Panel
```
curl -fsSLO https://raw.githubusercontent.com/MrSmith9/Small-Scripts/main/installer/pterodactyl.sh && chmod +x pterodactyl.sh && sudo ./pterodactyl.sh
```

The installer supports Debian and Ubuntu with PHP 8.2 or 8.3. It prompts for the panel's domain or public IP and can configure a Let's Encrypt certificate. After it completes, create the first panel administrator with the command it displays.

### Server utilities

Each utility below supports Debian and Ubuntu, must be run with `sudo`, and asks for confirmation before making the relevant persistent or network-affecting changes.

#### Fail2ban
```sh
curl -fSLO https://raw.githubusercontent.com/MrSmith9/Small-Scripts/main/installer/fail2ban.sh && chmod +x fail2ban.sh && sudo ./fail2ban.sh
```
Installs Fail2ban and enables an SSH jail for the selected SSH port.

#### UFW
```sh
curl -fSLO https://raw.githubusercontent.com/MrSmith9/Small-Scripts/main/installer/ufw.sh && chmod +x ufw.sh && sudo ./ufw.sh
```
Installs UFW, safely allows the chosen SSH port and optional TCP ports, then enables the firewall only after an explicit confirmation.

#### Certbot
```sh
curl -fSLO https://raw.githubusercontent.com/MrSmith9/Small-Scripts/main/installer/certbot.sh && chmod +x certbot.sh && sudo ./certbot.sh
```
Obtains and configures a Let's Encrypt certificate for a validated domain through an explicitly selected Nginx or Apache installation.

#### Docker cleanup
```sh
curl -fSLO https://raw.githubusercontent.com/MrSmith9/Small-Scripts/main/installer/docker-cleanup.sh && chmod +x docker-cleanup.sh && sudo ./docker-cleanup.sh
```
Shows Docker disk usage and removes unused containers, networks, images, and build cache only after typed confirmation; unused volumes require a separate confirmation.

#### Monitoring
```sh
curl -fSLO https://raw.githubusercontent.com/MrSmith9/Small-Scripts/main/installer/monitoring.sh && chmod +x monitoring.sh && sudo ./monitoring.sh
```
Installs Netdata from the distribution's signed APT repository and binds its dashboard locally at `http://127.0.0.1:19999`.

#### Backups
```sh
curl -fSLO https://raw.githubusercontent.com/MrSmith9/Small-Scripts/main/installer/backup.sh && chmod +x backup.sh && sudo ./backup.sh
```
Creates timestamped local `tar.gz` backups of selected directories, prunes them to a validated retention count, and installs a daily UTC cron job.

#### WireGuard
```sh
curl -fSLO https://raw.githubusercontent.com/MrSmith9/Small-Scripts/main/installer/wireguard.sh && chmod +x wireguard.sh && sudo ./wireguard.sh
```
Generates a server configuration and one client configuration with newly generated WireGuard keys; it does not open a firewall port and only activates the tunnel after confirmation.

#### Swap
```sh
curl -fSLO https://raw.githubusercontent.com/MrSmith9/Small-Scripts/main/installer/swap.sh && chmod +x swap.sh && sudo ./swap.sh
```
Creates a validated `/swapfile`, enables it, and adds the safe fstab entry after confirmation.

#### Unattended upgrades
```sh
curl -fSLO https://raw.githubusercontent.com/MrSmith9/Small-Scripts/main/installer/unattended-upgrade.sh && chmod +x unattended-upgrade.sh && sudo ./unattended-upgrade.sh
```
Enables daily Debian/Ubuntu security updates with an optional notification email and an explicitly selected automatic-reboot policy.

#### SSH hardening
```sh
curl -fSLO https://raw.githubusercontent.com/MrSmith9/Small-Scripts/main/installer/ssh-hardening.sh && chmod +x ssh-hardening.sh && sudo ./ssh-hardening.sh
```
Installs a supplied public key, disables password authentication, and safely reloads OpenSSH on a validated port without changing firewall rules.

#### Restic backups
```sh
curl -fSLO https://raw.githubusercontent.com/MrSmith9/Small-Scripts/main/installer/restic-backup.sh && chmod +x restic-backup.sh && sudo ./restic-backup.sh
```
Initializes or uses an encrypted Restic repository, stores its password with root-only permissions, and creates a daily UTC backup schedule with snapshot retention.

#### Server health report
```sh
curl -fSLO https://raw.githubusercontent.com/MrSmith9/Small-Scripts/main/installer/server-health.sh && chmod +x server-health.sh && sudo ./server-health.sh
```
Produces a read-only report of system resources, failed services, listening ports, firewall state, Docker usage, and recent warnings.

#### Application log rotation
```sh
curl -fSLO https://raw.githubusercontent.com/MrSmith9/Small-Scripts/main/installer/logrotate.sh && chmod +x logrotate.sh && sudo ./logrotate.sh
```
Adds a validated per-directory `.log` rotation rule with compression, retention, and non-restarting `copytruncate` behavior.

#### Disk cleanup
```sh
curl -fSLO https://raw.githubusercontent.com/MrSmith9/Small-Scripts/main/installer/disk-cleanup.sh && chmod +x disk-cleanup.sh && sudo ./disk-cleanup.sh
```
Previews disk usage and safely reclaims package cache, orphaned packages, aged system journals, and policy-managed temporary files only after typed confirmation.
