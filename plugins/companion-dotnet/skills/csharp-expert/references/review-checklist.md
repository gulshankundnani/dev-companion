# C# review checklist

## Correctness
- [ ] Null handling matches nullable annotations; no hidden `!`
- [ ] Equality/hash consistent for types used as keys
- [ ] DateTime: `DateTimeOffset`/UTC for persistence; `TimeProvider`/clock injected for testability
- [ ] Culture: `CultureInfo.InvariantCulture` for parsing/formatting machine data; `StringComparison` specified
- [ ] Decimal (not double) for money

## Async & threading
- [ ] No sync-over-async, no `async void`, `CancellationToken` flows through
- [ ] No shared mutable state without synchronization; `ConcurrentDictionary` / locks where needed
- [ ] `Task.WhenAll` for independent I/O; no fire-and-forget without error handling

## DI & lifetime
- [ ] No captive dependencies (scoped/transient inside singleton)
- [ ] `DbContext` scoped, never shared across threads
- [ ] `HttpClient` via factory / typed client

## Data
- [ ] No N+1; reads `AsNoTracking`; projections instead of full entities for read models
- [ ] Transactions around multi-step writes; concurrency token where races matter
- [ ] Parameterised SQL everywhere

## API
- [ ] Correct status codes; `ProblemDetails` for errors; validation on input DTOs
- [ ] No entity types leaked over the wire; versioning respected
- [ ] `[Authorize]`/policies applied; no over-posting

## Maintainability
- [ ] Follows `.editorconfig` / analyzers; no new warnings
- [ ] Methods small and single-purpose; no duplicated logic (check reuse catalog)
- [ ] Public members documented (`///`) if a library
- [ ] Tests cover new behaviour
