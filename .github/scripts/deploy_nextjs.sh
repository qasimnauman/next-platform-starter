#!/bin/bash

# Accessing secrets from GitHub environment variables
EC2_USERNAME="${{ secrets.EC2_USERNAME }}"
EC2_HOST="${{ secrets.EC2_HOST }}"

# Absolute path where the app will be stored on EC2
REMOTE_APP_DIR="/home/ubuntu/app"

# Sync code to the EC2 instance
echo "Syncing code to EC2 instance..."
rsync -avz --delete -e "ssh -i ~/.ssh/id_rsa" . $EC2_USERNAME@$EC2_HOST:$REMOTE_APP_DIR

# SSH into the instance to handle the directory and deploy
ssh -i ~/.ssh/id_rsa $EC2_USERNAME@$EC2_HOST << 'EOF'
  # Initial system update and install dependencies
  echo "Updating the system and installing dependencies..."
  sudo apt-get update -y
  sudo apt-get install -y nodejs npm

  # Check if PM2 is installed, if not, install it
  if ! command -v pm2 &> /dev/null; then
    echo "PM2 is not installed, installing PM2 globally..."
    sudo npm install pm2 -g
  else
    echo "PM2 is already installed."
  fi

  # Ensure the application directory exists or create it if missing
  if [ -d "$REMOTE_APP_DIR" ]; then
    echo "Directory $REMOTE_APP_DIR exists. Clearing old files..."
    rm -rf $REMOTE_APP_DIR/*
  else
    echo "Directory $REMOTE_APP_DIR does not exist. Creating..."
    mkdir -p $REMOTE_APP_DIR
  fi

  # Navigate to application directory
  cd $REMOTE_APP_DIR

  # Install dependencies
  echo "Installing dependencies..."
  npm install  # Now it should correctly find package.json

  # Start or restart the application using PM2
  if pm2 list | grep -q "next-app"; then
    echo "Restarting the application with PM2..."
    pm2 restart next-app
  else
    echo "Starting the application with PM2..."
    pm2 start npm --name "next-app" -- start
  fi

  # Save PM2 process list for automatic startup on system reboot
  pm2 save
EOF

echo "Deployment complete!"
