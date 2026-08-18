{{config(
    materialized='view'
)}}

select * from airbnb.staging.listings