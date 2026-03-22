# App Store Review — notes for Smeet (paste into App Review Information)

**Last updated:** Use the repo date when submitting.

## What Smeet is

Smeet is a **social sports matchmaking** app: users browse and create local sports games, discover people to play with (swipe/match), chat in-app, and manage a sports-focused profile. Backend is **Supabase** (auth, data, storage).

---

## Core reviewer flows

| Flow | Where | What to try |
|------|--------|-------------|
| **Browse games** | Home tab | Scroll “Upcoming Games”, adjust country/city/radius if needed. |
| **Create game** | Home | Fill sport, level, date/time, **search and pick a venue** from suggestions, set players/fee, Create Game. |
| **Join game** | Home | Tap **Join** on a listed game (sign in if prompted). |
| **Swipe / match** | Swipe tab | Browse profiles; **Like/Pass** requires sign-in. Guests can browse only (see Guest mode). |
| **My games** | My Game tab | Lists games you’ve joined; open group chat when available; leave game. |
| **Chat** | Chat tab | Lists conversations; open a thread, send messages. |
| **Profile** | Profile tab | Edit display name, city, sports, availability; optional **avatar** and **posts** (photo/video from library). |

---

## Safety & moderation (in-app)

- **Report user** — Available from relevant user/profile surfaces (e.g. other user profile / report flows).
- **Report message** — Available in chat contexts where implemented.
- **Block user** — Block/unblock flows; blocked users are filtered where the app applies block lists.
- **Account deletion** — In-app **delete account / data request** flow (see app UI and `docs/ACCOUNT_DELETION.md` if needed).

Legal documents are linked from the app (e.g. **Terms of Use**, **Privacy Policy** on Profile for guests and signed-in users).

---

## Guest mode

- Users can open the app **without signing in** and browse parts of the experience (e.g. Home, Swipe browse, Profile teaser).
- **Creating games, joining, liking/passing, chat, and full profile editing** require **sign in / sign up** (Auth screen).

---

## Sign-in for review

Use a **real test account** you control (recommended):

| Field | Value |
|--------|--------|
| **Test account email** | *(add before submission)* |
| **Test account password** | *(add before submission)* |

If you use **Sign in with Apple** or email magic link, note that in the “Notes” field so reviewers know how to log in.

---

## Location & photos (transparency)

- **Venue / game location** is chosen via **address search** (suggestions), not continuous device GPS. Users pick a place; coordinates come from the selected result.
- **Photos/videos** for avatar and posts are chosen from the **system photo library** (`image_picker`, gallery). The app does **not** currently use the device camera or microphone in code paths shipped for picking media (gallery-only).

---

## Optional reviewer tips

- If **no games** appear, create one from Home or widen radius/city on Home filters.
- If **Swipe** shows no cards, complete Profile sports/levels or refresh; empty state explains next steps.
- **Chat** may be empty until there is a match or game chat.

---

*Keep this file updated when flows or test accounts change.*
