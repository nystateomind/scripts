#!/bin/bash
set -e
# Postfix Gmail relay configuration script
# Usage: sudo su; curl -sL https://raw.githubusercontent.com/nystateomind/scripts/main/setup_postfix_relay.sh | bash -s myaddress@gmail.com 'xxxx xxxx xxxx xxxx'  

if [ "$EUID" -ne 0 ]; then 
    echo "Run as root"
    exit 1
fi

if [ $# -ne 2 ]; then
    echo "Usage: $0 <gmail_address> <app_password>"
    exit 1
fi

# install modules
apt install postfix libsasl2-modules mailutils -y -o Dpkg::Options::="--force-confnew"

GMAIL_USER="$1"
APP_PASSWORD="$2"

# Rename existing config
cp /etc/postfix/main.cf /etc/postfix/main.cf.bak.$(date +%s)

# Comment out existing relayhost lines
sed -i 's/^relayhost\s*=/#&/' /etc/postfix/main.cf

# Remove any existing Gmail relay config block to prevent duplicates
sed -i '/^# Gmail relay configuration$/,/^smtp_tls_CAfile.*ca-certificates.crt$/d' /etc/postfix/main.cf 

# Configure main.cf
cat >> /etc/postfix/main.cf << 'EOF'

# Gmail relay configuration
relayhost = [smtp.gmail.com]:587
smtp_sasl_auth_enable = yes
smtp_sasl_security_options = noanonymous
smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
smtp_tls_security_level = encrypt
smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt
EOF

# Create sasl_passwd
echo "[smtp.gmail.com]:587    ${GMAIL_USER}:${APP_PASSWORD}" > /etc/postfix/sasl_passwd

# Secure and hash
chmod 600 /etc/postfix/sasl_passwd
postmap /etc/postfix/sasl_passwd

# Create /etc/mailname if it doesn't exist
[ ! -f /etc/mailname ] && hostname --fqdn | sudo tee /etc/mailname > /dev/null   

# Restart postfix
systemctl restart postfix

echo "Postfix configured for Gmail relay"
if echo 'test' | mail -s 'Postfix configured for Gmail relay' -- "${GMAIL_USER}"; then
    echo "Test email sent to ${GMAIL_USER}"
else
    echo "Failed to send test email" >&2
fi
