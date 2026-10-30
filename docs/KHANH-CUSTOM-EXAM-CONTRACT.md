# Khánh — H01–H06 implementation and integration contract (28/10/2026)

This branch is local only. It adds the custom-exam module, exam page, Kafka producer and notification Worker. It does not change shared entities, DbContexts or migrations.

## Implemented

| Task | Code |
| --- | --- |
| H01 | `ContentQuestionClient` selects a candidate pool through the Content service HTTP contract. `CustomExamService` validates version/options, removes duplicate question IDs and randomly selects N. IDs are opaque strings until P0 mapping. |
| H02 | Redis key `custom-exam:v1:{ExamId:N}` holds user ownership, stable AttemptId, full server-only snapshot/keys, answers, deadline, revision and status. TTL = duration + 7 days; compare-and-swap preserves TTL. |
| H03 | API and page `/exams/` support create, resume, autosave, server deadline, client countdown/auto-submit, freeze, code-based scoring and retry. A Redis due index lets `CustomExamDeadlineWorker` submit expired exams even when the page is closed, and retry after Worker restart. Option shuffle is allowed only when Content marks `CanShuffleOptions=true`; otherwise order is preserved for questions referring to A/B/C/D. |
| H04 | `UserExamResultClient` posts a full graded snapshot to the User service. Success is returned only after that service confirms the save and Kafka confirms publish. Stable AttemptId is used on retries. |
| H05 | `KafkaExamEventPublisher` publishes an envelope with EventId=AttemptId, SchemaVersion, EntityId/Version, OccurredAtUtc, TraceParent, UserId and score. `WorkerService` consumes manually, retries three times, writes a per-user Redis notification inbox atomically and sends failed messages to DLQ before committing the source offset. The inbox API is owner-scoped. |
| H06 | Self-contained exam page plus unit tests for owner isolation, no answer-key leakage, stale/concurrent autosave, deadline, durable-save retry, broker retry and Worker restart recovery. |

## HTTP contracts to align at P0

Configuration keys are `Exams:ContentBaseUrl`, `Exams:ContentQuestionsPath`, `Exams:UserBaseUrl`, `Exams:SaveResultPath`, optional `Exams:InternalApiKey`, and `ConnectionStrings:Redis`. No secrets are committed.

Content endpoint: `GET {ContentQuestionsPath}?categoryId=...&bankVersion=...&count=N` returns a JSON array of `BankQuestion` (`Id`, `Version`, `Text`, `Options[{Id,Text}]`, `CorrectOptionId`, `CanShuffleOptions`). This endpoint must be trusted server-to-server because it returns keys. Phúc must confirm route, version and category mapping, and the option-shuffle safety flag. If fewer than N unique valid questions are returned, create fails clearly.

User endpoint: `POST {SaveResultPath}` accepts `SaveExamResult` (`AttemptId`, `ExamId`, `UserId`, `BankVersion`, `SubmittedAtUtc`, `Correct`, `Total`, `Questions[{QuestionId,Version,Text,Options,CorrectOptionId,SelectedOptionId}]`). Bảo/Vương must provide a unique AttemptId constraint, accept an identical retry as success, reject a conflicting payload, and retain the snapshot/history after Redis expiry. This module does not implement their SQL table or migration.

The caller includes optional `X-Internal-Api-Key`; deployment must restrict the internal endpoints and define stronger service authentication if needed. Gateway must route `/api/custom-exams`, `/api/exam-notifications` and `/exams/` to the host. API endpoints require JWT and check ownership.

## Kafka/Worker contract

- Topic: `exam-submitted-events`; key: UserId; group: `exam-notification-worker-v1`; DLQ: `exam-submitted-events-dlq`. The supplied Compose overlay provisions both topics in a single-broker local setup.
- Broker producer requests all replicas and checks `PersistenceStatus.Persisted`. A failed publish leaves Redis status `Submitting`; retry uses the same frozen answers, AttemptId and EventId. A `Submitted` retry returns the stored score without another publish.
- Worker commits the source offset only after the inbox write or DLQ broker ack. Redis transaction checks the per-event key before adding to the inbox. A replay with the same EventId is ignored while the 30-day dedup key exists. Notification inbox is ephemeral; `GET /api/exam-notifications` returns the latest 50 for the authenticated user.
- Logs distinguish processed, duplicate, retry, DLQ and commit failure. Kafka is at-least-once; this is not an exactly-once claim.

## Run and verification

`dotnet test BusinessLogic.Tests/BusinessLogic.Tests.csproj` checks business behavior. `dotnet build ChatAIWeb.slnx` builds API and Worker. `docker compose -f docker-compose.yml -f docker-compose.exams.yml config --quiet` validates the overlay. The API serves `/exams/` with `Database:MigrateOnStartup=false` for a static-page smoke test.

The Docker daemon was unavailable during this work, so Redis/Kafka delivery and the full Content → exam → User DB path have **not** been exercised against live services. Configure the Content/User API endpoints after their P0 contracts exist, then run that integration path before merging.

## Recovery limits requiring team decision

- If Redis is evicted before a frozen result is saved, the unfinished exam cannot be recovered. Completed history comes from User DB. Seven-day post-deadline retention and 30-day inbox retention are proposed defaults. The Worker deadline index is also in Redis and shares this eviction risk.
- A crash after User DB commit and before Kafka ack can be repaired by retry while the Redis snapshot exists. Guaranteeing delivery beyond Redis expiry requires a User DB outbox owned by Vương/Bảo. This module does not invent that schema.
- The Worker scans the Redis due index every five seconds and catches up after restart. A failed submission is postponed 30 seconds so one failing exam does not block the next 100. It can only finish while Redis still contains the exam snapshot and the User result service/Kafka are reachable.
