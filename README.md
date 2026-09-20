# Breast Cancer Data Pipeline with Apache Airflow

A reproducible data-processing pipeline built with **Apache Airflow** and **Docker** using the Wisconsin Diagnostic Breast Cancer dataset.

The workflow demonstrates how Airflow can orchestrate a complete preprocessing pipeline from raw data ingestion to validation, deterministic dataset splitting, feature scaling, and run reporting.

## Pipeline Overview

The DAG contains five main tasks:

```text
ingest
   ↓
validate
   ↓
split
   ↓
scale
   ↓
report
```

### Tasks

* **ingest**
  Reads the source CSV file and creates an immutable Parquet snapshot for the current DAG run.

* **validate**
  Checks the dataset for null values, negative measurements, invalid labels, duplicate samples, and extreme outliers.

* **split**
  Creates deterministic training and testing datasets by hashing `sample_id`.

* **scale**
  Calculates scaling statistics using the training dataset only and applies them to both train and test sets.

* **report**
  Generates a summary for the current run and maintains execution history.

---

## Project Structure

```text
airflow-mlops-pipeline/
│
├── dags/
│   └── ml_training_pipeline.py
│
├── data/
│   ├── raw/
│   │   └── wdbc.csv
│   └── staging/
│
├── utilities/
│   └── generate_corrupted_data.py
│
├── config/
│   └── __init__.py
│
├── src/
│   └── __init__.py
│
├── logs/
│
├── Dockerfile.airflow
├── compose.yaml
├── requirements.txt
├── .dockerignore
├── .gitignore
└── README.md
```

---

## Requirements

The project can be executed either locally or with Docker.

Recommended versions:

```text
Python: 3.11
Apache Airflow: 2.8.4
Docker / Docker Compose
```

---

# Running with Docker

Docker is the recommended method because all dependencies are isolated inside the Airflow container.

## 1. Build and start Airflow

```bash
docker compose up -d --build
```

Check container status:

```bash
docker compose ps
```

Wait until the Airflow container reports a healthy status.

The project uses:

```text
Docker image: breast-cancer-airflow:2.8.4
Container:    breast-cancer-mlops-airflow
Airflow UI:   http://127.0.0.1:18080
```

The internal Airflow port remains `8080`, while the host exposes it through port `18080`.

---

## 2. Get the Airflow admin password

```bash
docker compose exec airflow cat /opt/airflow/standalone_admin_password.txt
```

Open:

```text
http://127.0.0.1:18080
```

Username:

```text
admin
```

Use the password returned by the previous command.

---

# Running Locally

Create a Python virtual environment:

```bash
python3.11 -m venv .venv
```

Activate it:

```bash
source .venv/bin/activate
```

Install dependencies:

```bash
pip install -r requirements.txt \
  --constraint https://raw.githubusercontent.com/apache/airflow/constraints-2.8.4/constraints-3.11.txt
```

Configure the local Airflow environment:

```bash
export AIRFLOW_HOME=$PWD/.airflow
export AIRFLOW__CORE__DAGS_FOLDER=$PWD/dags
export AIRFLOW__CORE__LOAD_EXAMPLES=False
```

Start Airflow:

```bash
airflow standalone
```

The local Airflow UI will be available at:

```text
http://127.0.0.1:8080
```

---

# Airflow DAG

The project registers the following DAG:

```text
breast_cancer_etl
```

Verify that Airflow successfully loaded it:

```bash
docker compose exec airflow airflow dags list | grep breast_cancer
```

Expected output:

```text
breast_cancer_etl | ml_training_pipeline.py | airflow
```

Check for DAG import errors:

```bash
docker compose exec airflow airflow dags list-import-errors
```

A healthy configuration should return:

```text
No data found
```

---

# Testing the Pipeline

Execute the complete DAG for a logical execution date:

```bash
docker compose exec airflow airflow dags test breast_cancer_etl 2026-08-25
```

The tasks execute sequentially:

