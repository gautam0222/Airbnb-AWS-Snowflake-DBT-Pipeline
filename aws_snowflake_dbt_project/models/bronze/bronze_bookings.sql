{{ config(
    materialized='incremental',
    unique_key='booking_id'
) }}

select * from {{ source('staging', 'bookings') }}

{% if is_incremental() %}

where created_at > (select coalesce(max(created_at), '1970-01-01') from {{ this }})

{% endif %}