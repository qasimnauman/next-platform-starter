#!/bin/bash

# Directory where the app will be stored on EC2
REMOTE_APP_DIR="~/app"

# Initial system update and install dependencies
echo "Updating the system and installing dependencies..."
sudo apt-get update -y
sudo apt-get install nodejs -y
sudo apt-get install npm -y
sudo npm install pm2 -g

# Sync code to the EC2 instance
echo "Syncing code to EC2 instance..."
rsync -avz --delete -e "ssh -i ~/.ssh/id_rsa" . $EC2_USERNAME@$EC2_HOST:$REMOTE_APP_DIR

# SSH into the instance to handle the directory and deploy
ssh -i ~/.ssh/id_rsa $EC2_USERNAME@$EC2_HOST << 'EOF'
  REMOTE_APP_DIR="~/app"

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
  npm install  # Absolute path to npm

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