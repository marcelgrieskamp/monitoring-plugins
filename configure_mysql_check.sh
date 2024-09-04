#!/usr/bin/env bash

# The username and generate a random password with 48 characters
USERNAME=icinga2_check
PASSWORD=$(openssl rand -base64 48)

# Filter out the '/' and '\' characters from the password
PASSWORD=$(echo "$PASSWORD" | tr -d '/\\')

# Install the libdbd-mysql-perl package without installing recommended packages if not installed.
if dpkg -s libdbd-mysql-perl 2>/dev/null | grep -q "Status: install ok installed"; then
  echo "The package (libdbd-mysql-perl) is already installed."
else
  echo "The package (libdbd-mysql-perl) isn't installed. Installing..."
  apt install --no-install-recommends libdbd-mysql-perl
fi

# Create a user with the generated password
mysql -u root -p -e "CREATE USER '$USERNAME'@'localhost' IDENTIFIED BY '$PASSWORD'"

# Print the generated password
echo "The generated password for user (${USERNAME}) is: '${PASSWORD}'."
