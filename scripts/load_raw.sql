create schema if not exists raw;

create or replace table raw.listings as
select *, cast(current_timestamp as timestamp) as _loaded_at
from read_csv_auto('data/LISTINGS.csv');

create or replace table raw.calendar as
select *, cast(current_timestamp as timestamp) as _loaded_at
from read_csv_auto('data/CALENDAR.csv');

create or replace table raw.amenities_changelog as
select *, cast(current_timestamp as timestamp) as _loaded_at
from read_csv_auto('data/AMENITIES_CHANGELOG.csv');
