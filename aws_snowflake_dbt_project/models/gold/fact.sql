{% set congigs = [
    {
        "table" : "AIRBNB.GOLD.OBT",
        "columns" : "GOLD_obt.BOOKING_ID, GOLD_obt.LISTING_ID, GOLD_obt.HOST_ID,GOLD_obt.TOTAL_AMOUNT, GOLD_obt.SERVICE_FEE, GOLD_obt.CLEANING_FEE, GOLD_obt.ACCOMMODATES, GOLD_obt.BEDROOMS, GOLD_obt.BATHROOMS, GOLD_obt.PRICE_PER_NIGHT, GOLD_obt.RESPONSE_RATE",
        "alias" : "GOLD_obt"
    }
] %}



SELECT 
        {{ congigs[0]['columns'] }}

FROM
    {% for config in congigs %}
        {{ config['table'] }} AS {{ config['alias'] }}
    {% endfor %}