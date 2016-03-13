#! /bin/bash

if [[ $EUID -ne 0 ]]; then
   echo "This utility must be run as root"
   exit 1
fi

[ $SUDO_USER ] && SUSER=$SUDO_USER || SUSER=`whoami`
echo "Creating keys for $SUSER"

# Check if the Yubico repo is already added
YBCO=$(find /etc/apt/ -type f | grep yubico-ubuntu | wc -l)
if [[ $YBCO -lt 1 ]]; then
   apt-add-repository -y ppa:yubico/stable
fi

#apt-get update -y
#apt-get install -y yubikey-personalization-gui yubikey-neo-manager yubikey-personalization pcscd scdaemon gnupg2 pcsc-tools

gpg2 --version > /dev/null
ln -s /usr/bin/gpg2 /usr/local/bin/gpg
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

# Generate master key
#gpg2 --gen-key --batch genkey-options.conf
gpg2 --import master.sec
gpg2 --import master.pub

# Get master key ID
MASTER=$(gpg2 --list-keys | grep "`date -u +%Y-%m-%d`" | awk ' { print($2) } ' | awk -F"/" ' { print($2) } ')
echo $MASTER

# Create the subkeys with expect
cat files/expect.tpl | sed "s/CERTID/$MASTER/g" > script.exp
chmod +x script.exp
./script.exp

# Set the file permissions to what they need to be.
chown $SUSER:$SUSER script.exp
chown -R $SUSER:$SUSER ~/.gnupg/
