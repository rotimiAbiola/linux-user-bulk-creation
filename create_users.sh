#!/bin/bash
readonly SCRIPT_NAME=${0##*/}
readonly ARGS_ERROR=150

set -e

# Create a Function to end the script if an error occurs
terminate() {
  local msg="${1:-"An error occured"}"
  local code="${2:-160}"
  echo "ERROR: ${msg}" >&2
  exit "${code}"
}

# Create a Function that provides help on how to use the script
usage() {
  cat <<USAGE
Usage: bash ${SCRIPT_NAME} <name-of-text-file>

This is a usage message with instructions on how to run the script.
The script only requires just one argument to work. The argument must reference the name of the text file containing users' information.
For example, if the text file is named users_list.txt, run "bash ${SCRIPT_NAME} users_list.txt" on the terminal.
If the current user does not have the necessary permission to run the script, run it with sudo priviledges or as root.

Arguments:
  name-of-text-file The name of the text file containing users' details

Options:
  -h, --help      Show this help message and exit
USAGE
}

# Check if the user has provided a filename as an argument
if [ "$#" -ne 1 ]; then
  usage
  terminate "Command line argument missing" "${ARGS_ERROR}"
fi

if [[ "${1}" == "-h" ]] || [[ "${1}" == "--help" ]]; then
  usage
  exit 0
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
    else
      echo "Group $group already exists" >> "$user_log_file"
    fi

    if id -nG "$username" | grep -qw "$group"; then
      echo "User $username is already a member of group $group" >> "$user_log_file"
    else
      usermod -aG "$group" "$username"
      echo "Added user $username to group $group" >> "$user_log_file"
    fi
  done

done < "$user_list_file"

echo "User creation and group assignment completed."

exit 0

