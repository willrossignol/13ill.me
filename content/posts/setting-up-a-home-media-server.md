---
date: "2025-08-25T16:47:49-03:00"
draft: true
title: "Setting up a home media server"
tags: ["homelab", "docker", "ubuntu"]
---

# Introduction

We'll discuss how to set up a home media server using Ubuntu Server and Docker.
This is the setup I currently use, as of September 2025 for my personal home media server.
I am aware that there are issues with this setup (the lack of redundancy for example), but this should be used as more of an introduction to the world of homelabing and not a definite guide.

## Requirements

- A computer to use as a server. I personally use an old Dell Optiplex 3010
- A USB key to install Ubuntu Server
- An ethernet connection for your server

## Installing the OS

To install Ubuntu Server on your computer, you'll first need to download the ISO from the [Ubuntu Website](https://ubuntu.com/download/server). The LTS version is always a good option as it will be supported with security updates for the longest time and won't require you to upgrade your OS as often.

Once you've downloaded the ISO, you can use software like [Rufus](https://rufus.ie/en/) or [balenaEtcher](https://etcher.balena.io/) to create a bootable USB drive.
You will take this USB drive and insert it into your server. You will probably need to access the BIOS or the boot menu in order to boot from the USB drive.

Once you've booted into the Ubuntu Server installation media, go through the installation process.
After having installed the operating system, you'll want to make sure that everything is up-to-date using the following commands.
```sh
sudo apt update
sudo apt upgrade -y
```

We will want to enable ssh to be able to connect to the server's shell from another computer. 
To do so, we will need to run the two following commands
```sh
sudo systemctl enable ssh
sudo systemctl start ssh
```

To enhacne the security of your server, you should enable the [Uncomplicated Firewall](https://help.ubuntu.com/community/UFW) using the command `sudo ufw enable`.
We'll then want to allow SSH connections through the firewall, so we will need to run the command `sudo ufw allow ssh`.

Now, you should have a working Ubuntu Server OS installed on your sever that you can connect to using SSH.
To connect to your server using SSH, ensure it is connected to your network, find its IP address using a tool like `ifconfig`, and connect to your server from another computer using the following command
```sh
ssh <username>@<ip address>
```

For my setup, the command I use is `ssh bill@192.168.2.21`

## Setting up docker

To install docker, you can follow the instructions provided by Docker in their [documentation](https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository)

### Portainer

Once docker is installed, we can install [Portainer CE](https://docs.portainer.io/start/install-ce), which we will use to manage our Docker containers
We want to follow the installation instructions provided on the [Install Portainer CE with Docker on Linux][https://docs.portainer.io/start/install-ce/server/docker/linux] documentation page

After the successful installation of Portainer, its GUI `http://<server-ip>:9443`.

### Homarr

I like to have a dashboard where I can quickly access and manage all of the different applications that I install on my home server.
I use [homarr](https://homarr.dev/) as my dashboard, though there are multiple other options and I encourage to go take a look at the alternatives.

To setup homarr, we'll want to create a new stack in Portainer
This is the `docker-compose.yaml` file that this new stack will use:
```yml
services:
  homarr:
    container_name: homarr
    image: ghcr.io/ajnart/homarr:latest
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock # Optional, only if you want docker integration
      - /home/<user>/homarr/configs:/app/data/configs
      - /home/<user>/homarr/icons:/app/public/icons
      - /home/<user>/homarr/data:/data
    ports:
      - 7575:7575
```

You'll want to make sure that you replace `<user>` with the name that you chose for your Ubuntu Server user.

Once you create this new stack, you'll be able to setup Homarr at `http://<server-ip>:7575`.
I would start by bookmarking this Homarr dashboard, and adding a link to your Portainer instance on you Homarr dashboard.

### Gluetun

For *various* reasons, you may want to hide the traffic of some applications on your server behind a VPN. For instance, if you plan on using a torrenting client, you'll probably want to use that client behind a VPN, unless you want to let **everybody** know what your public IP is.

To achieve this I've created a Portainer stack that contains [Gluetun](https://github.com/qdm12/gluetun) and all of the other docker containers I want to be hidden behing a VPN, for example, the [qBittorrent](https://docs.linuxserver.io/images/docker-qbittorrent/) container.

To setup Gluetun, you will need to acquire a VPN subscription, I personally use [Mullvad VPN](https://mullvad.net/en) because of their privacy practices.

My `docker-compose.yaml` file for my Stack containing Gluetun and QBittorrent is the following:
```yml
services:
  gluetun:
    container_name: gluetun
    image: qmcgaw/gluetun
    cap_add:
      - NET_ADMIN
    ports:
      - 8080:8080 # qbittorrent
      - 6881:6881 # qbittorrent
      - 6881:6881/udp # qbittorrent
    devices:
      - /dev/net/tun:/dev/net/tun
    environment:
      - VPN_TYPE=wireguard
      - WIREGUARD_PRIVATE_KEY=<private key>
      - VPN_SERVICE_PROVIDER=<provider>
      - WIREGUARD_ADDRESSES=<addresses>
      - SERVER_COUNTRIES=<countries>
    restart: unless-stopped
    
  qbittorrent:
    container_name: qbittorrent
    image: lscr.io/linuxserver/qbittorrent:latest
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Moncton
      - WEBUI_PORT=8080
      - TORRENTING_PORT=6881
    volumes:
      - /home/bill/qbittorrent/config:/config
      - /home/bill/downloads:/downloads
      - /home/bill/media:/media
    restart: unless-stopped
    network_mode: service:gluetun
```

One of the most important things to notice here is the `network_mode` parameter for the `qbittorrent` container. This parameter ensures that all QBittorrent traffic is routed through the Gluetun network, which uses a VPN.

The VPN configuration of Gluetun is done using environment variables. It is recommended to use the [WireGuard](https://www.wireguard.com/) VPN Type, as it is faster than [OpenVPN](https://github.com/OpenVPN/openvpn).

With Mullvad, to get the information required to setup the VPN, you will need to navigate to your account page, go to WireGuard configuration, and generate a key. After having generated a key, you will be able to select which server you want to use, and download a ZIP archive containing your WireGuard configurations. In these WireGuard configurations, you will find your PrivateKey and the subnet of the VPN addresses. My environment variables for Candian VPN servers using Mullvad look like the following:
```
- VPN_SERVICE_PROVIDER=mullvad
- WIREGUARD_ADDRESSES="10.73.23.153/32"
- SERVER_COUNTRIES=Canada
```

If you already have a VPN provider and would like to use it using Gluetun, you can take a look at the [Gluetun Wiki's list of supported providers](https://github.com/qdm12/gluetun-wiki/tree/main/setup/providers)

### Various media containers

...
