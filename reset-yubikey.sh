#! /bin/bash

# Reset the Yubikey by locking it, then passing the full reset code:
cat files/reset-yubikey | gpg-agent --server
