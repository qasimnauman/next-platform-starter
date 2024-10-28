#!/bin/bash

# Directory where the app will be stored on EC2
REMOTE_APP_DIR="~/app"

# Step 1: Ensure Node.js is installed
echo "Checking for Node.js..."
if ! command -v node &> /dev/null; then
  echo "Node.js not found. Installing..."
  curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
  sudo apt-get install -y nodejs
else
  echo "Node.js found: $(node --version)"
fi

# Step 2: Ensure PM2 is installed
echo "Checking for PM2..."
if ! command -v pm2 &> /dev/null; then
  echo "PM2 not found. Installing..."
  sudo npm install -g pm2
else
  echo "PM2 found: $(pm2 --version)"
fi

# Step 3: Sync code from GitHub Actions runner to EC2
echo "Syncing code to EC2 instance..."
rsync -avz --delete -e "ssh -i ~/.ssh/id_rsa" . $EC2_USERNAME@$EC2_HOST:$REMOTE_APP_DIR

# Step 4: SSH into the instance to install dependencies and start the app
ssh -i ~/.ssh/id_rsa $EC2_USERNAME@$EC2_HOST << EOF
  cd $REMOTE_APP_DIR

  # Step 5: Install dependencies
  echo "Installing dependencies..."
  npm install

  # Step 6: Start or restart the application using PM2
  if pm2 list | grep -q "next-app"; then
    echo "Restarting the application with PM2..."
    pm2 restart next-app
  else
    echo "Starting the application with PM2..."
    pm2 start npm --name "next-app" -- start
  fi

  # Save the PM2 process list for restarts on system reboot
  pm2 save
EOF

echo "Deployment complete!"
