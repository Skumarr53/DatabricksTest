#!/bin/bash

# Script to automatically commit changes and push to master branch

# Navigate to the Git repository directory (optional, if you want to ensure you're in the right directory)
# cd /path/to/your/repo

# Check the current branch
current_branch=$(git branch --show-current)

if [ "$current_branch" != "master" ]; then
    echo "You are not on the master branch. Switching to master branch."
    git checkout master
fi

# Pull the latest changes from the remote master branch
echo "Pulling the latest changes from master branch..."
git pull origin master

# Add all changes to the staging area
echo "Adding all changes..."
git add .

# Commit changes with a default message
commit_message="Automated commit: $(date)"
echo "Committing changes with message: $commit_message"
git commit -m "$commit_message"

# Push changes to the master branch
echo "Pushing changes to master branch..."
git push origin master

echo "Changes successfully pushed to master branch."

