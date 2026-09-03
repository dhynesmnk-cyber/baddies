# Becoming Baddies

A two person workout tracker for **Dave** and **Angus**. Log strength sets, distances and
timed work in a few taps, then compare results activity by activity.

Supabase owns persistence, auth and row level security. The front end is a single HTML
file with no build step.

```
becoming-baddies-supabase.html   the whole app
sql/schema.sql                   tables, indexes, RLS policies, seed activities, realtime
sql/realtime.sql                 realtime only, for projects created before live sync
index.html                       redirect, so static hosts serve the app at /
```

## What it does

- **Workout** - pick a date, work the card list for that weekday. Strength logs completed
  sets, Run and Swim log kilometres, Skipping, Boxing and Plank log time on a live timer.
  Every change is written straight to Supabase.
- **Routine** - a weekly plan per profile. Empty days are rest days. Add activities from
  the shared library, reorder them, override sets, reps, rest, target distance or target
  time.
- **Activities** - the shared exercise library. Adding a routine item copies the library
  settings into the routine item, so Dave and Angus can run the same exercise at different
  targets without rewriting each other's history.
- **Compare** - head to head banner, per person totals, a 12 week consistency heatmap, a
  per activity breakdown with horizontal bars, and a grouped weekly bar chart for whichever
  activity you tap.
- **Live sync** - both screens update as the other person trains, with no refresh. A `LIVE`
  badge in the header shows the connection state.

### Visuals

- Animated radial progress ring for the selected training day, with streak and weekly
  points chips.
- Per day meters on the weekday tabs, and a live dot on today.
- A sparkline of the last ten sessions on every workout card, with the personal best
  highlighted.
- Completion glow and a `DONE` stamp that fire the moment a card is finished.
- Timer progress bar against the target, and a pulsing display while running.
- Head to head tug of war bar, crown for the leader, and per metric leader highlighting.
- GitHub style consistency heatmap per person, tinted in that person's colour.

### Live sync

Supabase Realtime streams every change to `logs`, `routine_items`, `activities` and
`profiles` to both signed in browsers. Row level security applies to the stream, so it
carries exactly what each user is allowed to read.

The rule the UI follows is that a live update never costs you work in progress:

- A running timer keeps running, and a distance you have typed but not saved is preserved
  across a rebuild.
- Your own logs arriving from another device patch the affected card in place - checkboxes,
  completion glow, stats and the day ring - rather than rebuilding the screen.
- A routine change that arrives mid set is deferred, with a note in the status bar, and
  applied as soon as you are no longer mid interaction.
- Bursts are coalesced, so the other person ticking eight sets costs one render.
- Their activity raises at most one status message a minute, so it stays useful rather than
  chatty.

If the socket drops, the badge turns to `Offline` and reconnects with backoff. Because
events that happen while disconnected are gone for good, every reconnect and every return
to the tab refetches rather than trusting the local copy.

### Scoring

The head to head bar and the points chips use one simple formula:

| Work | Points |
| --- | --- |
| One completed strength set | 1 |
| One kilometre | 3 |
| One minute of timer work | 0.5 |

Change the `POINTS` constant near the top of the script to rebalance it. Everything else
in Compare is like for like: sets against sets, km against km, minutes against minutes.

## Setup

1. Create a Supabase project.
2. Open the **SQL Editor** and run [`sql/schema.sql`](sql/schema.sql). It creates the
   tables, enables row level security, adds the policies, seeds the starter activity
   library and enables Realtime. If your project predates live sync, run
   [`sql/realtime.sql`](sql/realtime.sql) instead; it is idempotent and touches nothing
   else.
3. For quick testing, turn off email confirmation under **Authentication, Providers,
   Email**. If you leave confirmation on, each user has to confirm their email before they
   can sign in.
4. Point the app at your project, either way:
   - **Edit the file.** Replace these two lines near the top of the `<script>` block:
     ```js
     const SUPABASE_URL = "https://YOUR_PROJECT.supabase.co";
     const SUPABASE_ANON_KEY = "YOUR_ANON_KEY";
     ```
   - **Or paste at runtime.** Leave the placeholders and open the file. A setup screen asks
     for the project URL and anon key and stores them in that browser's local storage.
5. Open `becoming-baddies-supabase.html`, sign up, and enter a profile name. Use real
   names, `Dave` and `Angus`, so the colours and comparisons line up.
6. On the Routine screen, hit **Load starter week** for a three day starting plan, then
   edit it.

The anon key is a public key. It is designed to ship in the browser. Row level security is
what actually protects the data, which is why step 2 is not optional.

## Security model

- Everyone signed in can **read** all profiles, routines and logs. That is the point of a
  two person competition.
- You can only **write** rows tied to your own profile. Writes are checked server side by
  `public.is_profile_owner(profile_id)`, not by the front end.
- The activity library is shared read and write, deliberately, so either of you can add an
  exercise.
- If you ever want Angus unable to read Dave's raw logs, change the `logs_select` and
  `routine_select` policies. The Compare screen would then need a database view that only
  exposes aggregates.

## Known limits

- The Compare screen loads every log row. That is fine for two people and years of
  training; it would need pagination for a crowd.
- The workout screen is a card list, not a swipe deck. Swipe is presentation, and it adds
  failure modes when every interaction is a database write. Worth adding once persistence
  has proven itself.
- Deleting a library activity leaves existing routine items and logs intact, keeping their
  saved name and type. History survives on purpose.
