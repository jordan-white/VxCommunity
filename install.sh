#!/bin/bash
# VxStream Sandbox installer for automated installation of VxStream Sandbox

# Copyright (C) 2016 Payload Security UG (haftungsbeschränkt)
#
# Licensed  GNU GENERAL PUBLIC LICENSE, Version 3, 29 June 2007
# see https://github.com/PayloadSecurity/VxCommunity/blob/master/LICENSE.md
#
# Date - 1.09.2016
# Version - 1.0.0

# Functions:
#
# * usage
# * cleanHost
# * conf
# * checks
# * main
# * commandOutput
# * success
# * failure

# Instructions:
#
# chmod +x install.sh
# sudo ./install.sh
#

# * Exit code 0 - Successfully exit 
# * Exit code 1 - General error
# * Exit code 126 - Run as root

# Version
version="1.0.0"

# User validation for installing 

echo -e "\n#----------------------- VxStream Sandbox Installer ------------------------#" >&2
echo "#---- This is an experimental beta-script and may not work as expected! ----#" >&2
echo -e "#---------------------------------------------------------------------------#\n" >&2

# Make sure script is not run as root

if [ "$(id -u)" -eq 0 ]; then
    echo "Please do not run this script as root."
    echo "You will be asked for root rights if the script will continue successfully to VxBootstrapUI initalization."
    exit 126
fi

# Usage options

usage() {

    echo "Copyright (C) 2016 Payload Security"
    echo "Version: $version"
    echo -e "\nDescription:"
    echo "VxStream Sandbox installer for automated installation of VxStream Sandbox."
    echo "This scipt will download necessary resources and continue with the installation of VxStream Sandbox."
    echo -e "\nUsage:"
    echo -e  " $0 commands [parameters]\n"
    echo "Commands:"
    echo " --password          [Required] Password used for downloading resources"
    echo -e "\nParameters:"
    echo " -h, --help          Print this help message"
    echo " -v, --verbose       Print verbose messages to stdout (debugging mode)"
    echo -e "\nPlease use single quotes around command line arguments.\n"
    echo "Example:" 
    echo -e " $0 --password 'insertpasswordhere'\n"
    exit 1

}

# Command line arguments parsing

args=":hv-:"
while getopts "$args" optchar; do 
    case "${optchar}" in
        -)
            case "${OPTARG}" in
                password)
                    gpgPassword="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                    ;;
                help)
                    usage
                    exit 1
                    ;;
                verbose)
                    set -o xtrace
                    ;;
                *)
                    if [ "$OPTERR" != 1 ] || [ "${args:0:1}" = ":" ]; then
                        echo "Unknown option --${OPTARG}" >&2
                        echo "Try '$0 --help' for more information" >&2
                        exit 1
                    fi
                    ;;
            esac;;
        h)
            usage
            exit 1
            ;;
        v)
            set -o xtrace
            ;;
        *)
            if [ "$OPTERR" != 1 ] || [ "${args:0:1}" = ":" ]; then
                echo "Non-option argument: '-${OPTARG}'" >&2
                echo "Try '$0 --help' for more information" >&2
                exit 1
            fi
            ;;
    esac
done

# If no correct arguments were passed, then exit

if [ $OPTIND -eq 1 ]; then

    echo "No valid arguments were passed. Exiting..." >&2
    echo "Try '$0 --help' for more information" >&2
    exit 1

fi

# Check for correct number of arguments 

if [[ "$#" -lt 2 || "$#" -gt 3 ]]; then

    echo "Invalid number of arguments..."
    echo "Try '$0 --help' for more information" >&2
    exit 1

fi

# Clean-up trap exec
trap cleanHost EXIT

# Clean-up trap

cleanHost() {

    # If exit code is greater than 0, then clean the host
    if [ $? -gt 0 ]; then

        # Cleanup the installation directory 
        failure
        echo "Fatal error caught. Cleaning up ..."
        cd "$installDir" && find -not -name '*log*' | tail -n +2 | xargs rm -f
    fi
}

# Configuration

