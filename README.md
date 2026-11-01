# Ski Radio

Native iPhone internet radio with a full CarPlay interface. Stations come from the free
[Radio Browser](https://www.radio-browser.info) directory (50,000+ live stations, no API key).

## Features

**iPhone**
- Favorites tab first: big station tiles, tap to play or pause, Edit to reorder/delete
- Discover: your favorites, recently played, 14 genres, popular in your country, top worldwide
- Search by station name
- Station logos, with a colored initials tile for stations that have none
- Now Playing: song title and artist from the stream, album art from the iTunes catalog,
  LIVE badge, codec/bitrate, AirPlay picker
- Plays in the background, with lock screen / Control Center controls and station logos
- Next/previous skips through the list you started from
- Pauses for calls and resumes after

**CarPlay**
- Tabs: Favorites, Recent, Popular, Genres
- Station logos and a playing indicator on the current station
- Now Playing screen with skip buttons and a heart button to favorite the station

## Project layout

```
project.yml                 XcodeGen spec (generates SkiRadio.xcodeproj)
Support/Info.plist          background audio + CarPlay scene
Support/SkiRadio.entitlements  CarPlay audio entitlement
SkiRadio/App                app entry + tabs
SkiRadio/Models             Station, Genre
SkiRadio/Services           RadioBrowser API, RadioPlayer, Library, ImageCache
SkiRadio/Views              SwiftUI screens
SkiRadio/CarPlay            CarPlaySceneDelegate
.github/workflows/build.yml CI: compile check + unsigned IPA
```

## Build

**GitHub Actions:** push to a repo and the workflow builds on macOS and uploads
`SkiRadio-unsigned.ipa` as an artifact.

**On a Mac:**
```
brew install xcodegen
xcodegen generate
open SkiRadio.xcodeproj
```

## Trying CarPlay

- **Simulator:** run on an iPhone simulator, then in the Simulator menu choose
  I/O → External Displays → CarPlay.
- **Real car:** Apple only lets apps appear in CarPlay if the developer account has been
  granted the CarPlay Audio entitlement. You need a paid Apple Developer account, then request
  it at https://developer.apple.com/carplay/. Once approved, sign with a provisioning profile
  that includes it and install through Xcode or TestFlight.
- **Free signing / sideloading:** the phone app works, but the CarPlay entitlement gets
  stripped, so it won't show up on the car screen. If signing fails because of the
  entitlement, remove `CODE_SIGN_ENTITLEMENTS` from `project.yml`.
