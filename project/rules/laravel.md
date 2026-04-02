# Laravel Project Rules

> Extends global PHP rules (coding-style, patterns, security, testing) with Laravel-specific conventions.

## Architecture

- **Thin controllers**: Controllers handle HTTP concerns only (validation, response). Business logic lives in service classes.
- **Service layer**: One service per domain area (e.g., `BookingService`, `PaymentService`). Inject via constructor, never use facades in services.
- **Form Requests**: All input validation in dedicated FormRequest classes, never in controllers.
- **Resources/Transformers**: API responses use Eloquent API Resources for consistent output shape.
- **Events & Listeners**: Use for side effects (email, notifications, logging). Keep listeners single-responsibility.

## Eloquent

- Always define `$fillable` on models — never use `$guarded = []`.
- Use query scopes for reusable where clauses.
- Eager load relationships to avoid N+1: `->with('relation')` or `$with` on the model.
- Use database transactions for multi-step writes: `DB::transaction(fn () => ...)`.
- Never call `Model::all()` without pagination or limits in production code.

## Routing

- Resource routes preferred: `Route::resource('bookings', BookingController::class)`.
- API routes in `routes/api.php`, web routes in `routes/web.php`.
- Group routes with middleware: `Route::middleware(['auth:sanctum'])->group(...)`.
- Use route model binding for single-resource endpoints.

## Migrations

- One logical change per migration file.
- Always include a `down()` method for reversibility.
- Use `->after('column')` for column ordering consistency.
- Index foreign keys and frequently queried columns.

## Blade & Views

- Use Blade components over `@include` for reusable UI.
- Escape output by default: `{{ $var }}`. Only use `{!! !!}` with sanitized HTML.
- Keep logic out of views — use view composers or computed properties.

## Artisan Commands

- Custom commands in `app/Console/Commands/`.
- Use `$this->info()`, `$this->error()` for output.
- Add `--dry-run` flag for destructive commands.

## Environment

- All config via `.env` — never hardcode credentials or URLs.
- Access config through `config('key')`, not `env('key')` (except in config files).
- Cache config in production: `php artisan config:cache`.
