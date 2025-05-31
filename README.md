# Index

![Index Screenshots](https://raw.githubusercontent.com/moses-mbaga/semo/d4ed0519764b78d729cc459476086928d0a2d54b/banner.png)

Index is an open-source Flutter application designed to offer a seamless movie and TV show streaming experience. With support for multiple streaming servers, synced watch progress, and fully customizable subtitles, Index aims to be your go-to streaming app for enjoying your favorite content.

## Features

🗂 Comprehensive Library

- Access almost all movies and TV shows.
- Explore a vast library to find something for everyone.

🎥 Stream Playback

- Play movies and TV shows directly using high-quality HLS streams.
- Multiple streaming servers to ensure uninterrupted viewing.

⏳ Synced Watch Progress

- Automatically syncs playback progress for movies and episodes.
- Never lose your spot, even if you switch devices or revisit content later.

🔠 Customizable Subtitles

- Support for .srt subtitle files.
- Fully customizable options

## Download ![GitHub Downloads (all assets, all releases)](https://img.shields.io/github/downloads/moses-mbaga/semo/total?link=https%3A%2F%2Fgithub.com%2Fmoses-mbaga%2Fsemo%2Freleases)

Download APK
[![Download APK](https://custom-icon-badges.demolab.com/badge/-Download-F25278?style=for-the-badge&logo=download&logoColor=white&color=AB261D)](https://github.com/moses-mbaga/semo/releases)

Download IPA
[![Download IPA](https://custom-icon-badges.demolab.com/badge/-Download-F25278?style=for-the-badge&logo=download&logoColor=white&color=AB261D)](https://github.com/moses-mbaga/semo/releases)

## Tech Stack

**Client:** Flutter

**Server:** Firebase

## Installation

Prerequisites:
- [Flutter SDK](https://flutter.dev/) (latest stable version).
- A code editor (e.g., [VSCode](https://code.visualstudio.com/), [Android Studio](https://developer.android.com/studio)).
- A Firebase account

Instructions:

- Clone the repository
```bash
git clone https://github.com/moses-mbaga/semo.git
cd semo
```

- Install the dependencies:
```bash
flutter pub get
```

- Under libs/utils folder, create a dart file named **api_keys.dart** and add the following code:
```dart
class APIKeys {
  static const String tmdbAccessTokenAuth = 'Your TMDB access token auth';
  static const String subdl = 'Your SUBDL API Key';
}
```

- Add Firebase to the app using FlutterFire CLI. You can follow insructions from the [official documentation](https://firebase.google.com/docs/flutter/setup)

- Run the app:
```bash
flutter run
```
## Support

If you encounter any issues or have suggestions, please open an issue in the [GitHub Issues](https://github.com/moses-mbaga/semo/issues) section.

Enjoy streaming with Index! 🌟
