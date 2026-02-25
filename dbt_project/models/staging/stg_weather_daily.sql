with deduplicated as (

    select
        city,
        latitude,
        longitude,
        date,
        temperature_max,
        temperature_min,
        precipitation,
        wind_speed_max,
        loaded_at,
        row_number() over (
            partition by city, date
            order by loaded_at desc
        ) as row_num
    from {{ source('raw', 'weather_daily') }}

)

select
    city,
    latitude,
    longitude,
    date,
    round(temperature_max, 1) as temperature_max,
    round(temperature_min, 1) as temperature_min,
    round(precipitation, 1) as precipitation,
    round(wind_speed_max, 1) as wind_speed_max,
    loaded_at
from deduplicated
where row_num = 1
