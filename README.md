# Yubikey Utils
I put this together to simplify the secure use of a Yubikey with PGP. DO NOT USE if you have your own keys you want to use!

## Usage
<b>Clone, and modify genkey-options.conf</b><br>
<b>execute ./install.sh</b><br>
<br>

This will install the prerequisite packages, generate a 3 year, 4096-bit PGP Master key with 'cert' usage, and three 1 year, 2048-bit subkeys for Encryption, Authentication, and Signing.
