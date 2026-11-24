# Rental property analytics (dbt + DuckDB)

A dbt project that turns three source tables from a rental property system (listings, a daily calendar
and an amenities changelog) into a star schema at **listing/day grain**. Analysts can use it for
period-over-period revenue and occupancy analysis, and for amenity analysis that respects how amenities
changed over time.

## Project structure

```
models/
├── _docs.md                                  shared column descriptions (doc blocks)
├── staging/rental/
│   ├── _rental__sources.yml
│   ├── stg_rental__calendar.sql
│   ├── stg_rental__listings.sql
│   └── stg_rental__amenities_changelog.sql
├── intermediate/rental/
│   └── int_listing_amenities_history.sql
└── marts/core/rental/
    ├── fct_listing_daily.sql
    └── dim_listings.sql
analyses/                                     example queries on the mart
scripts/load_raw.sql                          loads the CSVs into raw
data/                                         source CSVs (not in the repo; see How to run)
```

Lineage:

```
raw.calendar ─────────────► stg_rental__calendar ──────────────────────────────────────────┐
raw.listings ─────────────► stg_rental__listings ──► dim_listings                          ├──► fct_listing_daily
raw.amenities_changelog ──► stg_rental__amenities_changelog ──► int_listing_amenities_history ┘
```

## Models

| Model | Grain | Materialization | Why this materialization |
|---|---|---|---|
| `stg_rental__calendar` | listing, date | incremental (`delete+insert`) | One row per listing per calendar day, so the table grows quickly: every listing adds a row for every day. Each run processes only newly loaded rows instead of rebuilding the whole table. |
| `stg_rental__listings` | listing | view | Small staging table with minimal transformation. |
| `stg_rental__amenities_changelog` | listing, change | view | Small staging table with minimal transformation. |
| `int_listing_amenities_history` | listing, amenities version | table | Built with window functions over each listing's full history. Storing the result means it is computed once per build, rather than every time the fact (which reads it twice on incremental runs) or its tests query it. |
| `dim_listings` | listing | table | Small table holding current values (SCD Type 1). It is part of the mart that analysts query directly, so it is stored rather than recomputed on every query. |
| `fct_listing_daily` | listing, day | incremental (`delete+insert`) | Grows with the calendar, one row per listing per day. Each run rebuilds only new calendar rows and the days of listings whose amenities changed. |

Row counts after a full build: calendar 18,250 (18,252 raw, 2 duplicates removed), listings 49, amenity
versions 100, fact 18,250. The calendar runs from 2021-07-12 to 2022-07-11.

Naming: `_at` for timestamps, `_date` for dates, `_usd` for money, `is_`/`has_` for booleans.

## Design decisions

**Star schema instead of one wide table.** The fact holds only what changes daily: availability, reservation,
price, stay limits and amenities. Listing attributes live in `dim_listings`, joined on `listing_id`. Putting
every listing, host and review attribute on every day would store the same values hundreds of times per
listing, a large and unnecessary copy of the dimension in every fact row. It would also mislead: values like
`number_of_reviews` are today's count, and copied onto every past day they look like daily history when they
aren't.

**The amenities changelog is the single source of truth for amenities.** The listings table also has an
amenities column, but only as a single snapshot. It was dropped from staging so there is one answer to "what
amenities did this listing have". Assumes every listing is in the changelog, covering its whole calendar
range; a relationships test warns if one isn't.

**Amenities as an SCD Type 2 history, joined as of each stay date.** `int_listing_amenities_history` turns
change events into half-open date ranges (`valid_from_date`, `valid_to_date`, `is_current`; the current
version ends 9999-12-31), and the fact joins on `valid_from_date <= calendar_date < valid_to_date`. Ranges are
dates, because the calendar is daily; when several changes happen on the same day, the last one wins, and a
change applies from the day it happened. Assumes `change_at` and `calendar_date` use the same timezone; if they
didn't, a late-evening change could land one day off.

**The full amenities list instead of amenity flags.** The fact carries `amenities` as a list. Any amenity can
be queried without a model change: `list_contains(amenities, 'air conditioning')`. Considered: boolean flags
per amenity, hardcoded or generated from a `vars` list. Rejected because every new amenity would still need a
code change. Amenity names are lowercased and trimmed in staging, so a capitalisation mismatch can't silently
return false. Trade-off: analysts still need the exact name, as spelling variants don't match.

**An incremental fact that takes amenity changes into account.** A simple incremental model: each run
rebuilds newly loaded calendar rows, plus the days of any listing whose amenities changed since the last run.

## Data quality

| Issue in the source | Handling |
|---|---|
| Duplicate calendar rows | Keep the most recently loaded row per listing/date |
| Missing key columns (today: 2 listings rows with no ID, one a test listing) | `not_null` source tests on every source's keys stop the build; listings rows with no ID (up to 10) warn and are dropped in staging |
| Test listings (name starts with "testing") | Excluded in staging |
| Reservation ID stored as the text `'NULL'` | Converted to a real null |
| Listing price stored as text (`'$1,250.00'`) | Converted to `decimal` |
| JSON arrays in text (amenities, host verifications) | Parsed into lists; amenity names lowercased and trimmed |
| Property type repeats the room type ("Private room in house") | Prefix removed ("house") |
| Bathrooms as free text ("1.5 shared baths") | Split into `bathroom_count` and `bathroom_privacy` |
| Missing bathrooms or bedrooms | Treated as 0 (for bedrooms, to be confirmed with the source team: null could also mean a studio) |
| Uppercase source column names | Renamed to lowercase |

## Tests