conf() {

    # Get working directory 
    DIR=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)

    # Installation directory
    installDir="$DIR"/vxstreaminstallation

    # Generate an installation directory
    test -d "$installDir" || mkdir -p "$installDir" && cd "$installDir"

    # Enable logging
    logFile=""$installDir"/install.log"
    echo -e "\nStarting install.sh... \nTimestamp:" >> "$logFile" && date >> "$logFile"
    exec &> >(tee -a "$logFile")

    # Export user who executed the script
    export installUser=$(whoami)

    # Make sure .ssh dir and known_hosts file exist
    test -d ~/.ssh/ || mkdir ~/.ssh
    test -f ~/.ssh/known_hosts || touch ~/.ssh/known_hosts

    # Decrypted authentication key file name
    decryptedKeyFile=""$installDir"/vxinstaller.key"

    # Authentication key file name
    authKeyFileName="vxinstallerkey.gpg"

    # Authentication key URL
    authKeyURL="https://www.payload-security.com/download.php?file=$authKeyFileName"

    # Correct authentication key type
    correctFileType="$(echo -e "application/octet-stream" | tr -d '[[:space:]]')"

    # Get authentication key type
    fileTypeNow=$(curl -A "VxStream Sandbox" -ISsk "$authKeyURL" 2>> "$logFile" | grep "Content-Type:" | awk {'print $2'})
    fileTypeNow="$(echo -e "${fileTypeNow}" | tr -d '[[:space:]]')"

    # Get the status code of curl
    curlStatusCode=$(curl -A "VxStream Sandbox" -ISsk "$authKeyURL" 2>> "$logFile" | head -n 1 | cut -d$' ' -f2)

}

# Run mandatory checks 

checks() {

    echo -e "----------------- Mandatory Checks ----------------\n"

    # Check if curl works 
    curl -s -S www.google.com >> "$logFile" 2>&1 

    if [ $? -eq 0 ]; then
        success && echo "Curl is working"
    else
        failure
        echo "Fatal error: curl isn't working"
        echo "See $logFile for more information. Exiting..."
        exit 1
    fi

    # Check if Git works
    git --version >> "$logFile" 2>&1

    if [ $? -eq 0 ]; then
        success && echo -e "Git is working\n"
    else
        failure
        echo "Fatal error: Git isn't working. Make sure Git is installed"
        echo "See $logFile for more information. Exiting..."
        exit 1
    fi

    # If curl status code for downloading authentication key was not 200, then quit

    if [ "$curlStatusCode" == "200" ]; then

        success
        echo "Authentication key can be fetched from remote server"
    else

        failure
        echo "Fatal error: authentication key can not be fetched from remote server: $authKeyURL"
        echo "Curl status code: $curlStatusCode"
        echo "Please contact Payload Security. Exiting..."
        exit 1
    fi

    # Make sure authentication key type is correct
    if [ "$fileTypeNow" == "$correctFileType" ]; then

        success
        echo -e "Authentication key type is correct: $fileTypeNow\n"
    else

        failure
        echo "Fatal error: authentication key type is not correct: $fileTypeNow"
        echo "Please contact Payload Security. Exiting..."
        exit 1
    fi

}

# Download authentication key, repositories and initialize VxBootstrapUI 

