select
    w.city,
    w.date,
    w.temperature_max,
    w.temperature_min,
    w.precipitation,
    w.wind_speed_max,
    c.region,
    case
        when w.temperature_max > 30 or w.precipitation > 50
            then true
        else false
    end as is_extreme_weather
from {{ ref('stg_weather_daily') }} w
inner join {{ ref('dim_cities') }} c
    on w.city = c.city
