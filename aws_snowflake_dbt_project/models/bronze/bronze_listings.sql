{{ config(
    materialized='incremental',
    unique_key='listing_id'
) }}

select * from {{ source('staging', 'listings') }}

{% if is_incremental() %}

where created_at > (select coalesce(max(created_at), '1970-01-01') from {{ this }})

{% endif %}