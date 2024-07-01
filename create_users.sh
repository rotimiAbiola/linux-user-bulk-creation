#!/bin/bash
# This script is used to create a new user on the system and add them to group(s)
# The usernames and groups are parsed through a text file with the syntax: "username; group, group, group"
# Usage: bash create_users.sh <name-of-text-file>


# Check if the user has provided a filename as an argument
if [ "$#" -ne 1 ]; then
  echo "Usage: bash $0 <name-of-text-file>"
  exit 1
fi

# Define the input file
INPUT_FILE=$1

# Check if the input file exists
if [ ! -f "$INPUT_FILE" ]; then
  echo "Error: File '$INPUT_FILE' not found!"
  exit 1
fi

# Log file and secure passwords file
LOG_FILE="/var/log/user_management.log"
PASSWD_FILE="/var/secure/user_passwords.csv"

# Ensure the log file and password file directories exist
mkdir -p /var/log
mkdir -p /var/secure

# Initialize the log file and password file
echo "User management log" > "$LOG_FILE"
echo "Username, Password" > "$PASSWD_FILE"

# Set permissions for the password file
chmod 600 "$PASSWD_FILE"

# Function to generate a random password
generate_password() {
  tr -dc A-Za-z0-9 </dev/urandom | head -c 15
}

# Read the input file line by line
while IFS=';' read -r username groups; do
  # Remove leading and trailing whitespace
  username=$(echo "$username" | xargs)
  groups=$(echo "$groups" | xargs)

  # Create a personal group with the same name as the username
  if ! getent group "$username" >/dev/null; then
    groupadd "$username"
    echo "Created group: $username" >> "$LOG_FILE"
  else
    echo "Group $username already exists" >> "$LOG_FILE"
  fi

  # Create the user with the personal group
  if ! id "$username" >/dev/null 2>&1; then
    password=$(generate_password)
    useradd -m -g "$username" -s /bin/bash "$username"
    echo "$username:$password" | chpasswd
    echo "$username,$password" >> "$PASSWD_FILE"
    echo "Created user: $username with home directory and set password" >> "$LOG_FILE"
  else
    echo "User $username already exists" >> "$LOG_FILE"
  fi

  # Add the user to the specified groups
  IFS=',' read -ra group_array <<< "$groups"
  for group in "${group_array[@]}"; do
    group=$(echo "$group" | xargs)
    if ! getent group "$group" >/dev/null; then
      groupadd "$group"
      echo "Created group: $group" >> "$LOG_FILE"
    fi
    usermod -aG "$group" "$username"
    echo "Added user $username to group $group" >> "$LOG_FILE"
  done

done < "$INPUT_FILE"

echo "User creation and group assignment completed."

exit 0
