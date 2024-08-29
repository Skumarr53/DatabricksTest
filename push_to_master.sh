#!/bin/bash

# Script to automatically commit changes and push to main branch

# Navigate to the Git repository directory (optional, if you want to ensure you're in the right directory)
# cd /path/to/your/repo

# Check the current branch
current_branch=$(git branch --show-current)

if [ "$current_branch" != "main" ]; then
    echo "You are not on the main branch. Switching to main branch."
    git checkout main
fi

# Pull the latest changes from the remote main branch
echo "Pulling the latest changes from main branch..."
git pull origin main

# Add all changes to the staging area
echo "Adding all changes..."
git add .

# Commit changes with a default message
commit_message="Automated commit: $(date)"
echo "Committing changes with message: $commit_message"
git commit -m "$commit_message"

# Push changes to the main branch
echo "Pushing changes to main branch..."
git push origin main

echo "Changes successfully pushed to main branch."

