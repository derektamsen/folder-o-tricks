#!/usr/bin/env bash

# This script will generate a floppy disk image and save it to the location specified.
# It will then add the kickstart file to the disk image.


if [[ $# -gt 0 ]]; then
    
    # Get the os name the script is runnig on
    OS="`uname -s`"
    echo "This script is running on ${OS}"
    
    # Set the floppy disk volume name
    VOLNAME="KS"
    
    # Grabs command line parameters for linking files
    for i in "$@"
    do
        case $i in
            --imagelocation=* | -o=*)
                # Where to save the floppy disk image
                IMGSAVE="`echo $i | sed 's/[-a-zA-Z0-9]*=//'`"
            ;;
            
            --kickstartfile=* | -k=*)
                # Kickstart file to inject into the floppy image
                KSFILE="`echo $i | sed 's/[-a-zA-Z0-9]*=//'`"
            ;;
            
            *)
                # Unknown option
                echo "Unknown option! Please specify: ${0} --imagelocation=<place_to_save_img_file> --kickstartfile=<kickstart_file>"
                exit 1
            ;;
        esac
    done
    
    # Find out if the image already exists and ask the user if they want to overwrite it
    if [[ -a "${IMGSAVE}" ]]; then
        until [[ "${OVERWRITE}" == "y" || "${OVERWRITE}" == "Y" || "${OVERWRITE}" == "n" || "${OVERWRITE}" == "N" ]]; do
            read -p "\"Overwrite ${IMGSAVE}\"? [y/N]: " OVERWRITE
            OVERWRITE="${OVERWRITE:-n}"
        done
    fi
    
    # Create the floppy disk image file with dd if it does not exist or the user wants to overwrite it
    if [[ "${OVERWRITE}" == "y" || "${OVERWRITE}" == "Y" || ! -a "${IMGSAVE}" ]]; then
        echo "Creating the floppy image \"${IMGSAVE}\""
        # Mac and Linux have different commands for formating and mounting devices
        case "${OS}" in
            
            # Mac OS X / Darwin
            "Darwin")
                # Create the floppy image and format it for msdos
                echo "Creating and Formatting the floppy image using hdutil"
                hdiutil create -ov -volname "${VOLNAME}" -sectors 2880 -fs "MS-DOS" -layout NONE "${IMGSAVE}"
                mv -f "${IMGSAVE}.dmg" "${IMGSAVE}"
                
                # Mount the disk image and grab some info about it
                echo "Mounting ${IMGSAVE}"
                MOUNTINFO="`hdiutil attach ${IMGSAVE}`"
                MOUNTPOINT="`echo ${MOUNTINFO} | awk '{print $2}'`"
                
                # Add the kickstart file to the floppy image
                echo "Adding the kickstart file \"${KSFILE}\""
                cp -f "${KSFILE}" "${MOUNTPOINT}/"
                
                # Eject the image
                echo "Ejecting the disk image"
                hdiutil detach "${MOUNTPOINT}"
            ;;
            
            # Linux OS
            "Linux")
                # Create an empty image file
                echo "Formatting the floppy image using dd and mkfs"
                dd if="/dev/zero" of="${IMGSAVE}" bs=512 count=2880
                
                # Format the flopy image
                echo "Formatting the floppy image"
                mkfs.msdos "${IMGSAVE}"
                
                # Mount the floppy image
                # Generate a random number so we can mount the image to it
                # and make sure we don't step on anything
                UNIQUE="`echo ${RANDOM}`"
                MOUNTPOINT="/tmp/KS.${UNIQUE}"
                
                echo "Mounting the floppy image to: ${MOUNTPOINT}"
                mkdir -p "${MOUNTPOINT}"
                sudo mount -o loop "${IMGSAVE}" "${MOUNTPOINT}"
                
                # Add the kickstart file to the floppy image
                echo "Adding the kickstart file \"${KSFILE}\""
                cp -f "${KSFILE}" "${MOUNTPOINT}/"
                
                # Eject the image and clean up the tmp path
                echo "Ejecting the disk image"
                sudo umount "${MOUNTPOINT}"
                rm -f "${MOUNTPOINT}"
            ;;
            
            # Unknown OS
            *)
                echo "Support for ${OS} has not been implemented yet."
                exit 1
            ;;
        esac
        
        # Check to see if everything is good
        if [[ $? -eq "0" ]]; then
            echo -e "\n\nThe image has been successfully created at: ${IMGSAVE}"
        else
            echo -e "\n\nError creating the kickstart floppy image"
            exit 1
        fi
        
    else
        echo "aborting creation of new disk image"
        exit 1
    fi


else
    echo "Unknown option! Please specify: ${0} --imagelocation=<place_to_save_img_file> --kickstartfile=<kickstart_file>"
    exit 1
fi