| What is tested | Tests | Severity |
|---|---|---|
| **Primary keys** | `unique` and `not_null` on every model's key: `listing_day_id` (calendar, fact), `listing_id` (listings, `dim_listings`), `listing_change_id` (changelog, amenities history). Surrogate keys are used where the natural key is two columns. | error |
| **Key columns** | `not_null` on the columns the surrogate keys are built from (calendar `listing_id`, `calendar_date`; changelog `listing_id`, `changed_at`) and on the fact's `listing_id` and `calendar_date` | error |
| **One amenities version per listing per day** | `dbt_utils.unique_combination_of_columns` on `listing_id` + `valid_from_date` in the amenities history | error |
| **Relationships between models** | Checked in both directions: calendar → listings, changelog → listings, listings → calendar, listings → changelog, fact → `dim_listings` | warn |
| **Every day has an amenities version** | `not_null` on the fact's `listing_change_id` | warn |
| **Prices** | `daily_price_usd` and `first_calendar_price_usd` must be greater than 0 (`dbt_utils.accepted_range`) | error |
| **Other values** | `accommodates` greater than 0, `room_type` in the known values, `host_id` not null | warn |
| **Business rule** | A reserved day is never marked available (`dbt_utils.expression_is_true` on the calendar) | warn |
| **Source keys** | `not_null` on each raw table's key columns (`listings.id`; calendar `listing_id`, `date`; changelog `listing_id`, `change_at`). They report missing keys where they start, before staging runs; for listings, staging drops the rows, so its own tests can't see them | error (listings: warn up to 10 rows, error above) |

## Analyses

Example queries on the mart, in `analyses/`. Each file starts with the question and ends with its
assumptions.

| Question | File | Approach |
|---|---|---|
| Revenue and share of revenue by month, with vs. without air conditioning | `amenity_revenue_by_month.sql` | `daily_price_usd` summed over booked days; AC checked on each stay date |
| Average price increase per neighborhood, 2021-07-12 → 2022-07-11 | `neighborhood_price_increase.sql` | Average of each listing's own price change, for listings priced on both dates |
| Longest possible stay for listings with a lockbox and a first aid kit | `longest_stay_lockbox_first_aid.sql` | Gaps and islands: runs of consecutive available days with both amenities, capped at `maximum_nights` and at least `minimum_nights` |

## Limitations

- **The first and last months are partial** (the calendar starts 2021-07-12 and ends 2022-07-11). Don't
  compare them month over month with full months.
- **Listing attributes are current values only** (`dim_listings` is SCD Type 1). Analysis by attributes such
  as beds uses today's values for every past date. Amenities are the exception: they have full history.
- **Amenities are as of the stay date, not the booking date.** The data has no booking timestamp. If a host
  changes amenities after a booking, the remaining nights show the new list.
- **Listing 276450 has calendar days but no listing details.** Its days are in the fact; an inner join to
  `dim_listings` drops them.
- **Amenity names must be spelled exactly.** Names are lowercased and trimmed in staging, but spelling
  variants (e.g. "wi-fi" vs "wifi", "first-aid kit" vs "first aid kit") don't match.

## Future improvements

- **SCD Type 2 for listings, if the business needs it.** If analysts need revenue by listing attributes as
  they were at the time (e.g. by number of bedrooms before and after a renovation), `dim_listings` would
  become a versioned dimension. A dbt snapshot on listings can record each version as it arrives, and the
  fact would join to the version in effect on each day.
- **Amenities as of the booking date.** Amenities are currently matched to each stay date. A guest decides
  based on the amenities listed when they book, so if a host adds air conditioning after a booking, today's
  model counts that stay as "with AC" even though AC didn't influence the booking. With a booking timestamp
  on reservations, amenities could be matched as of the booking, which is more accurate for questions like
  "how much revenue does AC bring in".
- **A flattened amenities model** (one row per listing, version and amenity) for analysing amenities across
  all listings.
- **Tests for incremental behaviour,** such as late-arriving calendar rows and amenity changes after a
  booking.
- **Source freshness** on `_loaded_at` (e.g. warn after 24 hours, error after 48 hours, run with
  `dbt source freshness`), to catch a load that has silently stopped.
- **Revisit materializations and performance at scale.** The materializations suit today's data volume.
  At much larger volumes, each model's materialization, incremental logic and physical layout (e.g.
  clustering on dates) would be reviewed and optimized, along with the cost of tests on large tables.

## AI usage

I used Claude (Claude Code) as a pair programmer throughout the project: to write and refactor code,
explore alternative modeling approaches and their trade-offs, debug, and draft documentation. The design
decisions were mine. I reviewed, tested and validated all of the code against the data, and kept a log of
each decision and the alternatives considered.

## How to run

Requires Python 3.10+ and the DuckDB CLI.

```bash
python -m venv .venv && source .venv/bin/activate      # or: uv venv && source .venv/bin/activate
pip install -r requirements.txt                         # dbt-core 1.12.7, dbt-duckdb 1.11.1
dbt deps                                                # dbt_utils

mkdir -p data && cp <path to the provided CSVs>/*.csv data/
duckdb rental.duckdb < scripts/load_raw.sql             # loads data/*.csv into the raw schema
dbt build --full-refresh                                # builds all models and runs all tests

dbt docs generate && dbt docs serve                     # lineage graph and documentation
```

Run everything from the project root: `profiles.yml` is in the repo and points to `rental.duckdb` in the
current folder.

To run an analysis:

```bash
dbt compile --select "path:analyses"
duckdb -readonly rental.duckdb < target/compiled/rental_property/analyses/amenity_revenue_by_month.sql
```

The source CSVs have no load timestamp. `scripts/load_raw.sql` adds a `_loaded_at` column to each raw
table, standing in for the timestamp a loading tool (e.g. Fivetran, Airbyte) would add in production. It
drives deduplication (latest load wins) and incremental runs.
