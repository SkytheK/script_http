#!/bin/bash

######Cambiar nombre de la maquina
sudo hostnamectl set-hostname MAINS-MDM

echo "########## DHCP SERVICE ##########"

#####Instala paquetes net-tools
sudo apt install -y net-tools
sleep 1 

#####Instals servidor dhcp
sudo apt install -y isc-dhcp-server
sleep 1

#####Apaga la interficie enp0s8
sudo ifconfig enp0s8 down 
sleep 1

#####Crea el fixero de la ip propia
sudo bash -c 'cat <<END> /etc/netplan/01-netcfg.yaml
# This file describes the network interfaces avilable on your system.
# For more information, see netplan(5).
network: 
 version: 2
 renderer: networkd
 ethernets: 
  enp0s8:
   dhcp4: no
   dhcp6: no
   addresses: [10.5.5.1/24]
   nameservers:
    addresses: [10.5.5.1]
    search: [mdm.itb]
END'
sleep 1

#####Aplicamos el netplan
sudo netplan apply

#####Activa el enp0s8
sudo ifconfig enp0s8 up
sleep 1

#####Remplaza el fixero por enp0s8
sudo sed -i 's/INTERFACESv4=""/INTERFACESv4="enp0s8"/g' "/etc/default/isc-dhcp-server"
sleep 1

#####Declara la red interna
sudo bash -c 'cat <<END>> /etc/dhcp/dhcpd.conf
subnet 10.5.5.0 netmask 255.255.255.0 {
    range 10.5.5.3 10.5.5.40;
    option subnet-mask 255.255.255.0;
    option broadcast-address 10.5.5.255;
    option routers 10.5.5.1; 
    option domain-name-servers 10.5.5.1;
    option domain-name "mdm.itb";
}
END'
sleep 1

#####Inicia el servicio y hace un status
sudo systemctl start isc-dhcp-server
sleep 1

#####Soluciona el problema de PID file 
sudo systemctl daemon-reload
sudo systemctl restart isc-dhcp-server
sleep 1
sudo systemctl status isc-dhcp-server

#####Solucion de problemas ivp4 inernet cliente, etc.
sudo sysctl -w net.ipv4.ip_forward=1
sleep 1

#####Problema internet
sudo iptables -A FORWARD -j ACCEPT
sudo iptables -t nat -A POSTROUTING -s 10.5.5.0/24 -o enp0s8 -j MASQUERADE
sudo iptables -t nat -A POSTROUTING -s 10.5.5.0/24 -j MASQUERADE

echo "########## DNS SERVICE ##########"

######Instala paquetes bind9
sudo apt install -y bind9
sleep 1

######Cambia el nombre del original named.conf.options
sudo mv /etc/bind/named.conf.options /etc/bind/named.conf.options.back
sleep 1

######Crea el named.conf.options configurado
sudo bash -c 'cat <<END> /etc/bind/named.conf.options
options {
    directory "/var/cache/bind";
    forwarders {
        8.8.8.8;
        8.8.4.4;
    };
};
END'
sleep 1

######Recarga el servicio y ve estatus
sudo service bind9 restart

######Configura el named.conf.local como se le diga 
sudo bash -c 'cat <<END>> /etc/bind/named.conf.local
zone "mdm.itb" {
    type master;
    file "/etc/bind/db.mdm.itb";
};
zone "5.5.10.in-addr.arpa" {
    type master;
    file "/etc/bind/db.10";
};
END'
sleep 1

######Crea archivo db.mdm.itb (Directa)
sudo bash -c 'cat <<END> /etc/bind/db.mdm.itb
; Definició de la zona mdm.itb
\$TTL 604800
mdm.itb. IN SOA router.mdm.itb. dm.router.mdm.itb. (
                 20141003       ; versió
                        1D      ; temps d’espera per refrescar
                        2H      ; temps de reintent
                        1W      ; Caducitat
                        2D )    ; ttl

@                       IN      NS      router.mdm.itb.
localhost               IN      A       127.0.0.1
router                  IN      A       10.5.5.1
bdd                     IN      A       10.5.5.2
eq1                     IN      A       10.5.5.101
eq2                     IN      A       10.5.5.102
web11                   IN      A       10.5.5.1
web22                   IN      A       10.5.5.1
www         			IN	CNAME	router
END'
sleep 1

######Crea el fixero db.10 (Inversa)
sudo bash -c 'cat <<END> /etc/bind/db.10
\$TTL 604800
5.5.10.in-addr.arpa. IN SOA router.mdm.itb. dm.router.mdm.itb. (
                        20141003        ; versió
                        1D      ; temps d’espera per refrescar
                        2H      ; temps de reintent
                        1W      ; Caducitat
                        2D )    ; ttl

                IN      NS      router.mdm.itb.
1               IN      PTR             router.mdm.itb.
2               IN      PTR             bdd.mdm.itb.
101             IN      PTR             eq1.mdm.itb.
102             IN      PTR             eq2.mdm.itb.
1               IN      PTR             web11.mdm.itb.
1               IN      PTR             web22.mdm.itb.
END'
sleep 1

######Datos y status
sudo systemctl restart bind9
sleep 1
sudo systemctl status bind9

echo "########## HTTP SERVICE ##########"

######Instala apache2 y -doc
sudo apt install -y apache2 apache2-doc
sleep 1

######Define los archivos de la estructura de los servers virtuales
sudo mkdir /var/www/web11.mdm.itb
sudo mkdir /var/www/web22.mdm.itb
sleep 1

