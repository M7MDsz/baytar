# Baytar · بيطار

Virtual veterinary consultations for animal owners in Saudi Arabia. Owners create animal profiles, describe a case
(text, voice, photos, video), book a licensed veterinarian and meet them by video. Veterinarians publish their times,
review assigned cases, run the consultation and document the outcome. Administrators verify licenses.

SWE 444 team project, King Saud University.

## Stack

| Part | Choice |
|---|---|
| Mobile app | Flutter (Dart), Arabic-first, right to left |
| Backend | Supabase: PostgreSQL 17 with row level security, Auth, Storage, Realtime, Edge Functions (Deno), pg_cron |
| Video | LiveKit Cloud (token issued by the `consultation-token` function) |
| Push | Firebase Cloud Messaging (sent by the `push-dispatch` function) |
| Email | Supabase Auth email with a 6-digit code, sent through Gmail SMTP |

## Run it

1. Install Flutter (stable) and the Supabase CLI.
2. Start the backend locally: `supabase start` then `supabase db reset` (applies every file in `supabase/migrations`).
3. Copy `env.example.json` to `env.json` and fill in the URL and publishable key printed by `supabase start`.
4. `flutter pub get`
5. `flutter run --dart-define-from-file=env.json`

Edge Function secrets (never commit them): `supabase secrets set LIVEKIT_URL=... LIVEKIT_API_KEY=... LIVEKIT_API_SECRET=... PUSH_WEBHOOK_SECRET=... FIREBASE_SERVICE_ACCOUNT='{...}'`.
Push also needs `android/app/google-services.json` from the Firebase console, and two rows in `app_config`:
`push_url` (the push-dispatch function URL) and `push_secret` (same value as `PUSH_WEBHOOK_SECRET`).

Administrators are not created from the app. Promote an account in SQL:
`update profiles set role = 'admin' where email = '...';`

## Checks

```
flutter analyze
flutter test
```

GitHub Actions runs both on every push and pull request.

## Where each story lives

| Story | App code (`lib/features/`) | Database (`supabase/migrations/`) |
|---|---|---|
| US-01, US-02 Animal profile | `animals/` | `*_us01_us02_animal_profiles.sql` |
| US-03, US-05, US-06 Case, media, drafts | `cases/` | `*_us03_us05_us06_cases.sql` |
| US-04 Voice description | `voice/` | `*_us04_voice_storage.sql` |
| US-07 Submit a case | `cases/case_form_screen.dart`, `case_review/` | `*_us07_submit_case.sql` |
| US-08, US-09, US-10 Find a veterinarian | `vets/` | `*_us08_us09_us10_browse_veterinarians.sql` |
| US-11 Book | `booking/` | `*_us11_book_appointment.sql` |
| US-12, US-13 Reschedule, cancel | `reschedule/`, `booking/appointment_detail_screen.dart` | `*_us12_us13_reschedule_cancel.sql` |
| US-14 Join (owner) | `consultation/` | `*_us14_join_consultation.sql`, `functions/consultation-token` |
| US-16 View outcome | `outcomes/` | `*_us16_view_outcome.sql` |
| US-17, US-18, US-21 Case review, info request, referral | `vet_cases/`, `case_review/` | `*_us17_*.sql`, `*_us18_*.sql`, `*_us21_*.sql` |
| US-19 Conduct consultation (vet) | `vet_consultation/` | `*_us19_conduct_consultation.sql` |
| US-20 Document outcome | `outcome_editor/` | `*_us20_document_outcome.sql` |
| US-29, US-30 Account, sign in | `auth/` | `*_us29_owner_accounts.sql`, `functions/sign-in` |
| US-31, US-32 Vet registration, license check | `vet_registration/`, `admin/` | `*_us31_*.sql`, `*_us32_*.sql` |
| US-33 Time slots | `slots/` | `*_us33_time_slots.sql` |
| US-34 Vet appointments | `vet_appointments/` | `*_us34_vet_upcoming_appointments.sql` |
| US-35 Notifications | `notifications/` | `*_us35_notifications.sql`, `functions/push-dispatch` |

Each feature folder has a `*_feature.dart` file with its routes and tabs; `lib/app/features.dart` lists them all.

## Security model

Every table has row level security on, with no access by default. Each story's migration opens only what that story
needs (for example, a veterinarian can read a case only while holding an appointment for it). Multi-step actions
(booking, reschedule, cancel, submit, approve) run as database functions that check the caller and the rules in one
transaction.
