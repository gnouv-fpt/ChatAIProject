# ChatAIWeb

ChatAIWeb is an ASP.NET Core Razor Pages application that provides a RAG chatbot for Vietnamese study materials. The system lets Admins/Teachers upload PDF, DOCX, and PPTX files, split the content into chunks, generate embeddings, retrieve relevant context, and produce answers with source citations.

The project follows a 3-layer architecture for the PRN222/FPT course: `Presentation`, `BusinessLogic`, `DataAccess`, `BusinessObject`.

## Table of Contents

- [Key Features](#key-features)
- [Tech Stack](#tech-stack)
- [Prerequisites](#prerequisites)
- [Quick Setup](#quick-setup)
- [AI/RAG Configuration](#airag-configuration)
- [Running the Application](#running-the-application)
- [Seed Accounts](#seed-accounts)
- [Project Architecture](#project-architecture)
- [Database](#database)
- [Python Services](#python-services)
- [Common Commands](#common-commands)
- [Troubleshooting](#troubleshooting)

## Key Features

- Login/logout by role: `Admin`, `Teacher`, `Student`.
- Manage subjects and users.
- Upload study materials in PDF, DOCX, PPTX formats.
- Extract text from documents, split into chunks, generate embeddings.
- RAG chatbot answers questions based on uploaded documents.
- Display citations by document, page/slide, chunk, and similarity score.
- Detect near-duplicate or conflicting uploaded documents and require the subject head teacher to choose the correct source.
- Store conversation history by user/subject.
- Benchmark chat/RAG with an evaluation question set, run history, model charts, and per-model details.
- Support for multiple embedding models:
  - `bge-m3` via Ollama.
  - `nomic-embed-text` via Ollama.
  - `mxbai-embed-large` via Ollama.
  - `vinai/phobert-base` via the PhoBERT FastAPI service.
- Support for Qdrant as a vector store, with SQL as fallback.
- Run RAGAS evaluations in a background FIFO queue with realtime SignalR progress.
- Show token usage dashboards for users and embedding models.
- Allow only the subject head teacher (`Subject.CreatedBy`) to upload and soft-delete documents.
- Support for a RAGAS Python service to score RAG.

## Tech Stack

| Component | Technology |
| --- | --- |
| Backend web | ASP.NET Core Razor Pages, .NET 8 |
| UI | Razor Pages, Bootstrap, jQuery, SignalR |
| Database | SQL Server, Entity Framework Core |
| Auth | Cookie Authentication |
| LLM | Google Gemini |
| Embedding | Ollama `bge-m3`, `nomic-embed-text`, `mxbai-embed-large`; PhoBERT service |
| Vector search | SQL cosine fallback, Qdrant REST API |
| File parsing | PdfPig, OpenXML |
| Benchmark | RAGAS service, LLM-as-judge fallback |
| Python services | FastAPI, transformers, sentence-transformers, ragas |

## Prerequisites

You need to install:

- .NET SDK 8.0 or later.
- SQL Server or SQL Server Express.
- Visual Studio 2022 or VS Code.
- Ollama for the default 3-model benchmark.
- Python 3.10+ if using PhoBERT/RAGAS/fine-tuning.
- Qdrant if you want to use the Qdrant vector store.

Quick check:

```powershell
dotnet --version
python --version
ollama --version
```

Install Ollama on Windows if it is missing:

```powershell
irm https://ollama.com/install.ps1 | iex
```

## Quick Setup

### 1. Clone or open the source code

```powershell
cd D:\Study_Research\Knowledge\IT\FPT\kì_7\PRN222\Assignments
```

If cloning from Git:

```powershell
git clone <repo-url> ChatAIWeb
cd ChatAIWeb
```

### 2. Restore and build

```powershell
dotnet restore ChatAIWeb.slnx
dotnet build ChatAIWeb.slnx
```

A successful build shows:

```text
Build succeeded.
```

### 3. Create the database

Open SQL Server Management Studio or Azure Data Studio, then run the file:

```text
ChatAIWeb_Database.sql
```

This file creates the `ChatAIWebDb` database, the required tables, and seeds demo data.

When updating an existing database, run `ChatAIWeb_Database.sql` again. The script contains idempotent schema updates, including `DocumentChunkEmbeddings`, RAGAS fields, and `Documents.IsSystemManaged`.

### 4. Check the connection string

Open the file:

```text
Presentation/appsettings.json
```

Default:

```json
"ConnectionStrings": {
  "DefaultConnection": "Server=localhost;Database=ChatAIWebDb;Trusted_Connection=True;TrustServerCertificate=true;Encrypt=false;"
}
```

If your machine hits a SQL Server encryption error, try changing it to:

```json
"DefaultConnection": "Server=localhost;Database=ChatAIWebDb;Trusted_Connection=True;TrustServerCertificate=true;Encrypt=false;"
```

If using SQL Server Express:

```json
"DefaultConnection": "Server=.\\SQLEXPRESS;Database=ChatAIWebDb;Trusted_Connection=True;TrustServerCertificate=true;Encrypt=false;"
```

### 5. Run the application

From the command line:

```powershell
dotnet run --project Presentation\Presentation.csproj --launch-profile https
```

Or open the solution in Visual Studio and click Run.

Default URLs:

- HTTPS: <https://localhost:7108>
- HTTP: <http://localhost:5039>

## AI/RAG Configuration

Configuration lives in:

```text
Presentation/appsettings.json
```

### Gemini LLM

Configuration section:

```json
"Llm": {
  "Provider": "Gemini",
  "Model": "gemini-2.5-flash",
  "Gemini": {
    "BaseUrl": "https://generativelanguage.googleapis.com",
    "Temperature": 0.2,
    "MaxOutputTokens": 1024
  }
}
```

The API key should be stored using User Secrets or an environment variable, not committed to the source code.

Example with User Secrets:

```powershell
cd Presentation
dotnet user-secrets set "Llm:Gemini:ApiKey" "<your-gemini-api-key>"
```

Do not put the real Gemini API key in `appsettings.json`. The committed config stores only the provider/model names; the secret is loaded from User Secrets on each developer machine.

### Ollama embedding models for benchmark

The default benchmark compares these 3 local embedding models:

- `bge-m3`
- `nomic-embed-text`
- `mxbai-embed-large`

Pull all models:

```powershell
ollama pull bge-m3
ollama pull nomic-embed-text
ollama pull mxbai-embed-large
```

Warm up Ollama:

```powershell
Invoke-RestMethod `
  -Uri "http://localhost:11434/api/embed" `
  -Method Post `
  -ContentType "application/json" `
  -Body '{"model":"bge-m3","input":"This is a warm-up test sentence for the embedding.","truncate":true}'
```

Optional warm-up for the other benchmark models:

```powershell
Invoke-RestMethod -Uri "http://localhost:11434/api/embed" -Method Post -ContentType "application/json" -Body '{"model":"nomic-embed-text","input":"warm up","truncate":true}'
Invoke-RestMethod -Uri "http://localhost:11434/api/embed" -Method Post -ContentType "application/json" -Body '{"model":"mxbai-embed-large","input":"warm up","truncate":true}'
```

Check the loaded model:

```powershell
ollama list
```

### Embedding models

Default in `appsettings.json`:

```json
"Embedding": {
  "Provider": "Ollama",
  "DefaultModel": "bge-m3",
  "DefaultModelKey": "bge-m3",
  "Models": [
    {
      "Key": "bge-m3",
      "Provider": "Ollama",
      "Model": "bge-m3",
      "BaseUrl": "http://localhost:11434",
      "Dimension": 1024,
      "Enabled": true,
      "IncludeInBenchmark": true
    },
    {
      "Key": "nomic-embed-text",
      "Provider": "Ollama",
      "Model": "nomic-embed-text",
      "BaseUrl": "http://localhost:11434",
      "Dimension": 768,
      "Enabled": true,
      "IncludeInBenchmark": true
    },
    {
      "Key": "mxbai-embed-large",
      "Provider": "Ollama",
      "Model": "mxbai-embed-large",
      "BaseUrl": "http://localhost:11434",
      "Dimension": 1024,
      "Enabled": true,
      "IncludeInBenchmark": true
    },
    {
      "Key": "phobert-base",
      "Provider": "PhoBert",
      "Model": "vinai/phobert-base",
      "BaseUrl": "http://localhost:8001",
      "Dimension": 768,
      "Enabled": true,
      "IncludeInBenchmark": true
    }
  ]
}
```

`phobert-base` is enabled in the committed configuration. Start the Python service before selecting or benchmarking it. If you do not want to run PhoBERT, set its `Enabled` value to `false`.

### Runtime Admin settings

The Admin page `/SystemSettings` configures the active embedding model, retrieval parameters, and chunking. It does not accept LLM providers or API keys.

Saved settings are stored in:

```text
Presentation/App_Data/system_settings.json
```

Runtime precedence:

1. Valid values in `system_settings.json`.
2. Defaults in `Presentation/appsettings.json`.

If the selected embedding model is missing, disabled, or invalid, the application falls back to `Embedding:DefaultModelKey`. The two System Prompt fields may be empty; the services then use their default behavior.

Chunk modes:

- `Page`: group N PDF pages or PPTX slides; DOCX falls back to word chunking.
- `Word`: split inside each page/slide by word count.
- `Character`: split inside each page/slide by character count.
- Overlap applies only to `Word` and `Character`.
- Changes apply to newly indexed documents and do not re-index old content.

Default values come from `RagSettings`:

```json
"RagSettings": {
  "TopK": 5,
  "SimilarityThreshold": 0.6,
  "MaxCitationSnippetLength": 250,
  "MaxContextChunks": 5,
  "ChunkSizeMode": "Page",
  "PageChunkSize": 1,
  "WordChunkSize": 700,
  "CharacterChunkSize": 3000,
  "ChunkOverlapSize": 100,
  "MinChunkCharacters": 30
}
```
### Qdrant

Configuration:

```json
"VectorStore": {
  "Provider": "Qdrant",
  "DualWrite": true
},
"Qdrant": {
  "Host": "localhost",
  "Port": 6333,
  "UseHttps": false,
  "ApiKey": "",
  "CollectionPrefix": "chataiweb"
}
```

If Qdrant is not running, the application logs a warning and falls back to SQL vector search.

Run Qdrant with Docker:

```powershell
docker run -p 6333:6333 -p 6334:6334 qdrant/qdrant
```

Or switch the provider to SQL:

```json
"VectorStore": {
  "Provider": "Sql",
  "DualWrite": false
}
```

## Running the Application

### With Visual Studio

1. Open `ChatAIWeb.slnx`.
2. Set the startup project to `Presentation`.
3. Select the `https` profile.
4. Click Run.
5. Open <https://localhost:7108>.

### With the terminal

```powershell
dotnet run --project Presentation\Presentation.csproj --launch-profile https
```

If you hit a port-in-use error:

```powershell
netstat -ano | Select-String ':7108|:5039'
```

Stop the process holding the port:

```powershell
Stop-Process -Id <PID> -Force
```

## Seed Accounts

The seed passwords are recorded in `ChatAIWeb_Database.sql`.

| Role | Email | Password |
| --- | --- | --- |
| Admin | `admin@chataiweb.local` | `Admin@123` |
| Teacher demo | `teacher@chataiweb.local` | `Teacher@123` |
| Student demo | `student@chataiweb.local` | `Student@123` |

The seeded database also contains many other teachers and students.

## Project Architecture

```text
ChatAIWeb
|-- BusinessObject
|   |-- Entities
|   `-- Enums
|-- DataAccess
|   |-- ChatAIWebDbContext.cs
|   `-- Repositories
|-- BusinessLogic
|   |-- DTOs
|   |-- Infrastructure
|   `-- Services
|-- Presentation
|   |-- Pages
|   |-- Models
|   |-- wwwroot
|   `-- Program.cs
`-- python_services
    |-- phobert_service.py
    |-- ragas_service.py
    |-- finetune_embedding.py
    `-- requirements.txt
```
### Presentation

Contains the ASP.NET Core Razor Pages UI:

- Razor Pages (`.cshtml` + PageModels).
- ViewModels.
- Cookie authentication.
- Dependency injection in `Program.cs`.
- SignalR hubs for upload, notifications, subject management, and RAGAS progress.
- A shared admin widget that restores background RAGAS job status after navigation.

PageModels should be thin and only call services in `BusinessLogic`.

### BusinessLogic

Contains the business workflows:

- Document upload and indexing.
- Text extraction orchestration.
- Chunking.
- Embedding generation.
- Vector search.
- RAG chatbot.
- Citation mapping.
- Background RAGAS benchmark, run history, metrics, and progress reporting.
- Runtime embedding, retrieval, and chunking settings.

### DataAccess

Contains the EF Core DbContext and repositories:

- Query the database.
- CRUD.
- Include navigation data.
- Store chat, document, chunk, citation, and benchmark results.

### BusinessObject

Contains the shared entities and enums:

- `User`
- `Subject`
- `SubjectEnrollment`
- `Document`
- `DocumentChunk`
- `DocumentChunkEmbedding`
- `ChatSession`
- `ChatMessage`
- `Citation`
- `EvaluationQuestion`
- `RagasBenchmarkResult`

## RAG Pipeline

The flow always runs as:

```text
Upload document
→ Save file
→ Extract text
→ Split into chunks
→ Generate embeddings
→ Save SQL metadata
→ Upsert Qdrant if available
→ Compare against similar indexed documents in the same subject
→ Mark as NeedsReview if conflicts are found
→ Otherwise mark document as Indexed

Student question
→ Generate question embedding
→ Search vector store
→ Filter by similarity threshold
→ Build prompt with retrieved chunks
→ Call LLM
→ Save chat message
→ Save citations
→ Return answer + sources
```

## Database

Main database: `ChatAIWebDb`.

Important tables:

| Table | Purpose |
| --- | --- |
| `Users` | Accounts and roles |
| `Subjects` | Subjects |
| `SubjectEnrollments` | Assign users to subjects |
| `Documents` | Uploaded document metadata |
| `DocumentChunks` | Text chunks from documents |
| `DocumentChunkEmbeddings` | Embeddings per chunk/model |
| `ChatSessions` | Chat sessions |
| `ChatMessages` | Questions/answers |
| `Citations` | Answer source citations |
| `EvaluationQuestions` | Benchmark question set |
| `RagasBenchmarkResults` | Benchmark results |

### Recreate the database from scratch

Be careful: this operation will drop the old database if the script contains `DROP DATABASE`/`DROP TABLE`.

1. Open `ChatAIWeb_Database.sql`.
2. Run it with SSMS/Azure Data Studio.
3. Verify the `ChatAIWebDb` database.
4. Run the app.

### Existing database

Run `ChatAIWeb_Database.sql` again after pulling schema changes. The current script is the canonical schema and seed source; there is no separate Phase 2 migration file.

## Python Services

The Python services are optional, but needed if you want to use PhoBERT/RAGAS/fine-tuning.

### Install dependencies

```powershell
cd python_services
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

### Run the PhoBERT service

```powershell
python phobert_service.py
```

Default:

- Health: <http://localhost:8001/health>
- Embed: `POST http://localhost:8001/embed`

Test:

```powershell
Invoke-RestMethod `
  -Uri "http://localhost:8001/embed" `
  -Method Post `
  -ContentType "application/json" `
  -Body '{"model":"vinai/phobert-base","texts":["Hello, this is a test sentence."]}'
```

### Run the RAGAS service

Requires a Gemini API key:

```powershell
$env:GOOGLE_API_KEY="<your-gemini-api-key>"
python ragas_service.py
```

Default:

- Health: <http://localhost:8002/health>
- Evaluate: `POST http://localhost:8002/evaluate`

If the RAGAS service is not running, the .NET service falls back to LLM-as-judge.

### Fine-tune the embedding

Export the dataset from SQL:

```powershell
python finetune_embedding.py `
  --connection-string "Driver={ODBC Driver 17 for SQL Server};Server=localhost;Database=ChatAIWebDb;Trusted_Connection=yes;TrustServerCertificate=yes;" `
  --subject-id 1 `
  --dataset artifacts/embedding_train.jsonl `
  --export-only
```

Train the model:

```powershell
python finetune_embedding.py `
  --dataset artifacts/embedding_train.jsonl `
  --base-model vinai/phobert-base `
  --output-dir models/phobert-finetuned `
  --epochs 1 `
  --batch-size 8
```

After you have the fine-tuned model, enable it in `appsettings.json`:

```json
{
  "Key": "phobert-finetuned",
  "Provider": "PhoBert",
  "Model": "models/phobert-finetuned",
  "Enabled": true
}
```

## Common Commands

| Command | Description |
| --- | --- |
| `dotnet restore ChatAIWeb.slnx` | Restore NuGet packages |
| `dotnet build ChatAIWeb.slnx` | Build the entire solution |
| `dotnet run --project Presentation\Presentation.csproj --launch-profile https` | Run the web app |
| `ollama pull bge-m3` | Download the embedding model |
| `ollama pull nomic-embed-text` | Download benchmark embedding model |
| `ollama pull mxbai-embed-large` | Download benchmark embedding model |
| `ollama ps` | Check loaded Ollama models |
| `python python_services\phobert_service.py` | Run the PhoBERT embedding service |
| `python python_services\ragas_service.py` | Run the RAGAS service |

## Troubleshooting

### 1. `Failed to bind to address ... address already in use`

Port `7108` or `5039` is held by another process.

Check:

```powershell
netstat -ano | Select-String ':7108|:5039'
```

Stop the process:

```powershell
Stop-Process -Id <PID> -Force
```

### 2. SQL Server encryption error

Common error:

```text
The instance of SQL Server you attempted to connect to requires encryption but this machine does not support it.
```

Try changing the connection string:

```json
"Encrypt=false;TrustServerCertificate=true;"
```

### 3. RAGAS page reports an invalid or missing column

Run the latest `ChatAIWeb_Database.sql` against `ChatAIWebDb`, then restart the application.

### 4. Ollama timeout when backfilling embeddings

The log looks like:

```text
Unable to backfill embedding ... TaskCanceledException
```

Common causes:

- Ollama is not running.
- The `bge-m3` model has not been pulled.
- The model is loading for the first time and is slow.
- The chunk is too long, or the machine lacks RAM/CPU/GPU.

Fix:

```powershell
ollama pull bge-m3
ollama ps
```

Warm up:

```powershell
Invoke-RestMethod `
  -Uri "http://localhost:11434/api/embed" `
  -Method Post `
  -ContentType "application/json" `
  -Body '{"model":"bge-m3","input":"This is a warm-up test sentence for the embedding.","truncate":true}'
```

### 5. Qdrant is not running

If Qdrant is not running, the app falls back to SQL search. If you want to disable Qdrant:

```json
"VectorStore": {
  "Provider": "Sql",
  "DualWrite": false
}
```

### 6. Upload page shows only some subjects

The upload page gets the subject list according to the rule in `DocumentService.GetUploadSubjectOptionsAsync`.

In the current version:

- Only teachers who are the head teacher/creator of a subject can upload documents for that subject.
- Admins do not upload documents through the upload page.
- Students cannot upload.

This matches the project rule that only the subject head teacher uploads learning materials. If a teacher does not see a subject, check whether that teacher is the subject creator/head teacher in the seeded data.

### 7. Uploaded document is marked as NeedsReview

After indexing, the app compares the new document chunks with similar indexed documents in the same subject. If it finds likely content conflicts, the document is held out of RAG and marked `NeedsReview`.

The subject head teacher should open the conflict report, review the chunk-level differences, then choose one of these actions:

- Select the new document as correct.
- Keep the existing document.
- Confirm there is no conflict.

### 8. Build is locked by a DLL file

If the build reports:

```text
The file is locked by: Microsoft Visual Studio, Presentation
```

Stop the app running in Visual Studio, then build again.

## Security Notes

- Do not commit the Gemini API key, Qdrant API key, database password, or other credentials.
- OpenAI is not used by the current runtime.
- Store secrets with User Secrets in development.
- Use environment variables or a secret manager in production.

## Suggested Demo Flow

1. Log in as Admin or Teacher.
2. Go to `Document Library`.
3. Select `Add new document`.
4. Upload a PDF/DOCX/PPTX into a subject.
5. Wait for the extract/chunk/embed/index process to finish.
6. Go to the chat for that subject.
7. Ask a question related to the document you just uploaded.
8. Check the answer and citations.
9. Go to the RAGAS benchmark page to evaluate multiple embedding models.

## License

This project serves learning and course-demo purposes. Update the license if you need to make it public or deploy to production.
