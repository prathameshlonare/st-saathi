# Data Source: vaibhav (MSRTC Timetables)

## Where the data came from
- GitHub: https://github.com/vaibhavmanch3kar/maharashtra-st-timetable
- 371 rows extracted from published depot timetable pages (Ratnagiri, Mumbai Central, Pune Swargate, Kurundwad)
- Retrieved 2026-08-28

## What we did with it
- Parsed source rows; departure-time lists were split and validated
- Each (origin, destination, departure) became one service - 1,514 total across 278 stations
- Fields the source does not publish - arrival, duration, fare, service class, platform, seats - were modelled with simple heuristics and labelled as modelled inside the app (Settings → Data sources)
- Embedded into the offline SQLite database (st_timetable.db)

## Known gaps
- 31 MSRTC divisional timetables exist only as scanned Marathi PDFs (614 pages, image-only, Devanagari numerals) - not yet in this dataset
- Fares shown in-app are modelled, not tariff-table values