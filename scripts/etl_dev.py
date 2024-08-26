import json
import requests

# Load the dev configuration
with open('./jobs/dev_job.json') as config_file:
    config = json.load(config_file)

def etl_process():
    # Simulate ETL logic
    print(f"Running ETL process in dev with config: {config}")

if __name__ == "__main__":
    etl_process()