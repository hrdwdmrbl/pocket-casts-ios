# Podcasta for iOS

This personal fork of Pocket Casts opens directly into the app. It has no account, cloud sync, purchases, paid features, onboarding, promotions, analytics, or remote experiments.

Podcast playback, downloads, local files, playlists, listening history, RSS chapters and transcripts, and transcript App Intents remain available. Smart playlists can include archived episodes. The Apple Watch app controls playback on the phone.

## Setup

If you don't already have it, you need to install Bundler:

`gem install bundler`

Next you'll need to install all the dependencies needed for [_fastlane_](https://docs.fastlane.tools/) using this script:

`make install_dependencies`

### Secrets

Internal contributors need to install and set up [`a8c-secrets`](https://github.com/Automattic/a8c-secrets), then decrypt the project secrets before building:

`a8c-secrets decrypt`

Re-run it whenever the secrets are rotated; the build does not decrypt them for you.

External contributors don't need the secrets; see [below](#external-contributors).

## External contributors

If you're an external contributor run `make external_contributor`. After that you should be able to build and run the project.

## Swift Formatting

We use [SwiftLint](https://github.com/realm/SwiftLint) to ensure code is spaced and formatted the same way and follows the same [general conventions](https://github.com/Automattic/swiftlint-config). We have a script that will run it over the whole project.

Run:

`make format`

You should do this before making a pull request.

## Running

Open the `.xcodeproj` file, select the `pocketcasts` scheme and the Simulator Device you want to run on, and hit the play button.

### Transcript App Intents

In Shortcuts, select Pocket Casts and add **Search Transcripts** or **Get Transcript**. Search accepts text and an optional podcast or episode. It returns matching passages with an episode reference, speaker, and start/end times when the transcript provides them. Pass a result's episode to Get Transcript to receive the full transcript as a text file.

The app indexes available transcripts from subscribed podcasts while it is open, including archived episodes. Search reports when indexing is incomplete. Selecting an episode downloads its transcript on demand; saved transcripts remain available offline. These actions use the same transcript metadata and formats as the app's transcript view.

## Localization

You can learn more about localization at [docs/Localization.md](./docs/localization.md)

## Debugging

Use Xcode's console and debugger when running the app. The upstream support, diagnostics-export, and analytics screens have been removed.

## Upstream

This project is based on [Pocket Casts for iOS](https://github.com/Automattic/pocket-casts-ios) and retains its [Mozilla Public License](LICENSE.md).
