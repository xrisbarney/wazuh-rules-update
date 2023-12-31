# Wazuh Rules Installer Script Documentation
## Description
The Wazuh Rules Installer script is designed to add custom rules for to your Wazuh manager. It provides options for both local and remote rule installations, allowing users to specify the source, destination, and whether to restart the Wazuh manager after installation. The script is intended to be run as root or the Wazuh user.

## Usage
```
./rules-installer.sh [-t|--type <local/remote>] [-s|--source <url/filename>] [-d|--destination <destination>] [-r|--restart <yes/no>] [-h|--help]
```
### Options

`-t|--type <local/remote>`: Specifies the type of rule installation, either local or remote.

`-s|--source <url/filename>`: Specifies the source of rules, either a URL for remote installation or a filename for local installation.

`-d|--destination <destination>`: Specifies the destination file name for the rules. Put only the file name, no path and the file name should end with .xml. The file will be created in `/var/ossec/etc/rules/`. If the destination file name is not specified, it adds the rules to local_rules.xml. 

`-r|--restart <yes/no>`: Specifies whether to restart the Wazuh manager after rule installation. The default behaviour is to restart.

`-h|--help`: Displays the help message.

`-v|--version`: Displays the script version information.

### Examples
#### Local rule installation
```./rules-installer.sh -t local -s cobalt_strike_rules.txt -d cobalt_strike_rules -r yes```

#### Remote rule installation
```./rules-installer.sh -t remote -s https://example.com/rules/custom_rules.xml -d local_rules.xml -r yes```

## Version Information
Version: 1.0

Author: Chris Bassey (https://github.com/xrisbarney)

Release Date: 31.12.2023

## ⚠️ Disclaimer
This script is provided as-is and has not been extensively tested. Use it at your own risk. The author and contributors are not responsible for any issues or damages caused by the use of this script. It is recommended to review and understand the script before executing it in a production environment.

## Notes
- The script must be run as root or the Wazuh user.
- Ensure proper file permissions for the specified source file.
- The Wazuh manager may need to be restarted for rule changes to take effect.
- This documentation provides a high-level overview of the script's functionality. Users are advised to review the script's code for detailed understanding and customization.