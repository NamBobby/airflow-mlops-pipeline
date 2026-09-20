# Tutorial 03's image: stock Airflow plus the two libraries the DAG imports.
#
FROM apache/airflow:2.8.4-python3.11

USER airflow

ARG AIRFLOW_VERSION=2.8.4
# NOTE: do not call this ARG PYTHON_VERSION -- the base image already sets
# ENV PYTHON_VERSION=3.11.8, and a base-image ENV overrides a same-named ARG
# inside RUN, which would make this fetch constraints-3.11.8.txt (404).
ARG CONSTRAINTS_PYTHON=3.11
RUN pip install --no-cache-dir \
      --constraint "https://raw.githubusercontent.com/apache/airflow/constraints-${AIRFLOW_VERSION}/constraints-${CONSTRAINTS_PYTHON}.txt" \
      "pandas==2.1.4" \
      "pyarrow==14.0.2"