######Edita el index de web11
sudo bash -c 'cat <<END> /var/www/web11.mdm.itb/web11.mdm.itb.html
#Use this file to change website information
<!DOCTYPE html>
<html>
   <head>
     <title>WEB 11</title> 
   </head>
   <body>
       <h1>WEB 11</h1>
       <p>Dominio web11.mdm.itb</p>
   </body>
</html>
END'
sleep 1

######Edita el index de web22
sudo bash -c 'cat <<END> /var/www/web22.mdm.itb/web22.mdm.itb.html
#Use this file to change website information
<!DOCTYPE html>
<html>
   <head>
     <title>WEB 22</title> 
   </head>
   <body>
       <h1>WEB 22</h1>
       <p>Dominio web22.mdm.itb</p>
   </body>
</html>
END'
sleep 1

######Edita el fichero de configuracion de web11
sudo bash -c 'cat <<END> /etc/apache2/sites-available/web11.mdm.itb.conf
<VirtualHost *:443>
    ServerName web11.mdm.itb
	#ServerAdmin itbsjo@localhost
	#ServerAlias www.web11.mdm.itb
	DocumentRoot /var/www/web11.mdm.itb
	DirectoryIndex web11.mdm.itb.html
	SSLEngine on     
	SSLCertificateKeyFile 	/etc/ssl/private/web11.mdm.itb.key
	SSLCertificateFile 		/etc/ssl/certs/web11.mdm.itb.crt
</VirtualHost>
END'
sleep 1

######Edita el fichero de configuracion de web22
sudo bash -c 'cat <<END> /etc/apache2/sites-available/web22.mdm.itb.conf
<VirtualHost *:80>
	ServerName web22.mdm.itb
	#ServerAdmin itbsjo@localhost
	#ServerAlias www.web22.mdm.itb
	DocumentRoot /var/www/web22.mdm.itb
	DirectoryIndex web22.mdm.itb.html
</VirtualHost>
END'
sleep 1

######Enlaçe simbolico
sudo a2ensite web11.mdm.itb.conf
sudo a2ensite web22.mdm.itb.conf
sleep 1

######Reseta el servicio
sudo systemctl restart apache2.service
sleep 1

echo "##### ACCESO SEGURO (HTTPS) #####"

######Activa el https
sudo a2enmod ssl
sudo a2ensite default-ssl
sudo systemctl restart apache2.service
sleep 1

echo "#### USUARIO Y CONTRASEÑA ####"

######Activa  el mod para la contraseña
sudo a2enmod auth_digest
sudo systemctl restart apache2.service
sleep 1

######Coloca contraseña para un usuario
htpasswd -c /home/itbsjo/Desktop/.password itbsjo
sleep 1

######Configura las contraseñas
sudo bash -c 'cat <<END>> /etc/apache2/sites-available/web11.mdm.itb.conf
<Directory /var/www/web11.mdm.itb>
 AuthType Basic
 AuthName "Top Secret"
 AuthUserFile /home/itbsjo/Desktop/.password
 Require user itbsjo
</Directory>
END'
sleep 1

######Reseta el servicio
sudo systemctl restart apache2.service
sleep 1

echo "#### MONITORIZAR RENDIMIENTO ####"

######Activa el mod del status para monitorizar
sudo a2enmod status
sudo systemctl restart apache2.service
sleep 1

######Cambia el nombre del status.conf
sudo mv /etc/apache2/mods-available/status.conf /etc/apache2/mods-available/status.conf.back
sleep 1

######Crea el nuevo archivo de status.conf con nuestra configuracion
sudo bash -c 'cat <<END>> /etc/apache2/mods-available/status.conf
<IfModule mod_status.c>
    <Location /server-status>
        SetHandler server-status
		Order deny,allow
		Allow from localhost
		Deny from 10.5.5.0/24
	</Location>
	ExtendedStatus On
	<IfModule mod_proxy.c>
		ProxyStatus On
	</IfModule>
</IfModule>
END'
sleep 1

sudo systemctl restart apache2.service

echo "#### SERVICIO DE TRANSFERENCIA DE FICHEROS ####"

######Instala paquetes de vsftpd
sudo apt install -y vsftpd
sleep 1

######Configura la carpeta .conf
sudo mv /etc/vsftpd.conf /etc/vsftpd.conf.back
sleep 1

sudo bash -c 'cat <<END>> /etc/vsftpd.conf
listen=YES
listen_ipv6=NO
anonymous_enable=NO
local_enable=YES
write_enable=YES
dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
connect_from_port_20=YES
xferlog_file=/var/log/vsftpd.log
ascii_upload_enable=YES
ascii_download_enable=YES
ftpd_banner=Bienvenido a FTP UwU.
secure_chroot_dir=/var/run/vsftpd/empty
pam_service_name=vsftpd
rsa_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem
rsa_private_key_file=/etc/ssl/private/ssl-cert-snakeoil.key
ssl_enable=NO
local_umask=000
END'
sleep 1

######Enable el servicio
sudo systemctl enable vsftpd.service
sudo systemctl status vsftpd.service
sudo systemctl restart vsftpd.service

echo "#### CERTIFICADOS ####"

######Crea los certificados
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout  /etc/ssl/private/web11.mdm.itb.key -out /etc/ssl/certs/web11.mdm.itb.crt

######
sudo systemctl restart apache2.service
