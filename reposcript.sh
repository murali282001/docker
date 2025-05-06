#!/bin/bash

# #################################
# Author: Murali
# Date: 01/08/2025
#
# This script downloads and extracts repository files
#
# Version: v2
# ##################################

# Set current date and time
current_date_time=$(date +"%Y-%m-%d_%H-%M-%S")

# Log file to record script activities
LOG_FILE="/tmp/Extraction_logs/script_log_${current_date_time}.log"

# Repo location file used to store all project repository locations
Repo_location_file="/tmp/Extraction_logs/Repo_Location_${current_date_time}.txt"

# Error and warning message file location
Error_message="/tmp/Extraction_logs/Error_Message_${current_date_time}.log"
Warning_message="/tmp/Extraction_logs/Warning_Message_${current_date_time}.log"

# Error message while extraction
ERROR_OUTPUT="/tmp/Extraction_logs/Extraction_error_${current_date_time}.log"

# loading the dbid.xmls from all repo files and store in one location
DBID_XML_FILES="/tmp/Extraction_logs/Dbid.xmlfiles_${current_date_time}"


# Color codes for log levels
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'


# CSV file containing input data
CSV_FILE="inputs_file.csv"

# Skip the first row and empty lines, count total valid rows
total_projects=$(awk 'NR > 1 && NF > 0' "$CSV_FILE" | wc -l)

# Initialize the projects counter
current_project=0

# Function to log errors
log_error() {
    echo -e "${RED}$(date +"%Y-%m-%d_%H-%M-%S") ERROR: $1${NC}" | tee -a "$Error_message"
    echo -e "${RED}$(date +"%Y-%m-%d_%H-%M-%S") ERROR: $1${NC}" | tee -a "$LOG_FILE"
}

# Function to log warnings
log_warning() {
    echo -e "${YELLOW}$(date +"%Y-%m-%d_%H-%M-%S") WARNING: $1${NC}" | tee -a "$Warning_message"
    echo -e "${YELLOW}$(date +"%Y-%m-%d_%H-%M-%S") WARNING: $1${NC}" | tee -a "$LOG_FILE"
}

# Function to log info messages
log_info() {
    echo -e "${GREEN}$(date +"%Y-%m-%d_%H-%M-%S") INFO: $1${NC}" | tee -a "$LOG_FILE"
}

# Check if Extraction_logs directory is present under the /tmp directory; if not, create it. Otherwise, skip creation.
if [[ ! -d "/tmp/Extraction_logs" ]]; then
    echo  "Start to create the directory in temp directory: Extraction_logs."
    sudo mkdir /tmp/Extraction_logs
    sudo chown -R alm_service.'domain users' /tmp/Extraction_logs
    sudo chmod -R 775 /tmp/Extraction_logs
    echo "completed to create the Extraction_logs directory."
else
    echo "Extraction_logs directory already present under temp directory, skipping creation."
fi

