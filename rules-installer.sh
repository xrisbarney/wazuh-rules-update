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
    echo -e "\e[91m✘ The specified file '$SOURCE' does not exist.\e[0m"
    exit 1
  fi

  if [ ! -r "$SOURCE" ]; then
    echo -e "\e[91m✘ Cannot read the specified file '$SOURCE'. Check file permissions.\e[0m"
    exit 1
  fi

  # Check if the file is a text file
  if ! file -b --mime-type "$SOURCE" | grep -q "^text/"; then
    echo -e "\e[91m✘ The specified file '$SOURCE' is not a text file.\e[0m"
    exit 1
  fi

  SOURCE_CONTENT=$(cat "$SOURCE")

  # Check if the content starts with "<group>"
  if [[ ! "$SOURCE_CONTENT" =~ \<group.* ]]; then
    echo -e "\e[93m⚠️  Source content does not start with '<group>'. Updating the source content to start with <group>.\e[0m"
    echo '<group name="local,automated,">' | cat - "$SOURCE" > temp && mv temp "$SOURCE"
  else
    echo -e "\e[32m\u2713 Source content starts with '<group>'. XML validation 1 passed. \e[0m"
  fi

  # Check if the content ends with "</group>"
  if [[ ! "$SOURCE_CONTENT" =~ \</group\>$ ]]; then
    echo -e "\e[93m⚠️  Source content does not end with '</group>'. Updating the source content to end with </group>.\e[0m"
    echo '</group>' >> "$SOURCE"
  else
    echo -e "\e[32m\u2713 Source content ends with '</group>'. XML validation 2 passed. \e[0m"
  fi
}

validate_remote_source() {
  echo "Validating remote source"
  # Check if the URL is valid
  if ! curl --output /dev/null --silent --head --fail "$SOURCE"; then
    echo -e "\e[91m✘ The specified URL '$SOURCE' is not valid.\e[0m"
    exit 1
  fi

  # Check if the URL is reachable
  if ! curl --output /dev/null --silent --head --fail "$SOURCE"; then
    echo -e "\e[91m✘ The specified URL '$SOURCE' is not reachable.\e[0m"
    exit 1
  fi

  echo "Downloading the rules file to $LOCAL_FILE"

  # Download the file
  if ! curl -o "$LOCAL_FILE" -sfL "$SOURCE"; then
    echo -e "\e[91m✘ Unable to download the file from '$SOURCE'.\e[0m"
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

validate_rule_ids() {
  local VALIDATION_SOURCE="$1"

  IDS_TO_VALIDATE=$(grep -o '<rule id="[0-9]*"' "$VALIDATION_SOURCE" | sed 's/<rule id="\([0-9]*\)"/\1/')

  for VALID_ID in $IDS_TO_VALIDATE; do
    if [ "$VALID_ID" -lt 100000 ] || [ "$VALID_ID" -gt 120000 ]; then
      echo -e "\e[91m✘ Rule ID $VALID_ID in $VALIDATION_SOURCE is not in the custom rules range. Please update the rule ID to a value within 100000 and 120000\e[0m"
      exit 1
    fi
  done

  EXISTING_RULE_IDS=$(find "/var/ossec/etc/rules" -type f -name '*.xml' -exec grep -o '<rule id="[0-9]*"' {} \; | sed 's/<rule id="\([0-9]*\)"/\1/')

  for ID in $EXISTING_RULE_IDS; do
    grep -q "<rule id=\"$ID\"" "$VALIDATION_SOURCE" && echo -e "\e[91m✘ Rule ID $ID in $VALIDATION_SOURCE already exists. Please update the associated rule IDs to use free IDs between 100000 and 120000.\e[0m" && exit 1
  done

}

validate_destination() {

  filename=$(basename "$DESTINATION")

  # Check if the file path exists
  if [ "$filename" != "local_rules.xml" ] && [ -e "$DESTINATION" ]; then
      echo -e "\e[91m✘ Destination rule file /var/ossec/etc/rules/$DESTINATION already exists. Exiting.\e[0m"
      exit 1
  fi
}

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

# process local rule installation
if [ "$TYPE" == "local" ]; then
  # Process for local source
  validate_local_source
  validate_destination
  validate_rule_ids "$SOURCE"
  if [ "$DESTINATION" = "/var/ossec/etc/rules/local_rules.xml" ]; then
      echo "Updating the rules files $DESTINATION"
      cat "$SOURCE" >> "$DESTINATION"
      echo -e "\e[32m\u2713 $DESTINATION rules file updated with the new rules. \e[0m"
  else
      cp "$SOURCE" "$DESTINATION"
      echo -e "\e[32m\u2713 Rules file created in /var/ossec/etc/rules/$DESTINATION. \e[0m"
  fi

# process remote rule installation
elif [ "$TYPE" == "remote" ]; then
  # Process for remote source
  validate_remote_source
  validate_destination
  validate_rule_ids "$LOCAL_FILE"
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

# Optional, restart the Wazuh manager
if [ "$RESTART" == "yes" ]; then
  echo "Restarting..."
  restart_output=$(systemctl restart wazuh-manager 2>&1)
  
  if echo "$restart_output" | grep -q 'failed'; then
    echo -e "\e[91m❌ ERROR: Wazuh manager restart failed please check the logs for error messages.
$restart_output\e[0m"
    exit 1
  else
    echo -e "\e[32m\u2713 Restart completed. \e[0m"
  fi
else
  echo -e "\e[93m⚠️  WARNING: Wazuh manager not restarted, these rules will not take effect until the manager is restarted. Run the command below to restart the Wazuh manager:\e[0m
  \e[93msystemctl restart wazuh-manager\e[0m"
fi