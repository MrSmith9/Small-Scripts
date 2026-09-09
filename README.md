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
