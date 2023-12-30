#!/bin/bash

print_help() {
  echo "Description: This script is used to update the rules for the Wazuh manager. This script has to be run as root or the wazuh user."
  echo "Usage: ./rules-installer.sh [-t|--type <local/remote>] [-s|--source <url/filename>] [-d|--destination <destination>] [-r|--restart <yes/no>] [-h|--help]"
  echo "Example: ./rules-installer.sh -t local -s cobalt_strike_rules.txt -d cobalt_strike_rules -r yes"
  exit 1
}

print_version() {
  echo "Version: 1.0
Author: Chris Bassey https://github.com/xrisbarney
Release date: 30.12.2023"
  echo "Description: This script is used to update the rules for the Wazuh manager. This script has to be run as root or the wazuh user."
  exit 1
}

validate_local_source() {
  echo "Validating local source"
  if [ ! -f "$SOURCE" ]; then
    echo "Error: The specified file '$SOURCE' does not exist."
    exit 1
  fi

  if [ ! -r "$SOURCE" ]; then
    echo "Error: Cannot read the specified file '$SOURCE'. Check file permissions."
    exit 1
  fi

  # Check if the file is a text file
  if ! file -b --mime-type "$SOURCE" | grep -q "^text/"; then
    echo "Error: The specified file '$SOURCE' is not a text file."
    exit 1
  fi

  SOURCE_CONTENT=$(cat "$SOURCE")

  # Check if the content starts with "<group>"
  if [[ ! "$SOURCE_CONTENT" =~ \<group.* ]]; then
    echo "Source content does not start with '<group>'. Updating the source content to start with <group>."
    echo '<group name="local,automated,">' | cat - "$SOURCE" > temp && mv temp "$SOURCE"
  else
    echo -e "\e[32m\u2713 Source content starts with '<group>'. XML validation 1 passed. \e[0m"
  fi

  # Check if the content ends with "</group>"
  if [[ ! "$SOURCE_CONTENT" =~ \</group\>$ ]]; then
    echo "Source content does not end with '</group>'. Updating the source content to end with </group>."
    echo '</group>' >> "$SOURCE"
  else
    echo -e "\e[32m\u2713 Source content ends with '</group>'. XML validation 2 passed. \e[0m"
  fi
}

validate_remote_source() {
  # Check if the URL is valid
  if ! curl --output /dev/null --silent --head --fail "$SOURCE"; then
    echo "Error: The specified URL '$SOURCE' is not valid."
    exit 1
  fi

  # Check if the URL is reachable
  if ! curl --output /dev/null --silent --head --fail "$SOURCE"; then
    echo "Error: The specified URL '$SOURCE' is not reachable."
    exit 1
  fi

  echo "Downloading the rules file to $LOCAL_FILE"

  # Download the file
  if ! curl -o "$LOCAL_FILE" -sfL "$SOURCE"; then
    echo "Error: Unable to download the file from '$SOURCE_URL'."
    exit 1
  fi

  SOURCE_CONTENT=$(cat "$LOCAL_FILE")

  # Check if the content starts with "<group>"
  if [[ ! "$SOURCE_CONTENT" =~ \<group.* ]]; then
    echo "Source content does not start with '<group>'. Updating the source content to start with <group>."
    echo '<group name="local,automated,">' | cat - "$SOURCE" > temp && mv temp "$SOURCE"
  else
    echo -e "\e[32m\u2713 Source content starts with '<group>'. XML validation 1 passed. \e[0m"
  fi

  # Check if the content ends with "</group>"
  if [[ ! "$SOURCE_CONTENT" =~ \</group\>$ ]]; then
    echo "Source content does not end with '</group>'. Updating the source content to end with </group>."
    echo '</group>' >> "$SOURCE"
  else
    echo -e "\e[32m\u2713 Source content ends with '</group>'. XML validation 2 passed. \e[0m"
  fi
}

# validate_rule_ids() {


# }

if [ "$#" -eq 0 ]; then
  print_help
  exit 1
fi

SOURCE=""
DESTINATION="/var/ossec/etc/rules/local_rules.xml"
TYPE="local"
RESTART="yes"
LOCAL_FILE="/tmp/temporary_wazuh_rules_file.txt"

while [[ "$#" -gt 0 ]]; do
  case $1 in
    -t|--type)
      TYPE="$2"
      # check if the type is local.
      shift
      ;;
    -s|--source)
      SOURCE="$2"
      shift
      ;;
    -d|--destination)
      DESTINATION="$2"
      shift
      ;;
    -r|--restart)
      RESTART="$2"
      shift
      ;;
    -h|--help)
      print_help
      ;;
    -v|--version)
      print_version
      ;;
    *)
      echo "Unknown parameter: $1"
      print_help
      ;;
  esac
  shift
done

if [ "$EUID" -ne 0 ] && [ "$(whoami)" != "wazuh" ]; then
  echo "Please run this script as root or the wazuh user."
  exit 1
fi

echo "Source: $SOURCE"
echo "Type: $TYPE"
echo "Destination: $DESTINATION"
echo "Restart: $RESTART"

# Add your logic here for processing the options

# Example:
if [ "$TYPE" == "local" ]; then
  # Process for local source
  validate_local_source
  if [ "$DESTINATION" = "/var/ossec/etc/rules/local_rules.xml" ]; then
      echo "Updating the rules files $DESTINATION"
      cat "$SOURCE" >> "$DESTINATION"
      echo -e "\e[32m\u2713 $DESTINATION rules file updated with the new rules. \e[0m"
  else
      cp "$SOURCE" "$DESTINATION"
      echo -e "\e[32m\u2713 Rules file created in /var/ossec/etc/rules/$DESTINATION. \e[0m"
  fi
  
elif [ "$TYPE" == "remote" ]; then
  # Process for remote source
  validate_remote_source
  if [ "$DESTINATION" = "/var/ossec/etc/rules/local_rules.xml" ]; then
      echo "Updating the rules files $DESTINATION"
      cat "$LOCAL_FILE" >> "$DESTINATION"
      echo -e "\e[32m\u2713 $DESTINATION rules file updated with the new rules. \e[0m"
  else
      cp "$LOCAL_FILE" "$DESTINATION"
      echo -e "\e[32m\u2713 Rules file created in /var/ossec/etc/rules/$DESTINATION. \e[0m"
  fi
  
else
  echo "Invalid source option"
  exit 1
fi

# Optionally, restart logic
if [ "$RESTART" == "yes" ]; then
  echo "Restarting..."
  systemctl restart wazuh-manager
  echo "Restart completed"
else
  echo "Waxuh manager not restarted, these rules will not take effect until the manager is restarted. Run the command below to restart the Wazuh manager:
systemctl restart wazuh-manager"
fi