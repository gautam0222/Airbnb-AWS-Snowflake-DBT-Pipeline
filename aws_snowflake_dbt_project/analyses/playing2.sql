{% set flag = true %}

select * from {{ref('bronze_listings')}}

{% if flag %}

where nights_booked > {{ nights_booked }}

{% else %}

where nights_booked <= {{ nights_booked }}

{% endif %}
