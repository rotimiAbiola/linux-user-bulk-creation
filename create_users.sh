#!/bin/bash
set -e

terminate() {
  local msg="${1:-"An error occured"}"
  local code="${2:-160}"
  echo "ERROR: ${msg}" >&2
  exit "${code}"
}
# Check if the user has provided a filename as an argument
if [ "$#" -ne 1 ]; then
  terminate "Please pass one argument referencing the name of the text file containing users' information
  Sample Usage: bash $0 <name-of-text-file>"
fi

# Define the input file
user_list_file=$1

# Check if the input file exists
if [ ! -f "$user_list_file" ]; then
  terminate "File '$user_list_file' not found!"
fi

# Log file and secure passwords file
user_log_file="/var/log/user_management.log"
secure_password_file="/var/secure/user_passwords.csv"

# Ensure the log file and password file directories exist
mkdir -p /var/log
mkdir -p /var/secure

# Initialize the log file and password file
echo "User management log" > "$user_log_file"
echo "Username, Password" > "$secure_password_file"

# Set permissions for the password file
chmod 600 "$secure_password_file"

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
    echo "Created group: $username" >> "$user_log_file"
  else
    echo "Group $username already exists" >> "$user_log_file"
  fi

  # Create the user
  if ! id "$username" >/dev/null 2>&1; then
    password=$(generate_password)
    useradd -m -g "$username" -s /bin/bash "$username"
    echo "$username:$password" | chpasswd
    echo "$username,$password" >> "$secure_password_file"
    echo "Created user: $username with home directory and set password" >> "$user_log_file"
  else
    echo "User $username already exists" >> "$user_log_file"
  fi

  # Add the user to the specified groups
  IFS=',' read -ra group_array <<< "$groups"
  for group in "${group_array[@]}"; do
    group=$(echo "$group" | xargs)
    if ! getent group "$group" >/dev/null; then
      groupadd "$group"
      echo "Created group: $group" >> "$user_log_file"
    fi
    usermod -aG "$group" "$username"
    echo "Added user $username to group $group" >> "$user_log_file"
  done

done < "$user_list_file"

echo "User creation and group assignment completed."

exit 0
