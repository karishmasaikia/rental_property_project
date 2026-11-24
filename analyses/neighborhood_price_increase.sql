/*
Problem #2 - Neighborhood Pricing
Find the average price increase for each neighborhood from July 12th 2021 to July 11th 2022.
Example from the brief: Back Bay has only one listing, so the difference of $44 is the average
for the whole neighborhood, based solely on listing 10813.
*/

with jul_2021 as (
    select
    listing_id
    , daily_price_usd as price_2021
    from {{ ref('fct_listing_daily') }}
    where calendar_date = '2021-07-12'
)
, jul_2022 as (
    select
    listing_id
    , daily_price_usd as price_2022
    from {{ ref('fct_listing_daily') }}
    where calendar_date = '2022-07-11'
)

select
dim_listings.neighborhood
, count(jul_2021.listing_id) as listing_count
, round(avg(price_2022 - price_2021), 2) as avg_price_increase_usd
from jul_2021
inner join jul_2022
on jul_2021.listing_id = jul_2022.listing_id
inner join {{ ref('dim_listings') }} as dim_listings
on jul_2021.listing_id = dim_listings.listing_id
group by 1
order by 3 desc

/*
Assumptions:
- The increase is the average of each listing's own difference (2022 price - 2021 price), not the
  difference of the two neighborhood averages, so listings joining or leaving can't create a fake increase.
- Only listings with a price on both dates are included (inner join).
*/
