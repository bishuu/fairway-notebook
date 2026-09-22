# Stride – step counter for iPhone

Stride counts your steps in real time, tracks walks on a live map, replays them
afterwards, links with Apple Health, keeps a history with badges and trends, and
estimates calories from your weight, height and gender.

## What it does

**Today**
- A big animated ring shows today's steps against your daily goal, with
  distance, calories and your 7-day average. Steps tick up live as you walk.
- A streak counter for days in a row you have hit your goal.
- Confetti when you reach the goal.

**Walks**
- One tap starts a walk. The map follows you with a pulsing walker marker and
  draws your route as you go. Time, steps, distance, calories and pace update
  live, plus climbing from the barometer and heart rate if you wear a watch.
- Tracking keeps running with the screen off. Pause and resume as you like.
- A Live Activity shows the walk on your Lock Screen and in the Dynamic Island,
  with a timer that keeps counting on its own.

**Replay**
- Every saved walk replays as a flythrough: the camera follows the walker along
  the route in 3D, and the line is coloured by how fast each stretch was, from
  deep indigo for slow to bright lime for fast.
- Distance, time and pace count up as it plays. Change speed, scrub to any
  point, or switch to a view of the whole route.

**Widgets**
- Home Screen widgets in small and medium, with the ring, distance, calories,
  streak and a Start a Walk button.
- Lock Screen widgets: a ring, a wide bar with the steps left to go, and an
  inline line beside the clock.

**History**
- Every walk with a route thumbnail and full stats.
- Steps per day for 7 or 30 days.
- Weekly and monthly reports comparing this period with the last.
- Sixteen badges, personal records and your best streak.
- A share card image of any walk for Messages or social apps.

**Apple Health**
- Reads your step total so it matches the Health app (Apple Watch included),
  reads heart rate during walks, and can prefill your weight, height and sex.
- Saves every walk as a walking workout with its route, distance and calories,
  with paused time excluded.

**Also**
- Miles or kilometres, everywhere in the app.
- An evening reminder when your goal is still within reach.
- Backup and restore through the Files app, so your walks survive a new phone.
- Siri and Shortcuts: "Start a walk in Stride".

Calories use MET values for walking (Compendium of Physical Activities), chosen
by your pace and multiplied by your weight and time. Height and gender set your
stride length, which turns steps into distance when there is no GPS.

## Putting it on your iPhone

You need a Mac with **Xcode** (free on the Mac App Store, with the iOS platform
component installed), your iPhone, a cable, and your Apple ID. No paid developer
account is required for the app itself; see the note on widgets below.

1. **Get the code.** On the GitHub page click the green **Code** button →
   **Download ZIP**, then unzip it. (Or clone the repository.)
2. **Open the project.** Inside the `Stride` folder, double-click
   `Stride.xcodeproj`. Xcode opens. Do not open the files inside it.
3. **Sign it with your Apple ID.** In the left sidebar click the blue **Stride**
   project icon at the very top. Under *TARGETS* choose **Stride**, open the
   **Signing & Capabilities** tab, and pick your **Team**. If there is none, use
   **Add an Account…** and sign in with your Apple ID, then choose the
   *Personal Team* that appears. **Do the same for the StrideWidgets target.**
   - If Xcode says a bundle identifier is not available, change
     `com.bishuu.stride` to something unique like `com.yourname.stride`, and
     change the widget's to the same thing with `.StrideWidgets` on the end.
4. **Plug in your iPhone.** Unlock it and tap **Trust** if asked. At the top of
   the Xcode window choose your iPhone as the destination.
5. **Press Run (▶).** Xcode builds the app and installs it.
   - First time only: on the iPhone go to **Settings → General → VPN & Device
     Management**, tap your Apple ID and tap **Trust**.
   - If the phone asks to turn on **Developer Mode** (Settings → Privacy &
     Security → Developer Mode), turn it on, restart, and press Run again.
6. **Open Stride** and allow Motion & Fitness, Apple Health and Location when
   asked. Enter your weight, height and gender, and you are set.

### Adding the widgets to your phone

Touch and hold an empty part of the Home Screen, tap **Edit → Add Widget**, and
search for Stride. For the Lock Screen, touch and hold the Lock Screen, tap
**Customise**, then tap a widget slot and pick Stride.

### If the widgets show "Open Stride" instead of your steps

The app and its widgets share data through an **App Group**, a capability that a
paid Apple Developer account provides. With a free Apple ID the app itself works
completely; only the widget's numbers are affected, and the app says so at the
bottom of the Profile tab.

If Xcode refuses to build with a signing error about App Groups, you can remove
the capability in a minute: select the **Stride** target → **Signing &
Capabilities** → hover over **App Groups** → click the **x**. Do the same for
the **StrideWidgets** target. Everything else keeps working.

### Good to know

- With a free Apple ID the install stops working after **7 days**. Plug in and
  press Run again to refresh it. A paid Apple Developer account keeps it working
  for a year.
- Free Apple IDs are limited to about 10 app identifiers per week. This project
  uses two (the app and the widget).
- The iPhone Simulator cannot count steps or use GPS, so test on a real phone.
- Steps come from the iPhone's motion chip, so carry the phone with you. If you
  wear an Apple Watch, connect Apple Health and Stride shows the combined total
  the Health app shows.
- Heart rate only appears if something writes it to Apple Health, such as an
  Apple Watch.

## Project layout

```
Stride/
  Stride.xcodeproj          – open this in Xcode
  Stride/                   – the app
    StrideApp.swift         – app entry point
    Info.plist              – permissions, Live Activities, background location
    Stride.entitlements     – Apple Health and App Group
    Shared/                 – code the app and the widgets both use
    Models/                 – walks, profile, calories, badges, trends, routes
    Services/               – pedometer, location, Health, altimeter,
                              notifications, Live Activity, storage, backup
    ViewModels/             – today's live steps, the walk workout engine
    Views/                  – screens and reusable animated components
    Intents/                – Siri phrases
  StrideWidgets/            – Home Screen, Lock Screen and Live Activity
```

Requires iOS 17 or later.
