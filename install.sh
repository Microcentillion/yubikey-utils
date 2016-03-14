#! /bin/bash

if [[ $EUID -ne 0 ]]; then
   echo "This utility must be run as root"
   exit 1
fi

# Pull in the configuration options:
source configuration.conf

[ $SUDO_USER ] && SUSER=$SUDO_USER || SUSER=`whoami`
echo "Creating keys for $SUSER"

# Check if the Yubico repo is already added
YBCO=$(find /etc/apt/ -type f | grep yubico-ubuntu | wc -l)
if [[ $YBCO -lt 1 ]]; then
   apt-add-repository -y ppa:yubico/stable
fi

#apt-get update -y
#apt-get install -y yubikey-personalization-gui yubikey-neo-manager yubikey-personalization pcscd scdaemon gnupg2 pcsc-tools paperkey qrencode

# Clean & prepare the workspace
mkdir keys
mkdir generated
rm keys/*
rm generated/*
gpg2 --no-permission-warning --version > /dev/null
cat ./files/gnome-keyring-daemon > /usr/local/bin/gnome-keyring-daemon

# Check for necessary options in gpg.conf, and add otherwise
DEFOPTS=$(grep "^cert-digest-algo" ~/.gnupg/gpg.conf | wc -l)
USEAGENT=$(grep "^use-agent" ~/.gnupg/gpg.conf | wc -l)
ENABLESSH=$(grep "^enable-ssh-support" ~/.gnupg/gpg-agent.conf | wc -l)

if [[ USEAGENT -lt 1 ]]; then
   echo "use-agent" >> ~/.gnupg/gpg.conf;
fi

if [[ ENABLESSH -lt 1 ]]; then
   echo "enable-ssh-support" >> ~/.gnupg/gpg-agent.conf;
fi

#if [[ DEFOPTS -lt 1 ]]; then
#   cat << EOB >> ~/.gnupg/gpg.conf
#default-preference-list SHA512 SHA384 SHA256
#cert-digest-algo SHA512
#EOB

# Reset the Yubikey
echo "Resetting the Yubikey..."
./reset-yubikey.sh

# Generate master key
#gpg2 --gen-key --batch genkey-options.conf
gpg2 --quiet --no-permission-warning --import master.sec master.sec

# Get master key ID
MASTER=$(gpg2 --no-permission-warning --list-keys | grep pub | awk ' { print($2) } ' | awk -F"/" ' { print($2) } ' | tr -d '\n')
#MASTER=$(gpg2 --list-keys | grep pub | grep "`date -u +%Y-%m-%d`" | awk ' { print($2) } ' | awk -F"/" ' { print($2) } ')

# Export private key, armor, and QR-Encoded Paperkey PNG
gpg2 --no-permission-warning  --export-secret-keys $MASTER > keys/master-privkey.sec
gpg2 --no-permission-warning --armor --export-secret-keys $MASTER > keys/master-privkey.asc
paperkey --secret-key keys/master-privkey.sec --output-type raw | base64 | qrencode -o keys/master-privkey.png

# Configure the yubikey and generate the subkeys with expect
cat files/expect_yubikeyconfig.tpl > generated/configyubikey.exp
sed -i "s/FIRSTNAME/$FIRSTNAME/g" generated/configyubikey.exp
sed -i "s/LASTNAME/$LASTNAME/g" generated/configyubikey.exp
sed -i "s/EMAIL/$EMAIL/g" generated/configyubikey.exp
sed -i "s/SEX/$SEX/g" generated/configyubikey.exp
sed -i "s/LANG/$LANG/g" generated/configyubikey.exp
sed -i "s/LOGIN/$LOGIN/g" generated/configyubikey.exp
sed -i "s,PUBKEYURL,$PUBKEYURL,g" generated/configyubikey.exp
sed -i "s/MASTERLENGTH/$MASTERLENGTH/g" generated/configyubikey.exp
sed -i "s/MASTEREXPIRE/$MASTEREXPIRE/g" generated/configyubikey.exp
sed -i "s/MASTER/$MASTER/g" generated/configyubikey.exp
sed -i "s/AUTHLENGTH/$AUTHLENGTH/g" generated/configyubikey.exp
sed -i "s/ENCLENGTH/$ENCLENGTH/g" generated/configyubikey.exp
sed -i "s/ENCEXPIRE/$ENCEXPIRE/g" generated/configyubikey.exp
sed -i "s/SIGNLENGTH/$SIGNLENGTH/g" generated/configyubikey.exp
sed -i "s/USERPIN/$USERPIN/g" generated/configyubikey.exp
sed -i "s/ADMINPIN/$ADMINPIN/g" generated/configyubikey.exp
sed -i "s/RESETPIN/$RESETPIN/g" generated/configyubikey.exp
sed -i "s/SIGNLENGTH/$SIGNLENGTH/g" generated/configyubikey.exp
sed -i "s/SIGNEXPIRE/$SIGNEXPIRE/g" generated/configyubikey.exp
sed -i "s/AUTHLENGTH/$AUTHLENGTH/g" generated/configyubikey.exp
sed -i "s/AUTHEXPIRE/$AUTHEXPIRE/g" generated/configyubikey.exp
sed -i "s/ENCLENGTH/$ENCLENGTH/g" generated/configyubikey.exp
sed -i "s/ENCEXPIRE/$ENCEXPIRE/g" generated/configyubikey.exp
chmod +x generated/configyubikey.exp
./generated/configyubikey.exp

# Generate revocation certificates for all master and subkeys:
SIGNKEY=$(gpg2 --with-colons --list-key $MASTER | grep :s: | awk -F":" ' { print($5) } ' | tr -d '\n')
AUTHKEY=$(gpg2 --with-colons --list-key $MASTER | grep :a: | awk -F":" ' { print($5) } ' | tr -d '\n')
ENCRKEY=$(gpg2 --with-colons --list-key $MASTER | grep :e: | awk -F":" ' { print($5) } ' | tr -d '\n')

cat files/expect_genrevoke.tpl > generated/genrevoke.exp
sed -i "s/MASTER/$MASTER/g" generated/genrevoke.exp
sed -i "s/SIGNKEY/$SIGNKEY/g" generated/genrevoke.exp
sed -i "s/AUTHKEY/$AUTHKEY/g" generated/genrevoke.exp
sed -i "s/ENCRKEY/$ENCRKEY/g" generated/genrevoke.exp
chmod +x generated/genrevoke.exp
./generated/genrevoke.exp

# QR-encode the revocation certificates to QR as well, cause why not:
ls -al ./keys/ | grep \.asc | grep -v master | awk ' { system("cat ./keys/" $9 " | qrencode -o ./keys/" $9 ".png") } '

# Set the file permissions to what they need to be.
chown -R $SUSER:$SUSER ./generated
chown -R $SUSER:$SUSER ./keys
chown -R $SUSER:$SUSER ~/.gnupg/

cat << EOE
# ******************************************************** #
# Certificate creation and Yubikey configuration completed #
#                                                          #
#  The master private key and revocation certificates can  #
#  be found in the following directory:                    #
#      ./keys/                                             #
#                                                          #
# Print out the Master key AND DELETE IT IMMEDIATELY, then #
#     move your revocation certificates to a safe place!   #
#         (THIS IS NOT A SUGGESTION! DO IT NOW!!!)         #
# ******************************************************** #
EOE
