[English](./README_EN.md) | [中文](./README.md)

# Cunji

Cunji makes time tangible: todos, collection logs, AI reviews, and resume management are treated as traces accumulated day by day.

> This README reflects the codebase as of 2026-06-21. Planned features such as midnight review generation, RAG, life compass, STAR resume writing, and PDF export are tracked in `docs/ROADMAP.md` and `docs/TODO.md`, not described as current functionality.

## Current Modules

| Module | Entry | Current status |
| --- | --- | --- |
| Collection | `/collection` | Items, category metadata, photos, patting logs, calendar, comparison, daily picks, rankings. Valuation code still exists, but valuation is not a long-term retained module. |
| Todo | `/todos` | Tasks, subtasks, soft delete, archive, week/month views, stats, review entry points. |
| AI Review | `/review/daily/*`, `/review/weekly/:id` | Conversational daily reviews, detail pages, weekly reports, offline generator, OpenAI-compatible service. |
| Resume | `/resume` | Three preview templates, long-form editing, visibility toggles, ordering, PNG share export. |
| Settings | `/settings` | AI config, notifications, category management, collection preferences, JSON backup import/export. |

## Global Direction

Current documentation separates implemented facts from future plans. The implementation order is:

1. Fix data debt first: backup import/export, API key storage, valuation removal strategy, and image path handling.
2. Then repair current feature flows: todo tree queries, real patting minutes in reviews, input/STT limits, weekly date-range queries, and resume editing gaps.
3. Then add AI cost gates: `PromptBuilder`, `chat_turns`, 15-turn cutoff, and offline notes.
4. Then build the midnight engine: foreground Catch-Up Guard first, Android WorkManager later.
5. Finally add long-term intelligence: milestones, vectors, life compass, RAG, STAR resume writing, and PDF export.

## Quick Start

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

The current package version is `1.0.2+3`, with Dart SDK constraint `^3.10.0`.

## Database

The current Drift `schemaVersion` is `8`, with 14 tables:

| Table | Purpose |
| --- | --- |
| `user_preferences` | Theme, language, notifications, AI config, review reminders, resume template id, todo categories. |
| `collection_categories` | Collection categories, subtypes, metadata fields, ordering. |
| `todo_lists` | Todo lists. |
| `todos` | Tasks, subtasks, status, tags, soft delete, recurrence rule. |
| `antique_items` | Collection item records. |
| `valuation_records` | Existing valuation records; valuation is not a long-term retained product module. |
| `patting_logs` | Collection patting/check-in logs. |
| `daily_reviews` | Daily reviews. |
| `weekly_reports` | Weekly reports. |
| `resume_profile` | Resume profile. |
| `work_experiences` | Work experiences. |
| `educations` | Education records. |
| `skill_items` | Skills. |
| `project_experiences` | Project experiences. |

## Current Routes

Bottom tabs:

```text
/collection
/todos
/resume
```

Fullscreen routes:

```text
/settings
/review/daily/new
/review/daily/edit/:date
/review/daily/:date
/review/weekly/:id
```

`/review` is registered as an independent review history entry without adding another bottom tab.

## Tech Stack

Flutter, Riverpod, go_router, Drift, Dio, flutter_local_notifications, image_picker, gal, share_plus, speech_to_text, and file_picker.

`fl_chart` is still present for the current valuation chart. `pdf` and `printing` are not current dependencies.

## Documentation

| Document | Contents |
| --- | --- |
| [Current spec](docs/SPEC_PERSONAL_AI_ASSISTANT.md) | Current features, database, AI boundaries, valuation policy. |
| [Architecture](docs/ARCHITECTURE.md) | Project structure, routes, dependencies, database, platforms. |
| [Todo spec](docs/SPEC_TODO.md) | Todo schema, DAO, repository, UI behavior, stats. |
| [Collection spec](docs/SPEC_COLLECTION.md) | Collection schema, pages, logs, categories, valuation removal policy. |
| [Review spec](docs/SPEC_REVIEW.md) | Daily/weekly reviews, AI service, flow, non-implemented boundaries. |
| [Resume spec](docs/SPEC_RESUME.md) | Resume schema, templates, editing, export boundary. |
| [Security](docs/SECURITY.md) | Local data, AI requests, JSON backup risks. |
| [Roadmap](docs/ROADMAP.md) | Planned debt and future features. |
| [TODO](docs/TODO.md) | Open implementation tasks. |

## License

No formal open-source license has been selected. All rights reserved.
