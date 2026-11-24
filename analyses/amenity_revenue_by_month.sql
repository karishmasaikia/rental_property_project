/*
Problem #1 - Amenity Revenue
Find the total revenue and percentage of revenue by month, segmented by whether or not
air conditioning exists on the listing.
Example from the brief: only 21.2% of revenue in July 2022 came from listings without air conditioning.
*/

with filtered_data as (
    select
    date_trunc('month', calendar_date)::date as months
    , daily_price_usd
    , list_contains(amenities, 'air conditioning') as has_ac
    from {{ ref('fct_listing_daily') }}
    where is_booked
)
, total_revenue as (
    select
    months
    , sum(daily_price_usd) as total_revenue
    from filtered_data
    group by 1
)

select
fd.months
, has_ac
, sum(daily_price_usd) as revenue_by_ac
, round(revenue_by_ac * 100 / max(tv.total_revenue),2) revenue_percent
from filtered_data fd
left join total_revenue tv
on fd.months = tv.months
group by 1,2
order by 1,2

/*
Assumptions:
- Revenue is the sum of daily_price_usd over booked days
- Air conditioning is checked as of each stay date rather than booked date with an exact match on 'air conditioning'
- Misuse: the calendar starts on 2021-07-12 and ends on 2022-07-11, so the first and last months are
  partial. July 2022 revenue is about a third of other months, so a month-over-month chart would show a
  false drop
*/
