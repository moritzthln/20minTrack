#!/usr/bin/env python3
"""Writes an English demo dataset (two weeks, stock labels, goals, one
absence, a pending check-in with app usage) into 20minTrack's storage.
Only for README screenshots — render_screenshots.sh backs up and
restores the real data around it."""
import datetime as dt, json, os, random, shutil, subprocess, uuid
from zoneinfo import ZoneInfo

TZ = ZoneInfo("Europe/Berlin")
REF = dt.datetime(2001, 1, 1, tzinfo=dt.timezone.utc)
BASE = os.path.expanduser("~/Library/Application Support/20minTrack")
DOMAIN = "com.moritzthelen.twentymintrack"
FOCUS = ["API refactor", "Onboarding flow", "Writing the launch post", "Pricing page",
         "Bug bash", "Data model for v2", "Landing page copy"]
FAZIT = ["Strong morning, drifted after lunch — phone away tomorrow.",
         "Shipped the onboarding flow. Felt great.", "Too many calls, barely any deep work.",
         "Good balance today, gym + 5h focus.", "Slow start, but the afternoon block was excellent."]


def ts(d):
    return (d - REF).total_seconds()


def weekday_plan(r):
    f = r.choice(FOCUS)
    plan = [(0, 0, "sleep", ""), (7, 0, "orga", "Breakfast & shower")]
    if r.random() < .5:
        plan.append((7, 40, "sport", "Morning run"))
    plan += [(8, 20, "orga", "Inbox"), (8, 40, "focus-mma", f), (11, 0, "calls", "Standup"),
             (11, 20, "focus-mma", f), (12, 20, "fun", "Lunch walk"), (13, 0, "half-focus", "Code review"),
             (13, 40, "no-focus" if r.random() < .6 else "half-focus", "YouTube" if r.random() < .6 else "Slack"),
             (14, 0, "focus-mma", r.choice(FOCUS)),
             (16, 0, "calls", r.choice(["Client call", "1:1 with Sam", "Design sync"])),
             (16, 40, "half-focus", "Docs"), (17, 20, "orga", "Groceries"),
             (18, 0, "sport" if r.random() < .6 else "fun", "Gym" if r.random() < .6 else "Walk"),
             (19, 0, "orga", "Cooking & dinner"), (20, 0, "fun", r.choice(["Reading", "Series", "Guitar"])),
             (22, 0, "no-focus" if r.random() < .5 else "fun", "Instagram" if r.random() < .5 else "Reading"),
             (23, 0, "sleep", "")]
    return plan


def weekend_plan(_):
    return [(0, 0, "sleep", ""), (8, 40, "orga", "Slow breakfast"), (10, 0, "sport", "Long run"),
            (11, 20, "fun", "Brunch with friends"), (14, 0, "half-focus", "Side project"),
            (16, 0, "fun", "Park"), (18, 0, "orga", "Cooking"), (19, 20, "fun", "Movie night"),
            (21, 40, "no-focus", "YouTube"), (23, 20, "sleep", "")]


def main():
    now = dt.datetime.now(TZ)
    today = now.date()
    # Pending span: the two blocks before the last completed boundary.
    last = now.replace(minute=now.minute - now.minute % 20, second=0, microsecond=0)
    anchor = last - dt.timedelta(minutes=40)
    shutil.rmtree(BASE, ignore_errors=True)
    os.makedirs(BASE + "/days")
    os.makedirs(BASE + "/usage")
    away = {today - dt.timedelta(days=12), today - dt.timedelta(days=11)}
    for back in range(16, -1, -1):
        day = today - dt.timedelta(days=back)
        if day in away:
            continue
        r = random.Random(day.toordinal())
        plan = weekend_plan(r) if day.weekday() >= 5 else weekday_plan(r)
        starts = [dt.datetime(day.year, day.month, day.day, h, m, tzinfo=TZ) for h, m, _, _ in plan]
        ends = starts[1:] + [dt.datetime.combine(day + dt.timedelta(days=1), dt.time(0), tzinfo=TZ)]
        entries = []
        for (_, _, label, text), start, end in zip(plan, starts, ends):
            if day == today:
                if start >= anchor:
                    break
                end = min(end, anchor)
            entries.append({"id": str(uuid.uuid4()).upper(), "start": ts(start), "end": ts(end),
                            "labelID": label, "text": text})
        data = {"entries": entries}
        if day != today:
            data["fazit"] = r.choice(FAZIT)
        json.dump(data, open(f"{BASE}/days/{day}.json", "w"))
    segments, t = [], anchor
    for bundle, name, minutes in [("com.apple.dt.Xcode", "Xcode", 17), ("site:github.com", "github.com", 9),
                                  ("com.tinyspeck.slackmacgap", "Slack", 6), ("com.apple.Safari", "Safari", 4),
                                  ("com.apple.dt.Xcode", "Xcode", 4)]:
        segments.append({"id": str(uuid.uuid4()).upper(), "bundleID": bundle, "name": name,
                         "start": ts(t), "end": ts(t + dt.timedelta(minutes=minutes))})
        t += dt.timedelta(minutes=minutes)
    json.dump(segments, open(f"{BASE}/usage/{today}.json", "w"))
    labels = [
        {"id": "focus-mma", "name": "Focus Work", "colorKey": "green", "archived": False, "goalMinutes": 270},
        {"id": "half-focus", "name": "Half Focus", "colorKey": "yellow", "archived": False},
        {"id": "orga", "name": "Admin & Everyday", "colorKey": "blue", "archived": False},
        {"id": "calls", "name": "Calls", "colorKey": "mint", "archived": False},
        {"id": "no-focus", "name": "Distraction", "colorKey": "red", "archived": False},
        {"id": "fun", "name": "Recreation", "colorKey": "orange", "archived": False},
        {"id": "sport", "name": "Sport", "colorKey": "teal", "archived": False, "goalMinutes": 60},
        {"id": "sleep", "name": "Sleep", "colorKey": "indigo", "archived": False, "goalMinutes": 480},
    ]
    first_away = min(away)
    absences = [{"id": str(uuid.uuid4()).upper(), "name": "Weekend trip",
                 "startDay": ts(dt.datetime.combine(first_away, dt.time(0), tzinfo=TZ)),
                 "endDay": ts(dt.datetime.combine(max(away), dt.time(0), tzinfo=TZ))}]
    subprocess.run(["defaults", "delete", DOMAIN], capture_output=True)

    def write(*args):
        subprocess.run(["defaults", "write", DOMAIN, *args], check=True)
    write("labels", "-data", json.dumps(labels).encode().hex())
    write("absences", "-data", json.dumps(absences).encode().hex())
    write("checkinAnchor", "-date", anchor.astimezone(dt.timezone.utc).strftime("%Y-%m-%d %H:%M:%S +0000"))
    write("lastLabelID", "focus-mma")
    write("languageOverride", "en")
    write("chimeVolume", "-float", "0.6")


if __name__ == "__main__":
    main()
