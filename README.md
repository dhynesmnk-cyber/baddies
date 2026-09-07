# Becoming Baddies

A two person workout tracker for **Dave** and **Angus**. Log strength sets, distances and
timed work in a few taps, then compare results activity by activity.

Supabase owns persistence, auth and row level security. The front end is a single HTML
file with no build step.

```
becoming-baddies-supabase.html   the whole app
sql/schema.sql                   tables, indexes, RLS policies, seed activities
sql/users.sql                    the two fixed logins and their profiles
sql/realtime.sql                 optional, only if you want live sync back
index.html                       redirect, so static hosts serve the app at /
```

## Getting in

There is no sign up and no email. Open the app, tap **Dave** or **Angus**, and key in the
4 digit PIN. The session is remembered, so day to day you just open it and train.

Both names unlock with **9876** out of the box.

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
- **Refresh** - the app loads everything on sign in and then leaves the screen alone. A
  `Refresh` button in the header pulls the other person's training in when you want it.

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

### Refreshing

Data is fetched once at sign in. Nothing polls, and nothing re-renders behind your back, so
the screen only ever changes because you changed it. **Refresh** in the header refetches
profiles, activities, routines and logs, and redraws every screen.

Two things a refresh will not take from you:

- A running timer. The workout list rebuild is held until you pause, reset or finish,
  and the status bar says so. Everything else redraws immediately.
- A distance you have typed but not saved. It survives the rebuild.

An earlier version pushed changes between the two phones over Supabase Realtime. It worked,
but a socket that reconnects is a screen that redraws on its own, and for two people
training at different times that was noise rather than a feature. The database side of it
still exists in [`sql/realtime.sql`](sql/realtime.sql) if it is ever wanted back.

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
   library.
3. Run [`sql/users.sql`](sql/users.sql). It creates the two logins, sets both PINs to
   9876, and links a profile to each. If it errors on your Supabase version, the file
   explains the two minute dashboard alternative.
4. Point the app at your project by editing these two lines near the top of the
   `<script>` block:
   ```js
   const SUPABASE_URL = "https://YOUR_PROJECT.supabase.co";
   const SUPABASE_ANON_KEY = "YOUR_ANON_KEY";
   ```
   Baking them in means every phone, tablet and browser opens straight on the name and
   PIN screen. Leave the placeholders instead and the app shows a setup screen that asks
   for the pair and stores it in that one browser's local storage, which has to be redone
   per device.
5. Open `becoming-baddies-supabase.html`, tap your name and key in **9876**.
6. On the Routine screen, hit **Load starter week** for a three day starting plan, then
   edit it.

The anon key is a public key. It is designed to ship in the browser. Row level security is
what actually protects the data, which is why step 2 is not optional.

## The PIN

Supabase enforces a minimum password length of 6, so `9876` cannot be the password itself.
The app turns what you type into the real password by appending a fixed suffix:

```
password = <pin> + "-becoming-baddies"
```

Only that recipe is in the published HTML. The PIN never is, so reading the page source is
not enough to get in.

**To change the PIN**, edit `new_pin` at the top of `sql/users.sql` and run it again. The
app needs no change.

Two honest limits. The same PIN unlocks both names, so either of you could tap the other's
card and log as them — it is a friendly gate between two mates, not a wall. If you want
that closed, give each account its own password (`1234-becoming-baddies` for one,
`5678-becoming-baddies` for the other) and the app handles it with no code change. And a
4 digit PIN is only 10,000 guesses, so it keeps out a passer by, not a determined attacker.
For two people tracking press ups, that is the right trade.

## Security model

- The two logins are fixed. There is no sign up, so nobody can add themselves.
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
- Nothing updates between the two phones on its own. If you want to see what the other
  person has done, press Refresh.
