# Khánh — custom exam contract draft (H01–H04, 28/10/2026)

This branch adds the domain service, Redis store and unit tests for custom exams. It does not alter shared entities, DbContexts, migrations, host registration or the solution file.

## Implemented behavior

- `IExamQuestionSource.GetQuestionsAsync` obtains a candidate pool from the Content/Exam service. The service rejects malformed questions, selects unique IDs randomly and snapshots the question/version/options/correct key. IDs are opaque strings until P0 mapping is published.
- Redis key `custom-exam:v1:{ExamId:N}` stores the owner, stable AttemptId, snapshot, answers, deadline, status and revision. TTL is exam duration plus seven days. Redis compare-and-swap updates preserve TTL. No correct key appears in `CustomExamView`.
- Autosave checks owner, question/option IDs, deadline, status and revision. Clients must send the latest revision and reload on conflict. Reload never changes deadline.
- Submit freezes answers with an atomic Redis transition, grades the snapshot in code, then calls `IExamResultSink.SaveAsync`. The sink must enforce a unique AttemptId and accept an identical retry. Success is returned only after that durable save. `Submitting` is retryable after a process crash. Result/history reads after Redis expiry belong to User service.

## P0 integration decisions required

1. **Phúc:** Content API route/auth and bank version format; return server-only correct option IDs to the trusted exam service. Confirm handling for questions whose wording refers to option letters after shuffle.
2. **Bảo/Vương:** User save-result route/auth, snapshot JSON format, unique AttemptId constraint and duplicate-payload behavior. Confirm that a retry of an already committed AttemptId returns success.
3. **Vương:** Register adapters and Redis connection in the relevant host after service boundaries/Gateway are fixed. Redis connection failure must surface as failure, never simulated success. No schema change is included here.
4. **Team:** Confirm seven-day post-deadline Redis retention, maximum 100 questions/180 minutes, and recovery policy if Redis is evicted before submission. The current implementation returns not found for an evicted unfinished exam.

## Remaining H tasks

- HTTP adapters/controllers and exam UI need the P0 Content/User API and host contracts. Timer expiry currently blocks further autosave; submission can still be triggered by client or a future Worker handler. Offline automatic submission needs a durable scheduling decision because Redis TTL alone does not trigger reliable work.
- H05 Kafka notification event types/consumers need the service owners to identify actual notifications. The old Redis event publisher is outside this change and is not evidence of Kafka delivery.
- Integration tests against Redis, Content/User services and Gateway remain to be run after those services exist.
