# Data Source: cookingconverter (MSRTC Timetables)

## Where the data came from
- GitHub: https://github.com/cookingconvertertools-web/msrtc-bus-timetable
- 45 depot timetable files across Vidarbha, Khandesh, and Marathwada regions
- Retrieved and extracted from published depot timetable pages

## What we did with it
- Parsed division, district, tehsil, and depot-level JSON files
- Combined into a single offline SQLite database (st_timetable.db)
- Kept only verified fields: origins, destinations, departure times, via-stops, bus types
- Did not model or invent: no synthetic arrival times, fares, or seat counts
- Fields not published by the source are omitted, not guessed

## Known gaps
- Some rural routes may be missing from the source data
- Fares and arrival times are not published by this source and are not in the app