```text
ingest
validate
split
scale
report
```

A successful run finishes with:

```text
state=success
```

---

# Pipeline Output

Each logical execution date receives its own working directory.

Example:

```text
data/staging/2026-08-25/
```

Generated artifacts include:

```text
raw.parquet
clean.parquet
rejected.parquet
validation_report.json

train_unscaled.parquet
test_unscaled.parquet

train.parquet
test.parquet

scaler.json
summary.json
```

The project also maintains:

```text
data/staging/history.jsonl
```

Each logical date has one summary entry.

Re-running the same logical date replaces its previous entry instead of creating duplicate history records.

---

# Data Validation

Before processing continues, the `validate` task checks for several data-quality problems.

Current validation checks include:

* Missing numerical values
* Negative feature values
* Invalid diagnosis labels
* Duplicate sample IDs
* Extreme `mean_area` outliers

Accepted labels are:

```text
M
B
```

The maximum rejected-row threshold is:

```text
5%
```

If more than 5% of the dataset is invalid, the pipeline fails immediately.

---

# Deterministic Train/Test Split

Instead of randomly shuffling the dataset, the pipeline hashes each `sample_id`.

The resulting hash determines whether a record belongs to the training or testing partition.

Current ratio:

```text
Training: approximately 80%
Testing:  approximately 20%
```

This approach provides reproducible partitioning even when source rows arrive in a different order.

---

# Feature Scaling

Scaling statistics are calculated exclusively from the training partition.

For each numerical feature:

```text
scaled_value = (value - training_mean) / training_standard_deviation
```

The generated statistics are stored in:

```text
scaler.json
```

The test dataset never contributes to the calculation of the scaler.

---

# Testing Data Quality Failure

The project includes a small utility that intentionally corrupts part of the source dataset.

Run:

```bash
python utilities/generate_corrupted_data.py
```

By default, the script modifies approximately 12% of the records.

Because this exceeds the pipeline's 5% rejection limit, the `validate` task should fail.

After testing, restore the original source dataset:

```bash
python utilities/generate_corrupted_data.py --repair
```

A custom corruption fraction can also be supplied:

```bash
python utilities/generate_corrupted_data.py --fraction 0.10
```

---

# Useful Docker Commands

Start the environment:

```bash
docker compose up -d
```

Rebuild after Docker dependency changes:

```bash
docker compose up -d --build
```

Check services:

```bash
docker compose ps
```

View Airflow logs:

```bash
docker compose logs -f airflow
```

Open a shell inside the Airflow container:

```bash
docker compose exec airflow bash
```

List DAGs:

```bash
docker compose exec airflow airflow dags list
```

Stop containers:

```bash
docker compose down
```

Stop containers and remove associated volumes:

```bash
docker compose down -v
```

---

# Verification Commands

Validate Python syntax:

```bash
python3 -m py_compile dags/ml_training_pipeline.py
python3 -m py_compile utilities/generate_corrupted_data.py
```

Validate Docker Compose configuration:

```bash
docker compose config
```

Check DAG import errors:

```bash
docker compose exec airflow airflow dags list-import-errors
```

Run the DAG:

```bash
docker compose exec airflow airflow dags test breast_cancer_etl 2026-08-25
```

---

## Technology Stack

* Apache Airflow 2.8.4
* Python 3.11
* Docker
* Docker Compose
* Pandas
* NumPy
* PyArrow

---

## Current Pipeline

```text
wdbc.csv
   │
   ▼
INGEST
   │
   ├── raw.parquet
   ▼
VALIDATE
   │
   ├── rejected.parquet
   ├── clean.parquet
   └── validation_report.json
   │
   ▼
SPLIT
   │
   ├── train_unscaled.parquet
   └── test_unscaled.parquet
   │
   ▼
SCALE
   │
   ├── train.parquet
   ├── test.parquet
   └── scaler.json
   │
   ▼
REPORT
   │
   ├── summary.json
   └── history.jsonl
```
