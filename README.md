# Airbnb Analytics Pipeline: AWS S3, Snowflake & dbt

An analytics engineering project that models Airbnb-style operational data from Snowflake staging tables into curated, analytics-ready layers with dbt. The intended ingestion path is **AWS S3 → Snowflake staging → dbt → Snowflake bronze/silver/gold**.

The repository contains the dbt transformation project. It does not include S3 bucket infrastructure, Snowflake loading scripts, or orchestration configuration; therefore, those parts of the architecture are documented as integration boundaries rather than implemented resources.

## Contents

- [Airbnb Analytics Pipeline: AWS S3, Snowflake \& dbt](#airbnb-analytics-pipeline-aws-s3-snowflake--dbt)
  - [Contents](#contents)
  - [What this project demonstrates](#what-this-project-demonstrates)
  - [Architecture](#architecture)
    - [Layer definitions](#layer-definitions)
  - [Data layers and lineage](#data-layers-and-lineage)
  - [Project structure](#project-structure)
  - [Prerequisites](#prerequisites)
  - [Configuration](#configuration)
  - [Run the project](#run-the-project)
  - [Data model](#data-model)
    - [Bronze models](#bronze-models)
    - [Silver transformations](#silver-transformations)
    - [Gold outputs](#gold-outputs)
  - [dbt concepts used](#dbt-concepts-used)

## What this project demonstrates

- A **medallion architecture**: raw/staging inputs are transformed through bronze, silver, and gold layers.
- **Incremental dbt models** for efficient processing of booking, host, and listing records.
- Snowflake as the cloud data warehouse and serving layer.
- dbt features including sources, references, Jinja templating, reusable macros, incremental materializations, and snapshot definitions.
- A joined **one big table (OBT)** for analysis across bookings, listings, and hosts, plus a narrower fact-style output.

## Architecture

```text
Airbnb source files
       │
       ▼
AWS S3 bucket
       │  (loaded into Snowflake outside this repository)
       ▼
Snowflake AIRBNB.STAGING
  ├── bookings
  ├── listings
  └── hosts
       │
       ▼
dbt project: aws_snowflake_dbt_project
  ├── BRONZE  — incremental copies of staging data
  ├── SILVER  — cleaned and enriched entities
  └── GOLD    — integrated analytical outputs
       │
       ▼
Snowflake AIRBNB.GOLD
  ├── OBT
  └── FACT
```

### Layer definitions

| Layer | Purpose | Models in this project |
| --- | --- | --- |
| **Staging** | Snowflake landing schema for data loaded from S3. It is declared as a dbt source and is not built by dbt. | `staging.bookings`, `staging.listings`, `staging.hosts` |
| **Bronze** | Incremental, lightly transformed copies of source data; preserves source grain. | `bronze_bookings`, `bronze_listings`, `bronze_hosts` |
| **Silver** | Cleaned, standardized, and business-enriched entity tables. | `silver_bookings`, `silver_listings`, `silver_hosts` |
| **Gold** | Integrated datasets for reporting and analysis. | `obt`, `fact` |

## Data layers and lineage

```text
staging.bookings ──► bronze_bookings ──► silver_bookings ──┐
staging.listings ──► bronze_listings ──► silver_listings ──┼──► obt ──► fact
staging.hosts ─────► bronze_hosts ─────► silver_hosts ─────┘
```

The primary relationships are:

- `bookings.listing_id` → `listings.listing_id`
- `listings.host_id` → `hosts.host_id`

The gold OBT starts from bookings and left-joins listings, then hosts. It keeps booking records even when a related listing or host record is unavailable.

## Project structure

```text
.
├── README.md
├── pyproject.toml                         # Python/dbt dependencies
└── aws_snowflake_dbt_project/
    ├── dbt_project.yml                    # Paths and layer-level materializations
    ├── profiles.yml                       # Environment-variable Snowflake profile
    ├── models/
    │   ├── sources/sources.yml            # AIRBNB.STAGING source declarations
    │   ├── bronze/                        # Incremental ingestion models
    │   ├── silver/                        # Cleansing and enrichment models
    │   └── gold/                          # OBT, fact, and ephemeral projections
    ├── macros/                            # Reusable Jinja/SQL functions
    ├── snapshots/                         # Slowly changing dimension definitions
    ├── tests/                             # Singular data tests
    └── analyses/                          # Exploratory Jinja/SQL examples
```

## Prerequisites

- Python 3.12 or later
- A Snowflake account, warehouse, database, and credentials with permissions to read `AIRBNB.STAGING` and create objects in the target schemas
- Data already loaded from S3 into `AIRBNB.STAGING.BOOKINGS`, `AIRBNB.STAGING.LISTINGS`, and `AIRBNB.STAGING.HOSTS`
- `uv` (recommended) or `pip`

## Configuration

`aws_snowflake_dbt_project/profiles.yml` uses environment variables so credentials are never committed.

In PowerShell, configure a session before running dbt:

```powershell
$env:SNOWFLAKE_ACCOUNT = "<organization-account>"
$env:SNOWFLAKE_USER = "<user>"
$env:SNOWFLAKE_PASSWORD = "<password>"
$env:SNOWFLAKE_DATABASE = "AIRBNB"
$env:SNOWFLAKE_WAREHOUSE = "COMPUTE_WH"
$env:SNOWFLAKE_ROLE = "TRANSFORMER_ROLE"
$env:SNOWFLAKE_SCHEMA = "dbt_schema"
```

The database, warehouse, role, schema, and thread count have safe defaults in the profile, but they can all be overridden with environment variables. Use a least-privilege transformation role in place of `ACCOUNTADMIN`.

Install dependencies from the repository root:

```powershell
uv sync
```

Or, with pip:

```powershell
python -m pip install "dbt-core>=1.12.2" "dbt-snowflake>=1.12.0"
```

## Run the project

Run all commands from `aws_snowflake_dbt_project` so dbt discovers the local `profiles.yml` file.

```powershell
cd aws_snowflake_dbt_project
dbt debug
dbt source freshness
dbt run
dbt test
```

For the first build of an incremental model, or when source history needs to be reprocessed:

```powershell
dbt run --full-refresh
```

Useful selective runs:

```powershell
dbt run --select bronze_bookings+
dbt run --select obt+
dbt docs generate
dbt docs serve
```

## Data model

### Bronze models

Each bronze model reads directly from a declared staging source and is configured as incremental with a business key:

| Model | Unique key | Incremental watermark |
| --- | --- | --- |
| `bronze_bookings` | `booking_id` | `created_at` |
| `bronze_listings` | `listing_id` | `created_at` |
| `bronze_hosts` | `host_id` | `created_at` |

On incremental runs, rows with a `created_at` value later than the maximum target `created_at` are selected. This is efficient for append-only source extracts. Late-arriving rows or changes to older records require a full refresh or a more robust merge/watermark strategy.

### Silver transformations

| Model | Transformations |
| --- | --- |
| `silver_bookings` | Selects booking attributes and calculates `total_amount` as `nights_booked × booking_amount`, rounded to two decimal places. |
| `silver_listings` | Selects listing attributes and classifies `price_per_night` as `LOW` (&lt;100), `MEDIUM` (100–&lt;200), or `HIGH` (≥200). |
| `silver_hosts` | Replaces spaces in host names with underscores and classifies response rate as `very_good`, `good`, `average`, or `poor`. |

### Gold outputs

- **`obt`**: Incremental, denormalized booking-centric dataset combining booking, listing, and host attributes. It is the project’s principal analytics table.
- **`fact`**: A curated projection from `AIRBNB.GOLD.OBT` that retains identifiers, revenue/cost measures, listing capacity attributes, price, and host response rate.
- **Ephemeral models** (`gold/ephemeral`): Inline projections for booking, listing, and host attributes. dbt compiles ephemeral models into dependent queries instead of creating Snowflake relations.

## dbt concepts used

| Concept | How it is used here |
| --- | --- |
| `source()` | Declares and queries the three `AIRBNB.STAGING` tables. |
| `ref()` | Defines dbt lineage between bronze and silver models. |
| Incremental models | Uses unique keys and a `created_at` filter to limit subsequent processing. |
| Macros | `multiply` calculates rounded totals; `tag` assigns listing price bands; `generate_schema_name` uses the configured layer schema exactly. |
| Jinja | Dynamically builds SQL column lists and joins in the gold models; analyses demonstrate Jinja control structures. |
| Snapshots | YAML definitions intend to retain historical versions of bookings, hosts, and listings using timestamp strategies. |

