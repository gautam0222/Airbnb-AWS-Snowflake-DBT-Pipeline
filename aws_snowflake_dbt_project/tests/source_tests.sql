{{config(
    severity='warn'
)}}

select 1 from {{source('airbnb', 'bookings')}} where booking_amount < 200