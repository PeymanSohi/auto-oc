#!/bin/bash

apt update && apt install cowsay nginx ocserv certbot -y

cowsay "Let's Go"

sudo systemctl start ocserv
systemctl status ocserv

ufw allow 80,443/tcp

echo -e "What is your email address?"
echo -n "Email address:  "
read email
pattern="^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
if [[ $email =~ $pattern ]]; then
    echo -e "Your email address is \e[32m$email\e[0m\nnow What is your domain?" 
else
    echo "Invalid email address: \e[31m$email\e[0m"
    exit 0
fi
echo -n "Domain:  "
read domain
echo -e "This is your domain \e[32m$domain\e[0m "

set -e
handle_error() {
    echo "An error occurred in the script. Exiting."
    exit 1
}
trap 'handle_error' ERR

certbot certonly --http-01-port 8080 --standalone --preferred-challenges http --non-interactive --agree-tos --email $email -d $domain

if [ -n "$domain" ]; then
    touch "/etc/nginx/conf.d/$domain.conf"
else
    echo "Domain variable is empty. Please provide a domain name."
    exit 0
fi

sed -i "s/{{DOMAIN}}/$domain/g" ./nginx.conf
sed -i "s/{{DOMAIN}}/$domain/g" ./ocserv.conf

cp ./nginx /etc/nginx/conf.d/$domain.conf
sudo mkdir -p /var/www/ocserv
sudo chown www-data:www-data /var/www/ocserv -R
sudo systemctl reload nginx

set -e
handle_error() {
    echo "An error occurred in the script. Exiting."
    exit 1
}
trap 'handle_error' ERR

certbot certonly --force-renewal --http-01-port 8080 --standalone --preferred-challenges http --non-interactive --agree-tos --email $email -d $domain -w /var/www/ocserv

cp ./ocserv.conf /etc/ocserv/ocserv.conf


echo -e "Which one is your Network Adapter name?" && ip link show | awk -F': ' '/^[0-9]/ {print $2}'
echo -n "Network Adapter:  "
read adapter

echo "net.ipv4.ip_forward = 1" | sudo tee /etc/sysctl.d/60-custom.conf
echo "net.core.default_qdisc=fq" | sudo tee -a /etc/sysctl.d/60-custom.conf
echo "net.ipv4.tcp_congestion_control=bbr" | sudo tee -a /etc/sysctl.d/60-custom.conf
sudo sysctl -p /etc/sysctl.d/60-custom.conf
sudo ufw allow 22/tcp

cat <<EOF | sudo tee -a /etc/ufw/before.rules
# NAT table rules
*nat
:POSTROUTING ACCEPT [0:0]
-A POSTROUTING -s 10.10.10.0/24 -o $adapter -j MASQUERADE

# End each table with the 'COMMIT' line or these rules won't be processed
COMMIT
EOF

sudo ufw route allow from 10.10.10.0/24
sudo ufw route allow to 10.10.10.0/24

sudo ufw enable
sudo systemctl restart ufw
sudo iptables -t nat -L POSTROUTING
sudo ufw allow 443/tcp
sudo ufw allow 443/udp

echo -e "Enter a Username"
echo -n "Username :  "
read user
echo -e "Enter a Password"
echo -n "Password :  "
read password

ocpasswd -c /etc/ocserv/ocpasswd $user << EOF
$password
$password
EOF

cowsay "Address : $domain ,user : $user ,password : $password"
