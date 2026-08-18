{{ config(
    materialized='ephemeral'
) }}

with hosts as (
    select
        host_id,
        host_name,
        host_since,
        is_superhost,
        response_rate_quality,
        host_created_at
    from {{ ref('obt') }}
)
select * from hosts