# Read the CSV file line by line, skipping the header
while IFS=, read -r Location Domain_Name CL_PRO_NAME  S3_URL Download Extraction Zip_Delete File_Type; do
    if [[ "$Location" == "Location" || -z "$Location" ]]; then
         continue  # Skip the header row or empty Location fields
    fi
    ((current_project++))
    project_name=$(basename "$S3_URL")
    # Validate required fields
    if [[ -z "$Location" || -z "$Domain_Name" || -z "$CL_PRO_NAME" || -z "$S3_URL" ]]; then
        log_info "#####################################################################################################################################################"
        log_warning "project= $current_project/$total_projects, Skipping row due to missing required fields"
        continue
    fi

    case "$project_name" in

        *.qcp)
            log_info "#####################################################################################################################################################"
            log_info "qcp project= $current_project/$total_projects, Processing Location: $Location, Domain_Name: $Domain_Name, CLIENT_PROJECT_NAME: $CL_PRO_NAME, S3_URL: $S3_URL, FILE_TYPE: $File_Type"

            cd "$Location" || { log_error "Failed to change directory to $Location"; continue; }
            cd ..  # Move one level up

            if [ ! -d "archive" ]; then
                log_warning "Archive folder is not present, creating now."
                mkdir archive
                chmod 775 archive -R
                log_info "Archive folder created successfully with permission 775."
            else
                log_info "Archive folder already present."
            fi

            cd archive

            if [ ! -d "$Domain_Name" ]; then
                log_warning "$Domain_Name folder is not present, creating now."
                mkdir "$Domain_Name"
                chmod 775 "$Domain_Name" -R
                log_info "$Domain_Name folder created successfully with permission 775."
            else
                log_info "$Domain_Name folder already present."
            fi

            cd "$Domain_Name"

            if [ ! -d "$CL_PRO_NAME" ]; then
                log_warning "$CL_PRO_NAME folder is not present, creating now."
                mkdir "$CL_PRO_NAME"
                chmod 775 "$CL_PRO_NAME" -R
                log_info "$CL_PRO_NAME folder created successfully with permission 775."
            else
                log_info "$CL_PRO_NAME folder already present."
            fi

            cd "$CL_PRO_NAME"

            sudo aws s3 cp "$S3_URL" . || { log_error "Failed to download $S3_URL"; continue; }
            # Rename and process files based on File_Type
            log_info "Raw File_Type: '$File_Type'"
            File_Type=$(echo "$File_Type" | tr -d '[:space:]')
            log_info "Trimmed File_Type: '$File_Type'"

            if [[ "$File_Type" == "ST" ]]; then
               new_name="ST_operas_$(date +"%Y-%m-%d_%H-%M-%S").qcp"
               mv "$project_name" "$new_name"
               log_info "Renamed $project_name to $new_name"
            elif [[ "$File_Type" == "T" ]]; then
               new_name="T_operas_$(date +"%Y-%m-%d_%H-%M-%S").qcp"
               mv "$project_name" "$new_name"
               log_info "Renamed $project_name to $new_name"
            else
               log_warning "Unexpected file type for $project_name - '$File_Type'. Ensure that the file type is 'ST' for project files and 'T' for template files."
            fi
            sudo chown alm_service.'domain users' -R *
            sudo chmod 775  -R *
            log_info "$(ls -la)"
            continue
            ;;

        *)
            log_info "#####################################################################################################################################################"
            # Validate Download, Extraction, and Zip_Delete values
            if [[ "$Download" != "YES" && "$Download" != "NO" ]]; then
               log_warning "Unexpected value for Download ($Download) in Location $Location. Defaulting to 'NO'."
               Download="NO"
            fi
            if [[ "$Extraction" != "YES" && "$Extraction" != "NO" ]]; then
               log_warning "Unexpected value for Extraction ($Extraction) in Location $Location. Defaulting to 'NO'."
               Extraction="NO"
            fi
            if [[ "$Zip_Delete" != "YES" && "$Zip_Delete" != "NO" ]]; then
               log_warning "Unexpected value for Zip_Delete ($Zip_Delete) in Location $Location. Defaulting to 'NO'."
               Zip_Delete="NO"
            fi
            log_info "Project= $current_project/$total_projects Processing Location: $Location, Domain_Name: $Domain_Name, CLIENT_PROJECT_NAME: $CL_PRO_NAME, S3_URL: $S3_URL, Download: $Download, Extraction: $Extraction, Zip_Delete: $Zip_Delete, FILE_TYPE: $File_Type"

            # Find directory that matches Domain_Name pattern
            dir_path=$(find "$Location" -maxdepth 1 -type d -name "${Domain_Name}_*" -print -quit)

            if [[ -z "$dir_path" ]]; then
               log_error "Failed to find directory matching pattern ${Location}/${Domain_Name}_*"
               continue
            else
               log_info "Found directory: $dir_path"
            fi

            # Attempt to change to the found directory
            if cd "$dir_path"; then
                log_info "Changed to directory: $(pwd)"
            else
                log_error "Failed to change directory to $dir_path"
            continue
            fi
            # start Download Process

            if [[ "$Download" == "YES" ]]; then
                if [ -f "$project_name" ]; then
                    log_warning "$project_name already exists, skipping download."
                    continue
                else
                    log_info "$project_name does not exist, downloading."
                fi

                log_info "Downloading $project_name"
                if sudo aws s3 cp "$S3_URL" .; then
                    log_info "Download completed successfully: $project_name"
                else
                    log_error "Failed to download $project_name from S3."
                    continue
                fi

                sudo chown -R alm_service.'domain users' "$project_name"
                sudo chmod -R 775 "$project_name"

                if [[ $(stat -c "%U:%G" "$project_name") == "alm_service:domain users" && $(stat -c "%a" "$project_name") == "775" ]]; then
                    log_info "Validation successful: $project_name has correct ownership and permissions."
                else
                    log_error "Validation failed: $project_name does not have correct ownership or permissions."
                fi
                log_info "$(ls -la)"
                log_info "Size of the zipped file $project_name: $(du -sh "$project_name")"
            else
                log_warning "Skipped download of the repo $project_name file."
            fi

            if [[ "$Extraction" == "YES" ]]; then
            #    folder_name="${project_name%.*}"
                if [[ "$project_name" == *.tar.gz ]]; then
                  folder_name="${project_name%.tar.gz}"
                  log_info "$folder_name"
                else
                  folder_name="${project_name%.*}"
                  log_info "$folder_name"

                fi
                if [ -d "$folder_name" ]; then
                    log_warning "$folder_name already exists, skipping extraction."
                    continue
                else
                    log_info "$folder_name does not exist, extracting."
                fi
                echo "$folder_name"
                case "$project_name" in
                    *.zip)
                        log_info "Unzipping $project_name using 'jar xvf'"


                        counter=0

                        # Extract the files and show extraction progress with percentage
                       if jar xvf "$project_name" 2>"$ERROR_OUTPUT"  | while read -r line; do
                           ((counter++))

                           # Display a simple progress indicator (dots or count)
                           if (( counter )); then
                              printf "\rExtracted files: %d" "$counter"
                           fi
                       done; then

                           printf "\n"  # Move to the next line after completion
 #                          log_info "Successfully unzipped $project_name to $folder_name and files count is $counter"
                          log_info "Successfully unzipped $project_name to $folder_name"
                       else
                           # Log error if extraction fails
                           log_error "Failed to unzip $project_name: $(<"$ERROR_OUTPUT")"
                           continue
                        fi

                        ;;
                    *.7z)
                        log_info "Unzipping $project_name using '7za x'"


                        counter=0

                        # Extract the files and show extraction progress with percentage
                       if 7za x "$project_name" 2>"$ERROR_OUTPUT"  | while read -r line; do
                           ((counter++))

                           # Display a simple progress indicator (dots or count)
                           if (( counter )); then
                              printf "\rExtracted files: %d" "$counter"
                           fi
                       done; then

                           printf "\n"  # Move to the next line after completion
