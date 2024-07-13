#!/bin/bash

# Function to generate a password for the user 
password_gen(){
    openssl rand -base64 8
}

# Function to check if the user exists
check_user(){
    if id "$1" > /dev/null 2>&1; then
        echo "$1 already exists"
        # The user exists     
        return 0
    else
        echo "$1 does not exist"
        # The user does not exist     
        return 1
    fi
}

# Function to check if the group exists 
check_group(){
    if getent group "$1" &> /dev/null; then 
        return 0
    else
        return 1
    fi
}

timestamp(){
    date +"%Y-%m-%d %H:%M"
}

# This checks if only 1 argument is passed 
if [[ $# -ne 1 ]]; then
    echo "Error: invalid number of arguments"
    exit 1
fi

userfileip=$1

# Check if the user file exists 
if [[ ! -f $userfileip ]]; then
    echo "Error: $userfileip file not found"
    exit 1
fi

# Initialize user_management absolute path to file to LOG_FILE 
LOG_FILE="/var/log/user_management.log"

# Create the user_management.log and set user and group access to root 
if [[ ! -f "$LOG_FILE" ]]; then
    sudo touch "$LOG_FILE"
    sudo chown root:root "$LOG_FILE"
fi

exec > >(sudo tee -a "$LOG_FILE") 2>&1

# Initialize user_passwords.csv absolute path to file to PASSWORD_FILE 
PASSWORD_FILE="/var/secure/user_passwords.csv"

# Create the password.csv and set user and group access to root 
if [[ ! -f "$PASSWORD_FILE" ]]; then
    sudo touch "$PASSWORD_FILE"
    sudo chown root:root "$PASSWORD_FILE"
fi

while IFS=";" read -r username groups; do
    # Get the username from file 
    username=$(echo "$username" | xargs)
    groups=$(echo "$groups" | xargs)

    # Check if the user already exists 
    if check_user "$username"; then 
        # If the user exists 
        echo "$username already exists"
    else
        sudo useradd "$username"
        # Set the generated password 
        password=$(password_gen)

        # Set permission for the user's home directory 
        sudo chmod 700 "/home/$username"
        sudo chown "$username:$username" "/home/$username"

        echo "$username:$password" | sudo chpasswd  
        
        echo "$username was created at $(timestamp). Check user_passwords.csv for more info"
        echo "$username,$password" >> "$PASSWORD_FILE"
    fi

    # Split the string into an array
    IFS=',' read -ra group_array <<< "$groups"

    for group in "${group_array[@]}"; do 
        # Check if the group exists
        if check_group "$group"; then
            # If the group exists 
            echo "$group already exists"
        else
            sudo groupadd "$group"
            echo "$group was created at $(timestamp). For more info, check user_management.log"
        fi   

        if id -nG "$username" | grep -qw "$group"; then 
            # If the user is in the group 
            echo "User is already in the group"
        else
            # Add the user to the group 
            sudo usermod -aG "$group" "$username" 
            echo "'$username' is added to the '$group'."
        fi
    done
done < "$userfileip"
