{% set nights_booked = 5 %}

select * from {{ref('bronze_listings')}}
where nights_booked > {{ nights_booked }}