#                           log_info "Successfully unzipped $project_name to $folder_name and files count is $counter "
                           log_info "Successfully unzipped $project_name to $folder_name"
                       else
                           # Log error if extraction fails
                           log_error "Failed to unzip $project_name: $(<"$ERROR_OUTPUT")"
                           continue
                        fi

                        ;;

                    *.tar.gz)

                        log_info "Unzipping $project_name using 'tar xvf'"


                        counter=0

                        # Extract the files and show extraction progress with percentage
                       if tar xvf "$project_name" --no-same-owner 2>"$ERROR_OUTPUT"  | while read -r line; do
                           ((counter++))

                           # Display a simple progress indicator (dots or count)
                           if (( counter )); then
                              printf "\rExtracted files: %d" "$counter"
                           fi
                       done; then

                           printf "\n"  # Move to the next line after completion
#                           log_info "Successfully unzipped $project_name to $folder_name and files count is $counter "
                           log_info "Successfully unzipped $project_name to $folder_name"
                       else
                           # Log error if extraction fails
                           log_error "Failed to unzip $project_name: $(<"$ERROR_OUTPUT")"
                           continue
                        fi

                        ;;
                    *)
                        log_error "Unsupported file format: $project_name"
                        continue
                        ;;
                esac


                if [ -d "$folder_name" ]; then
                    log_info "$folder_name exists after extraction."
                    # Check if the ProjRep folder and dbid.xml file exists in a directory
                    sudo chown alm_service.'domain users' $folder_name
                    if [ -d "$folder_name/ProjRep" ] && [ -f "$folder_name/dbid.xml" ]; then
                        log_info "The ProjRep folder and dbid.xml file is present inside the $folder_name folder."
                    else
                        log_error "The ProjRep folder and dbid.xml file is missing inside the $folder_name folder and stopping the process for this project. "
                        continue
                    fi

                # Check if ProjRep and dbid.xml are present but not under the expected folder.
                elif [[ -d "ProjRep" && -f "dbid.xml" ]]; then
                   log_warning "ProjRep and dbid.xml files were uploaded but not under the $folder_name folder."

                   # List files for verification
                   log_info "$(ls -la)"

                   # Create the folder and move files into it
                   log_info "Creating folder $folder_name and moving ProjectRep and dbid.xml into it."

                   if sudo mkdir "$folder_name"; then
                       log_info "Directory $folder_name created successfully."
                       log_info "giving the permission to the newly created folder $folder_name"
                       sudo chown -R alm_service.'domain users' "$folder_name"
                       sudo chmod -R 775 "$folder_name"
                       log_info "Done to giving the Permission to the newly created folder $folder_name"

                   else
                       log_error "Failed to create directory $folder_name."
                       continue
                   fi

                   if sudo mv "ProjRep" "$folder_name/"; then
                       log_info "Moved ProjRep to $folder_name."
                   else
                       log_error "Failed to move ProjRep to $folder_name."
                       continue
                   fi

                   if sudo mv "dbid.xml" "$folder_name/"; then
                       log_info "Moved dbid.xml to $folder_name."
                   else
                       log_error "Failed to move dbid.xml to $folder_name."
                       continue
                   fi

                   # Check the contents of the new directory
                   log_info "Checking the files inside $folder_name after moving."
                   if cd "$folder_name"; then
                       log_info "$(ls -la)"
                       cd ..  # Go back to the previous director
                   else
                       log_error "Failed to change directory to $folder_name."
                       continue
                   fi

                else
                    log_error "$folder_name does not exist after extraction."
                    continue
                fi


                log_info "giving permision to the $folder_name folder."

                # Desired owner and group
                DESIRED_OWNER="alm_service"
                DESIRED_GROUP="domain users"

                # Get the current owner and group
                CURRENT_OWNER=$(ls -ld "$folder_name" | awk '{print $3}')
                CURRENT_GROUP=$(ls -ld "$folder_name" | awk '{print $4}')

                # Compare with desired owner and group
                if [[ "$CURRENT_OWNER" == "$DESIRED_OWNER" && "$CURRENT_GROUP" == "$DESIRED_GROUP" ]]; then
                    log_info "Owner and group are already correct: $CURRENT_OWNER.'$CURRENT_GROUP'. No changes needed."
                else
                    log_info "Changing owner and group to $DESIRED_OWNER.'$DESIRED_GROUP'..."
                    sudo chown -R "$DESIRED_OWNER:$DESIRED_GROUP" "$folder_name"
                    if [[ $? -eq 0 ]]; then
                        log_info "Ownership successfully updated."
                    else
                        log_error "Failed to update ownership. Please check permissions."
                    fi
                fi
               # sudo chown -R alm_service.'domain users' "$folder_name"
                log_info "changing 775 permission to the $folder_name unzip file."
                sudo chmod -R 775 "$folder_name"
                log_info "Sucessfully the Changed the owner and Permissions"
                # to check the owner and permission to the unzip file
