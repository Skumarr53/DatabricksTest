#!/bin/bash
set -e  # Exit immediately if a command exits with a non-zero status

if [ $# -lt 2 ]; then
    echo "Please specify the environment (dev/staging/production) and the artifact_id as arguments."
    echo "Usage: ./deploy_jobs.sh staging build_version"
    exit 1
fi

ENV=$1
ARTIFACT_ID=$2

# Define various paths based on the environment and artifact ID
ARTIFACTS_PATH="dbfs:/artifacts/$ARTIFACT_ID/"
DOWNLOAD_PATH="/tmp/artifacts/tmp"
TEMP_PATH="/tmp/artifacts/$ARTIFACT_ID"
DBFS_PATH="dbfs:/env-artifacts/$ENV/$ARTIFACT_ID"
SCRIPT_DESTINATION="$DBFS_PATH/scripts/etl_dev.py"

# Check if the temporary path already exists
if [[ -d "$TEMP_PATH" ]]; then
    echo "$TEMP_PATH exists. Using existing artifacts."
else
    echo "$TEMP_PATH does not exist"
    echo "Getting artifacts from $ARTIFACTS_PATH"
    rm -rf $DOWNLOAD_PATH  # Clean the download path
    dbfs cp --overwrite --recursive $ARTIFACTS_PATH $DOWNLOAD_PATH  # Copy artifacts from DBFS
    mv $DOWNLOAD_PATH $TEMP_PATH  # Move to the target temp path
fi

echo "Copying etl_dev.py to $SCRIPT_DESTINATION"
dbfs cp --overwrite "scripts/etl_dev.py" "$SCRIPT_DESTINATION"  # Deploy the Python script

declare -r JOB_CONFIG_PATH=$TEMP_PATH/environments/"${ENV}".json  # Load environment-specific job configuration
declare JOB_SETTINGS=$(cat "$JOB_CONFIG_PATH")

ACTIVE_JOBS=($(echo $JOB_SETTINGS | jq -r ".active_jobs[]" | xargs echo -n))  # Get active jobs list

# Loop through each active job to configure them
for JOB_NAME in "${ACTIVE_JOBS[@]}"; do
  echo "Retrieving existing $JOB_NAME job"
  
  declare JOB_ID=$(databricks jobs list --output json | jq ".jobs[] | select(.settings.name == \"${ENV} - ${JOB_NAME}\") | .job_id")  # Get job ID

  declare JOB_CONFIG_TEMPLATE=$(jq -s '.[0] * .[1] * .[2].config' $TEMP_PATH/job_configuration/_base_.json $TEMP_PATH/job_configuration/"$JOB_NAME".json $TEMP_PATH/environments/"$ENV".json)  # Merge job configurations

  declare JOB_CONFIG=$(echo "$JOB_CONFIG_TEMPLATE" | \
   sed -e "s::$ENV:g" | \
   sed -e "s::$JOB_NAME:g" | \
   sed -e "s//$(echo "$SCRIPT_DESTINATION" | sed -e 's/[\/&]/\\&/g')/g" | \
   jq .settings)  # Update placeholders with actual paths and names

  if [ -z "$JOB_ID" ]; then
      echo "Job not found. Creating it"
      echo "$JOB_CONFIG"
      databricks jobs create --json "$JOB_CONFIG"  # Create a new job if not found
  else
      echo "Updating job $JOB_ID"
      databricks jobs reset --job-id "$JOB_ID" --json "$JOB_CONFIG"  # Update existing job configuration

      RUNNING_JOB_ID=$(databricks runs list --active-only --limit 1000 --output json | jq -r ".runs[]? | select(.job_id == $JOB_ID and .state.life_cycle_state == \"RUNNING\")? | .run_id?")  # Check if job is running

      if [ -n "$RUNNING_JOB_ID" ]; then
            echo "The job $RUNNING_JOB_ID (${ENV} - ${JOB_NAME}) is running. Stopping and restarting it"
            databricks runs cancel --run-id "$RUNNING_JOB_ID"  # Cancel running job
            while [ $(databricks runs list --active-only --limit 1000 --output json | jq -r ".runs[] | select(.job_id == $JOB_ID and .run_id == $RUNNING_JOB_ID) | .state.life_cycle_state ") != "TERMINATED" ];do
              sleep 0.1  # Wait for job to terminate
            done
            echo "${JOB_NAME} has been terminated."
            databricks jobs run-now --job-id "$JOB_ID"  # Restart job
        fi
  fi
done
