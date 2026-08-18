{{ config (
    materialized='incremental',
    unique_key='host_id'
)
}}

select
    host_id,
    replace(host_name, ' ', '_') as host_name,
    host_since,
    is_superhost,
    response_rate,
    case
        when response_rate > 95 then 'very_good'
        when response_rate > 80 and response_rate <= 95 then 'good'
        when response_rate > 60 and response_rate <= 80 then 'average'
        else 'poor'
    end as response_rate_quality,
    CREATED_AT
from
    {{ ref('bronze_hosts') }}
