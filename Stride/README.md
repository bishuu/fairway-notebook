# Stride – step counter for iPhone

Stride counts your steps in real time, tracks walks on a live map, links with
Apple Health, keeps a history, and estimates calories from your weight, height
and gender.

## What it does

- **Today** – a big animated ring shows today's steps against your daily goal,
  with distance, calories and your 7-day average. Steps tick up live as you walk.
- **Start a Walk** – one tap starts a walk workout. The map follows you with a
  pulsing walker marker and draws your route as you go. You see time, steps,
  miles, calories and pace live. Pause, resume, and end whenever you like.
  Tracking keeps going while the screen is off.
- **Apple Health** – reads your step total (so it matches the Health app, Apple
  Watch included), can prefill your weight, height and sex, and saves every walk
  as a walking workout with its route, distance and calories.
- **History** – every walk with a route thumbnail, stats, and an animated replay
  of the route on the map. Plus a 7-day / 30-day step chart.
- **Profile** – weight (lb), height (ft/in), gender, and your daily step goal.

Calories use MET values for walking (Compendium of Physical Activities), chosen
by your pace and multiplied by your weight and time. Height and gender set your
stride length, which turns steps into distance when there is no GPS.

## Putting it on your iPhone

You need a Mac with **Xcode** (free on the Mac App Store), your iPhone, a cable,
and your Apple ID. No paid developer account is required.

1. **Get the code.** On the GitHub page click the green **Code** button →
   **Download ZIP**, then unzip it. (Or clone the repository.)
2. **Open the project.** Inside the `Stride` folder, double-click
   `Stride.xcodeproj`. Xcode opens.
3. **Sign it with your Apple ID.** In the left sidebar click the blue **Stride**
   project icon at the very top. Under *TARGETS* choose **Stride**, open the
   **Signing & Capabilities** tab, and pick your **Team**. If there is none, use
   **Add an Account…** and sign in with your Apple ID, then choose the
   *Personal Team* that appears.
   - If Xcode says the bundle identifier is not available, change
     `com.bishuu.stride` to something unique, like `com.yourname.stride`.
4. **Plug in your iPhone.** Unlock it and tap **Trust** if asked. At the top of
   the Xcode window choose your iPhone as the destination (instead of a
   simulator).
5. **Press Run (▶).** Xcode builds the app and installs it.
   - First time only: on the iPhone go to **Settings → General → VPN & Device
     Management**, tap your Apple ID and tap **Trust**.
   - If the phone asks to turn on **Developer Mode** (Settings → Privacy &
     Security → Developer Mode), turn it on, restart, and press Run again.
6. **Open Stride** and allow Motion & Fitness, Apple Health and Location when
   asked. Enter your weight, height and gender, and you are set.

Good to know:

- With a free Apple ID the install stops working after **7 days**. Just plug in
  and press Run again to refresh it. A paid Apple Developer account keeps it
  working for a year.
- The iPhone Simulator cannot count steps or use GPS, so test on a real phone.
- Steps come from the iPhone's motion chip, so carry the phone with you. If you
  wear an Apple Watch, connect Apple Health and Stride will show the combined
  total the Health app shows.

## Project layout

```
Stride/
  Stride.xcodeproj        – open this in Xcode
  Stride/
    StrideApp.swift       – app entry point
    Info.plist            – permissions text and background location
    Stride.entitlements   – Apple Health capability
    Models/               – walks, profile, calorie maths, formatting
    Services/             – pedometer, location, Apple Health, storage
    ViewModels/           – today's live steps, the walk workout engine
    Views/                – screens and reusable animated components
```

Requires iOS 17 or later.