main() {

    echo -e "----------------------- Main ----------------------\n"

    # Download authentication key
    curl -A "VxStream Sandbox" -k -s -S "$authKeyURL" -o "$installDir"/vxinstallerkey.gpg 2>> "$logFile" && success && echo "Successfully downloaded authentication key" || {

        failure
        echo "Fatal error: failed to download authentication key"
        echo "See $logFile for more information. Exiting..."
        exit 1
    }

    # Decrypt the authentication key
    gpg -q --yes --passphrase "$gpgPassword" --decrypt --output "$decryptedKeyFile" "$installDir"/"$authKeyFileName" 2>> "$logFile" && success && echo -e "Successfully decrypted authentication key\n" || {

        failure
        echo "Fatal error: failed to decrypt authentication key"
        echo "See $logFile for more information. Exiting..."
        exit 1
    }

    # Check if authKeyVxBootstrapUI is correct
    head -27 "$decryptedKeyFile" > "$installDir"/authKeyVxBootstrapUI && chmod 600 "$installDir"/authKeyVxBootstrapUI && ssh-keygen -P "" -y -e -f "$installDir"/authKeyVxBootstrapUI >> "$logFile" 2>&1 && success && echo "VxBootstrapUI authentication key is correct" || {

        failure
        echo "Fatal error: VxBootstrapUI authentication key is invalid"
        echo "See $logFile for more information. Exiting..."
        exit 1
    }

    # Check if authKeyVxBootstrap is correct
    tail -28 "$decryptedKeyFile" > "$installDir"/authKeyVxBootstrap && chmod 600 "$installDir"/authKeyVxBootstrap && ssh-keygen -P "" -y -e -f "$installDir"/authKeyVxBootstrap >> "$logFile" 2>&1 && success && echo -e "VxBootstrap authentication key is correct\n" || {

        failure
        echo "Fatal error: VxBootstrap authentication key is invalid"
        echo "See $logFile for more information. Exiting..."
        exit 1
    }

    # Add Github as trusted host
    ssh-keyscan -t rsa -H github.com >> ~/.ssh/known_hosts && success && echo -e "Successfully added Github as a trusted host\n" || {

        failure
        echo "Fatal error: failed to add Github as trusted host"
        echo "See $logFile for more information. Exiting..."
        exit 1
    }

    # Download VxBootstrapUI
    echo "Downloading VxBootstrapUI..." && ssh-agent bash -c "ssh-add "$installDir"/authKeyVxBootstrapUI >> "$logFile" 2>&1 ; git clone git@github.com:PayloadSecurity/VxBootstrapUI.git >> "$logFile" 2>&1"

    if [ $? -eq 0 ]; then
        success && echo -e "Successfully downloaded VxBootstrapUI\n"
    else
        failure
        echo "Fatal error: Was not able to download VxBootstrapUI."
        echo "See $logFile for more information. Exiting..."
        exit 1
    fi

    # Download VxBootstrap 
    echo "Downloading VxBootstrap..." && ssh-agent bash -c "ssh-add "$installDir"/authKeyVxBootstrap >> "$logFile" 2>&1 ; git clone git@github.com:PayloadSecurity/VxBootstrap.git >> "$logFile" 2>&1"

    if [ $? -eq 0 ]; then
        success && echo -e "Successfully downloaded VxBootstrap\n"
    else
        failure
        echo "Fatal error: Was not able to download VxBootstrap."
        echo "See $logFile for more information. Exiting..."
        exit 1
    fi
    
    # Create a soft link of VxBootstrap to user home dir if it does not exist yet
    test -d $HOME/VxBootstrap

    if [ $? -ne 0 ]; then

        ln -s "$installDir"/VxBootstrap $HOME >> "$logFile" 2>&1 && success && echo "Successfully created a softlink of VxBootstrap to $HOME" || {

            failure
            echo "Failed to create a softlink of VxBootstrap to $HOME"
            echo "See $logFile for more information"
        }
    fi
    
    # Set write permissions to the configuration file (used later by the UI)
    echo "Adding write permissions to the bootstrap configuration file..." && chmod 666 "$installDir"/VxBootstrap/bootstrap.cfg > /dev/null 2>> "$logFile" && success && echo -e "Successfully changed permissions\n" || {
        failure
        echo "Fatal error: failed to set correct permissions for "$installDir"/VxBootstrap/bootstrap.cfg. Exiting..."
        exit 1
    }

    # Initialize VxBootstrapUI 
    echo -e "Initializing VxBootstrapUI [need root rights]...\n" && sudo -k

    # Promt for user password until a correct password has been provided
    while [[ "$userId" != 0 ]]; do

        echo -n "[sudo] password for $installUser": 
        read -s installUserPassword

        # Check if given password is correct 
        userId=$(echo "$installUserPassword" | sudo -S id -u 2> /dev/null)

        if [ "$userId" = 0 ]; then 
            declare -x installUserPassword=$installUserPassword
        else
            echo -e "\nSorry, the provided password is incorrect. Please try again!"
        fi

    done

    # Add init.sh to sudoers
    echo "$installUserPassword" | sudo -S bash -c "echo \"$installUser ALL=(ALL) NOPASSWD:SETENV: $installDir/VxBootstrapUI/scripts/init.sh\" >> /etc/sudoers"

    # Execute VxBootstrapUI installer
    cd "$installDir"/VxBootstrapUI/scripts && sudo installUser="$installUser" installUserPassword="$installUserPassword" termColumns="$termColumns" ./init.sh

}

# Success and error message colouring

commandOutput() {

    # Column number to place the status message
    termColumns=$(tput cols)
    messageColumn=$((termColumns-20))

    # Command to move out to the configured column number
    moveToColumn="echo -en \\033[${messageColumn}G"

    # Command to set the color to SUCCESS (Green)
    setColorSuccess="echo -en \\033[32m"

    # Command to set the color to FAILED (Red)
    setColorFailure="echo -en \\033[31m"

    # Command to set the color back to normal
    setColorNormal="echo -en \\033[0;39m"

}

# Function to print the SUCCESS status message

success() {

    $moveToColumn
    echo -n "["
    $setColorSuccess
    echo -n $"  OK  "
    $setColorNormal
    echo -n "]"
    echo -ne "\r"
}

# Function to print the FAILED status message

failure() {
    
    $moveToColumn
    echo -n "["
    $setColorFailure
    echo -n $"FAILED"
    $setColorNormal
    echo -n "]"
    echo -ne "\r"
}

# Call out functions
commandOutput
conf
checks
main
