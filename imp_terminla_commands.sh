databricks jobs create --json @jobs/dev_job.json --profile dev
databricks jobs run-now  --profile stg


databricks fs mkdir dbfs:/FileStore/scripts/
databricks fs cp ./scripts/etl_dev.py dbfs:/FileStore/scripts/etl_dev.py