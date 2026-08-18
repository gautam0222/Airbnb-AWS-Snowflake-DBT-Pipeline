{%set columns = ['nights_booked', 'booking_id', 'booking_amount']%}

select 
{%for col in columns%}
    {{col}}{%if not loop.last%},{%endif%}
{%endfor%}
from {{ref('bronze_bookings')}}