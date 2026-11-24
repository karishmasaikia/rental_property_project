/*
Problem #3 - Long Stay / Picky Renter
Determine the longest possible stay duration for rental listings that include both a lockbox and
a first aid kit in their amenities, considering both listing availability windows and maximum stay
limits set by property owners.
Example from the brief: listing 1303261 has both a lockbox and a first aid kit; the longest possible
stay would be 159 days.
*/

with filtered_data as (
    select listing_id, calendar_date, maximum_nights, minimum_nights
    from {{ ref('fct_listing_daily') }}
    where list_contains(amenities, 'lockbox')
    and list_contains(amenities, 'first aid kit')
    and is_available = true
)
, ranks_and_groups as (
    select *
    , row_number() over(partition by listing_id order by calendar_date) rn
    , calendar_date-rn::int as groups
    from filtered_data
)

select
listing_id
, groups
, max(maximum_nights) max_nights
, min(minimum_nights) min_nights
, count(*) available_nights
, least(available_nights, max_nights) longest_possible_nights
, min(calendar_date) start_date
, max(calendar_date) end_date
from ranks_and_groups
group by 1,2
having longest_possible_nights>=min_nights
qualify row_number() over(partition by listing_id order by longest_possible_nights desc) = 1
order by longest_possible_nights desc

/*
Assumptions:
- A stay can only use consecutive days that are available AND have both amenities on that day
  (exact match on 'lockbox' and 'first aid kit'; amenity names are lowercased in staging).
- is_available alone is enough: a staging test confirms no reserved day is marked available.
- Each window's stay is capped at maximum_nights and must be at least minimum_nights.
- The limits used are the most generous in the window (max of maximum_nights, min of minimum_nights).
  The stricter reading uses the limits on the check-in day; neither limit changes within a window
  in this data, so both give the same result.
- A window that reaches the last calendar date (2022-07-11) may continue beyond the data, so the true
  longest stay could be longer (1303261 could reach its 180-night maximum).
*/
