#!/bin/bash
# Bu skript AWS EC2 serveriga WireGuard VPN o'rnatish uchun mo'ljallangan

# Tizimni yangilash
sudo apt update && sudo apt upgrade -y

# WireGuard paketlarini o'rnatish
sudo apt install -y wireguard

# IP-forwarding yoqish
sudo sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sudo sysctl -p

# WireGuard serverini sozlash
cd /etc/wireguard/

# Server private va public kalitlarini yaratish
wg genkey | tee /etc/wireguard/server_private.key | wg pubkey > /etc/wireguard/server_public.key

# wg0.conf server konfiguratsiya faylini yaratish
cat > /etc/wireguard/wg0.conf << EOF
[Interface]
PrivateKey = $(cat /etc/wireguard/server_private.key)
Address = 10.0.0.1/24
ListenPort = 51820
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
EOF

# Mijozlar uchun kalitlarni yaratish va konfiguratsiya qilish
mkdir -p /etc/wireguard/clients

# 30 ta mijoz uchun kalitlar va konfiguratsiya fayllarini yaratish
for i in {1..30}
do
    # Mijoz private va public kalitlarini yaratish
    wg genkey | tee /etc/wireguard/clients/client${i}_private.key | wg pubkey > /etc/wireguard/clients/client${i}_public.key

    # Mijoz konfiguratsiya faylini yaratish
    cat > /etc/wireguard/clients/client${i}.conf << EOF
[Interface]
PrivateKey = $(cat /etc/wireguard/clients/client${i}_private.key)
Address = 10.0.0.$(($i+1))/32
DNS = 8.8.8.8, 8.8.4.4

[Peer]
PublicKey = $(cat /etc/wireguard/server_public.key)
AllowedIPs = 0.0.0.0/0
Endpoint = SERVER_PUBLIC_IP:51820
PersistentKeepalive = 25
EOF

    # Serverga mijoz public kalitini qo'shish
    cat >> /etc/wireguard/wg0.conf << EOF

[Peer]
PublicKey = $(cat /etc/wireguard/clients/client${i}_public.key)
AllowedIPs = 10.0.0.$(($i+1))/32
EOF
done

# SERVER_PUBLIC_IP ni haqiqiy IP bilan almashtirish
SERVER_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
for i in {1..30}
do
    sed -i "s/SERVER_PUBLIC_IP/$SERVER_IP/" /etc/wireguard/clients/client${i}.conf
done

# WireGuard ni avtomatik ishga tushirish
sudo systemctl enable wg-quick@wg0

# WireGuard ni ishga tushirish
sudo systemctl start wg-quick@wg0

# Statusni tekshirish
sudo wg

echo "WireGuard VPN server muvaffaqiyatli o'rnatildi!"
echo "Mijozlar konfiguratsiya fayllari /etc/wireguard/clients/ papkasida joylashgan"