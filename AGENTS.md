# Repository Guidelines

## Project Structure & Module Organization
This repository is split into two apps:
- `backend/`: Express + TypeScript API. Main source is in `backend/src/` with layered folders: `controllers/`, `routes/`, `services/`, `models/`, `middlewares/`, `validators/`, and `config/`.
- `frontend/`: Flutter client. App code is in `frontend/lib/` with `app/`, shared `core/`, and domain modules under `features/` (`admin`, `doctor`, `patient`, `login`, etc.).

Tests live in `backend/tests/` and `frontend/test/`. Treat `backend/build/` as generated output; make source edits in `backend/src/`.

## Build, Test, and Development Commands
- Backend install: `cd backend && npm ci`
- Backend dev server: `cd backend && npm run dev`
- Backend production build/start: `cd backend && npm run build && npm run start`
- Backend tests: `cd backend && npm test`
- Seed admin user: `cd backend && npm run seed`

- Frontend install deps: `cd frontend && flutter pub get`
- Run app locally: `cd frontend && flutter run`
- Static analysis: `cd frontend && flutter analyze`
- Frontend tests: `cd frontend && flutter test`

## Coding Style & Naming Conventions
For Flutter/Dart, follow `flutter_lints` (`frontend/analysis_options.yaml`): use `snake_case` for files, `PascalCase` for widgets/classes, and `camelCase` for members.

For backend TypeScript, keep names descriptive and layer-based (`auth.controller.ts`, `patient.routes.ts`). Use `PascalCase` for types/classes and `camelCase` for functions/variables. Match the local formatting style in touched files (no repo-wide formatter is configured).

## Testing Guidelines
Backend tests use Jest (`backend/jest.config.ts`) and are named `*.test.ts`. Many tests are integration-style and use Testcontainers with MongoDB, so ensure Docker is running before `npm test`.

Frontend tests use `flutter_test` and should follow `*_test.dart` naming in `frontend/test/`.

No strict coverage gate is configured; add or update tests for every behavior change.

## Commit & Pull Request Guidelines
Recent history favors Conventional Commit prefixes (`feat:`, `fix:`, `refactor:`). Use concise, imperative subjects and scope commits to one logical change.

PRs should include:
- What changed and why
- Affected areas (`backend`, `frontend`, or both)
- Test evidence (commands run and outcomes)
- UI screenshots for Flutter changes and sample request/response notes for API changes

## Security & Configuration Tips
Use `backend/.env.example` as the template for local `.env`. Never commit secrets, tokens, or real credentials. Override default admin credentials outside local development.
