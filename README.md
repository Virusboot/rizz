# Rizz

A dating app for adults (18+) built with Flutter and Firebase.
People pick what they are looking for (Dating, Casual or Open to both) and only see others whose choice fits.

## What works

- Email and password sign up, sign in, password reset, email verification
- 18+ gate: self-declared date of birth, under-18 sign up is stopped in the app,
  and the database rules refuse a stored age below 18 or an age that goes down
- Onboarding: basics, what you are looking for and city, photos (min 2), prompts (min 2)
- Discover: filtered by interested-in, age range, looking-for, same city, blocks, passes
- Filters on the Discover screen: Dating, Casual, Verified, Active today, New here
- Like, pass, undo pass, Spark (1 free per week), Boost (1 free per day)
- Likes You: see who liked you, like back to match
- Matches and real-time text chat, unmatch
- Report, block, unblock, block list, safety tips, helplines (India)
- Selfie verification request (manual review), pause profile
- Edit profile, dating preferences, delete account (removes all data)
- Push notifications (Android): new match, new message, new like or Spark.
  A like never shows who it is from. Can be turned off in Profile > My Rizz.
- Firestore and Storage security rules, indexes

Everything is free for now. Paid features can be added later (Google Play Billing).

## Setup (about 20 minutes)

You need: Flutter SDK, Node.js, a Google account.

1. Install tools

   ```
   npm install -g firebase-tools
   dart pub global activate flutterfire_cli
   firebase login
   ```

2. Create the Flutter project, then copy these files into it

   ```
   flutter create --org com.kvstudio --project-name rizz --platforms android rizz
   ```

   Copy from this folder into `rizz/`, replacing what is there:
   `lib/` (whole folder), `test/` (whole folder), `pubspec.yaml`, `firestore.rules`,
   `storage.rules`, `firestore.indexes.json`, `firebase.json`, and the `functions/` folder.

3. Create a Firebase project at https://console.firebase.google.com and turn on:
   - Authentication > Sign-in method > Email/Password
   - Firestore Database (production mode). For the location pick **asia-south1 (Mumbai)**.
     It cannot be changed later, and `functions/index.js` uses the same location.
     If you pick another location, change `region` at the top of `functions/index.js`.
   - Storage (needs the Blaze pay-as-you-go plan; the free quota is generous.
     Set a budget alert so you never get a surprise bill.)

4. Connect the app to Firebase (this replaces `lib/firebase_options.dart`)

   ```
   cd rizz
   flutter pub get
   flutterfire configure
   ```

5. Android settings
   - Open `android/app/build.gradle` (or `build.gradle.kts`) and set `minSdk` to 23 or higher.
   - For notifications on Android 13 and newer, open `android/app/src/main/AndroidManifest.xml`
     and add this line just above the `<application` tag:

     ```
     <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
     ```

6. Deploy the rules, indexes and notification functions. Do not skip this: without the rules and
   indexes the app shows errors, and without the functions no notifications are sent.
   The indexes take a few minutes to build the first time. Functions need the Blaze plan.

   ```
   cd functions && npm install && cd ..
   firebase deploy --only firestore:rules,firestore:indexes,storage,functions
   ```

7. Run

   ```
   flutter analyze
   flutter test
   flutter run
   ```

   This code was written and reviewed without a Flutter compiler. If `flutter analyze`
   shows an error, send it to me and I will fix it.

## Running the team side (you)

- **Approve a selfie:** open Storage at `verifications/<uid>/selfie.jpg` and compare it with the
  user's photos. If it matches, open Firestore > `users` > that user and set `verified` to `true`
  and `verifyPending` to `false`. Users cannot set `verified` themselves.
- **Reports:** Firestore > `reports`. Each report has the reason and, for chat reports,
  the last 10 messages. To remove a bad account, disable the user in Authentication.
- **Test with two accounts** (two phones or emulators). Sign up both, finish onboarding with
  compatible choices (interested-in matches the other's gender, same looking-for or Open to both),
  then like each other.

## Good to know

- Blocked people cannot find out who blocked them. If they try to like the person who blocked them,
  the like is quietly dropped and the profile disappears from their feed.
- Non-binary people are shown to people who chose "Everyone" as who they want to meet.
- If Discover shows an error with a link about an index, the indexes in step 6 are not deployed yet.
  Open the link or run the deploy command again.

## Before you publish on Google Play

- Write a Privacy Policy and Terms, host them on a web page, add the links in the Play Console
  and in the sign up screen text.
- Fill the Data safety form (email, photos, birth date, chat messages are collected).
- Set the content rating for a dating app and make it 18+.
- Account deletion is in the app (Profile > My Rizz > Delete account). Play also asks for a web page
  where users can request deletion. Add one.
- Report and block are built in, but someone must actually read the reports and act on them.

## Known limits

- Age is self-declared. Real age checks need an ID check service.
- Discover reads people newest first, up to 1,500 profiles per refresh, and filters them on the phone.
  Fine for the first few thousand users. After that, move matching to Cloud Functions.
- Photos are not scanned automatically. Add an image moderation service before you grow.
- Selfie verification is manual, not automatic face matching.
- The weekly Spark and daily Boost limits are checked in the app, not on the server.
  Fine while they are free. Move them to Cloud Functions before you charge for them.
- Notifications are Android only. Message text shows on the lock screen. If a notification does not
  arrive, check the function logs in the Firebase console (Functions > Logs).
- Email and password only. Phone OTP and Google sign-in can be added later.
- No distance filter, because the app does not use location. It uses city instead.
