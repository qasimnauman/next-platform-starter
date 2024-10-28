#!/bin/bash

# Directory where the app will be stored on EC2
REMOTE_APP_DIR="~/app"

# Initial system update
echo "Updating the system before Node.js installation..."
sudo apt-get update -y && sudo apt-get upgrade -y

# Check for Node.js installation, install if not present
echo "Checking for Node.js..."
if ! command -v node &> /dev/null; then
  echo "Node.js not found. Installing..."
  curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
  sudo apt-get install -y nodejs
  # Add npm global bin to PATH in current session
  export PATH=$PATH:$(npm bin -g)
else
  echo "Node.js found: $(node --version)"
fi

# System update after installing Node.js
echo "Updating the system after Node.js installation..."
sudo apt-get update -y && sudo apt-get upgrade -y

# Check for PM2 installation, install if not present
echo "Checking for PM2..."
if ! command -v pm2 &> /dev/null; then
  echo "PM2 not found. Installing..."
  sudo npm install -g pm2
  export PATH=$PATH:$(npm bin -g) # Ensure PM2 is available in PATH
else
  echo "PM2 found: $(pm2 --version)"
fi

# Sync code to the EC2 instance
echo "Syncing code to EC2 instance..."
rsync -avz --delete -e "ssh -i ~/.ssh/id_rsa" . $EC2_USERNAME@$EC2_HOST:$REMOTE_APP_DIR

# SSH into the instance to handle the directory and deploy
ssh -i ~/.ssh/id_rsa $EC2_USERNAME@$EC2_HOST << EOF
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

  # Re-export PATH for npm and pm2 to make sure they are accessible
  export PATH=$PATH:$(npm bin -g)

  # Install dependencies
  echo "Installing dependencies..."
  npm install

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