#                if [[ $(stat -c "%U:%G" "$folder_name") == "alm_service:domain users" && $(stat -c "%a" "$folder_name") == "775" ]]; then
#                    log_info "Validation successful: $folder_name has correct ownership and permissions."
#                else
#                    log_error "Validation failed: $folder_name does not have correct ownership or permissions."
#                fi
                log_info "Size of the unzipped file $folder_name: $(du -sh "$folder_name")"

                # Define the target directory where all dbid.xml files will be stored
                if [ ! -d "$DBID_XML_FILES" ]; then
                  log_info "DBID_XML_FILES: $DBID_XML_FILES"

                  mkdir -p "$DBID_XML_FILES"  # Create directory and its parent if needed
                  if [ $? -eq 0 ]; then
                    log_info "Successfully created directory: $DBID_XML_FILES"
                  else
                    log_warning "Failed to create directory: $DBID_XML_FILES"
                    exit 1  # Exit if directory creation fails
                  fi
                else
                  log_info "Directory already exists: $DBID_XML_FILES"
                fi

                target_dir="$DBID_XML_FILES/$folder_name"

                # Create the target directory if it doesn't exist
                if [ ! -d "$target_dir" ]; then
                  mkdir -p "$target_dir"  # Create directory and its parent if needed
                  if [ $? -eq 0 ]; then
                    log_info "Successfully created directory: $target_dir"
                  else
                    log_warning "Failed to create directory: $target_dir"
                    exit 1  # Exit if directory creation fails
                  fi
                else
                  log_info "Directory already exists: $target_dir"
                fi

                # Copy the dbid.xml file to the new folder
                source_file="$folder_name/dbid.xml"
                if [ ! -f "$source_file" ]; then
                  log_warning "Source file does not exist: $source_file"
                  exit 1  # Exit if source file doesn't exist
                fi

                # Attempt to copy the file
                if cp "$source_file" "$target_dir"; then
                  log_info "Successfully copied the dbid.xml file to $target_dir"
                else
                  log_warning "Failed to copy the dbid.xml file to $target_dir"
                  exit 1  # Exit if copying fails
                fi



                echo "$(date +"%Y-%m-%d_%H-%M-%S") Location of $folder_name under $Domain_Name is $(pwd)/$folder_name/" >> "$Repo_location_file"
                log_info "$(date +"%Y-%m-%d_%H-%M-%S") Location of $folder_name under $Domain_Name is $(pwd)/$folder_name/"
                log_info "$(ls -la)"
                #
                rm -f "$ERROR_OUTPUT"
            else
                log_warning "Skipped extraction of the repo file."
            fi

            if [[ "$Zip_Delete" == "YES" ]]; then
                log_info "Attempting to remove the zip file of Project: $project_name"
              #  folder_name="${project_name%.*}"
                if [[ "$project_name" == *.tar.gz ]]; then
                  folder_name="${project_name%.tar.gz}"
                else
                  folder_name="${project_name%.*}"
                fi
                log_info "$folder_name unzip file name"
                log_info "$project_name zip file name"
                if [[ -d "$folder_name" ]]; then
                   if sudo rm -rf "$project_name"; then
                     log_info "Successfully removed the zip file of Project: $project_name."
                     log_info "$(ls -la)"
                   else
                     log_error "Failed to remove the zip file of Project or file is not present: $project_name."
                   fi
                else
                  log_warning "$folder_name is not a folder or does not exist, skipping deletion."
                fi
            elif [[ "$Zip_Delete" == "NO" ]]; then
                log_warning "Zip file deletion skipped as per the configuration: $project_name."
            else
               log_error "Unexpected value for Zip_Delete: $Zip_Delete. Skipping deletion."
            fi
            ;;
   esac
done < "$CSV_FILE"

log_info "Script execution completed. Logs can be found in $LOG_FILE."
