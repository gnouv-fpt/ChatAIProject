/* =========================================================
   ChatAIWeb Database Script
   Project: ASP.NET Razor + 3 Layers + RAG Chatbot
   Database: SQL Server
   Author: Generated for ChatAIWeb solution
   ========================================================= */

IF DB_ID(N'ChatAIWebDb') IS NULL
BEGIN
    CREATE DATABASE ChatAIWebDb;
END
GO

USE ChatAIWebDb;
GO

/* =========================================================
   Drop tables if needed - keep safe order by FK dependency
   Uncomment this block if you want to recreate database objects.
   ========================================================= */
/*
DROP TABLE IF EXISTS dbo.RagasBenchmarkResults;
DROP TABLE IF EXISTS dbo.EvaluationQuestions;
DROP TABLE IF EXISTS dbo.Citations;
DROP TABLE IF EXISTS dbo.ChatMessages;
DROP TABLE IF EXISTS dbo.ChatSessions;
DROP TABLE IF EXISTS dbo.Notifications;
DROP TABLE IF EXISTS dbo.DocumentConflictFindings;
DROP TABLE IF EXISTS dbo.DocumentConflictCandidates;
DROP TABLE IF EXISTS dbo.DocumentConflictReviews;
DROP TABLE IF EXISTS dbo.DocumentChunkEmbeddings;
DROP TABLE IF EXISTS dbo.DocumentChunks;
DROP TABLE IF EXISTS dbo.Documents;
DROP TABLE IF EXISTS dbo.SubjectEnrollments;
DROP TABLE IF EXISTS dbo.Subjects;
DROP TABLE IF EXISTS dbo.Users;
*/
GO

/* =========================================================
   1. Users
   Roles: Admin / Teacher / Student
   ========================================================= */
IF OBJECT_ID(N'dbo.Users', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Users
    (
        Id              INT IDENTITY(1,1) PRIMARY KEY,
        FullName        NVARCHAR(150) NOT NULL,
        Email           NVARCHAR(256) NOT NULL,
        PasswordHash    NVARCHAR(500) NOT NULL,
        Role            NVARCHAR(30)  NOT NULL,
        IsActive        BIT NOT NULL CONSTRAINT DF_Users_IsActive DEFAULT 1,
        CreatedAt       DATETIME2(0) NOT NULL CONSTRAINT DF_Users_CreatedAt DEFAULT SYSUTCDATETIME(),
        UpdatedAt       DATETIME2(0) NULL,

        CONSTRAINT UQ_Users_Email UNIQUE (Email),
        CONSTRAINT CK_Users_Role CHECK (Role IN (N'Admin', N'Teacher', N'Student'))
    );
END
GO

/* =========================================================
   2. Subjects
   Stores courses/subjects whose learning materials are indexed.
   ========================================================= */
IF OBJECT_ID(N'dbo.Subjects', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Subjects
    (
        Id              INT IDENTITY(1,1) PRIMARY KEY,
        SubjectCode     NVARCHAR(50) NOT NULL,
        SubjectName     NVARCHAR(200) NOT NULL,
        Description     NVARCHAR(MAX) NULL,
        CreatedBy       INT NULL,
        IsDeleted       BIT NOT NULL CONSTRAINT DF_Subjects_IsDeleted DEFAULT 0,
        DeletedAt       DATETIME2(0) NULL,
        DeletedBy       INT NULL,
        DeleteReason    NVARCHAR(500) NULL,
        CreatedAt       DATETIME2(0) NOT NULL CONSTRAINT DF_Subjects_CreatedAt DEFAULT SYSUTCDATETIME(),
        UpdatedAt       DATETIME2(0) NULL,

        CONSTRAINT UQ_Subjects_SubjectCode UNIQUE (SubjectCode),
        CONSTRAINT FK_Subjects_Users_CreatedBy FOREIGN KEY (CreatedBy) REFERENCES dbo.Users(Id),
        CONSTRAINT FK_Subjects_DeletedBy FOREIGN KEY (DeletedBy) REFERENCES dbo.Users(Id)
    );
END
GO

IF OBJECT_ID(N'dbo.Subjects', N'U') IS NOT NULL
    AND COL_LENGTH(N'dbo.Subjects', N'IsDeleted') IS NULL
BEGIN
    ALTER TABLE dbo.Subjects
    ADD IsDeleted BIT NOT NULL CONSTRAINT DF_Subjects_IsDeleted DEFAULT 0;
END
GO

IF OBJECT_ID(N'dbo.Subjects', N'U') IS NOT NULL
    AND COL_LENGTH(N'dbo.Subjects', N'DeletedAt') IS NULL
BEGIN
    ALTER TABLE dbo.Subjects ADD DeletedAt DATETIME2(0) NULL;
END
GO

IF OBJECT_ID(N'dbo.Subjects', N'U') IS NOT NULL
    AND COL_LENGTH(N'dbo.Subjects', N'DeletedBy') IS NULL
BEGIN
    ALTER TABLE dbo.Subjects ADD DeletedBy INT NULL;
END
GO

IF OBJECT_ID(N'dbo.Subjects', N'U') IS NOT NULL
    AND COL_LENGTH(N'dbo.Subjects', N'DeleteReason') IS NULL
BEGIN
    ALTER TABLE dbo.Subjects ADD DeleteReason NVARCHAR(500) NULL;
END
GO

IF OBJECT_ID(N'dbo.FK_Subjects_DeletedBy', N'F') IS NULL
    AND OBJECT_ID(N'dbo.Subjects', N'U') IS NOT NULL
BEGIN
    ALTER TABLE dbo.Subjects
    ADD CONSTRAINT FK_Subjects_DeletedBy FOREIGN KEY (DeletedBy) REFERENCES dbo.Users(Id);
END
GO

/* =========================================================
   3. SubjectEnrollments
   Optional: maps students/teachers to subjects.
   ========================================================= */
IF OBJECT_ID(N'dbo.SubjectEnrollments', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.SubjectEnrollments
    (
        Id          INT IDENTITY(1,1) PRIMARY KEY,
        SubjectId   INT NOT NULL,
        UserId      INT NOT NULL,
        RoleInClass NVARCHAR(30) NOT NULL,
        CreatedAt   DATETIME2(0) NOT NULL CONSTRAINT DF_SubjectEnrollments_CreatedAt DEFAULT SYSUTCDATETIME(),

        CONSTRAINT FK_SubjectEnrollments_Subjects FOREIGN KEY (SubjectId) REFERENCES dbo.Subjects(Id),
        CONSTRAINT FK_SubjectEnrollments_Users FOREIGN KEY (UserId) REFERENCES dbo.Users(Id),
        CONSTRAINT UQ_SubjectEnrollments_Subject_User UNIQUE (SubjectId, UserId),
        CONSTRAINT CK_SubjectEnrollments_RoleInClass CHECK (RoleInClass IN (N'Teacher', N'Student'))
    );
END
GO

/* =========================================================
   4. Documents
   Stores uploaded PDF/DOCX/PPTX files and indexing status.
   ========================================================= */
IF OBJECT_ID(N'dbo.Documents', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Documents
    (
        Id              INT IDENTITY(1,1) PRIMARY KEY,
        SubjectId       INT NOT NULL,
        Title           NVARCHAR(255) NOT NULL,
        OriginalFileName NVARCHAR(255) NOT NULL,
        StoredFileName  NVARCHAR(255) NOT NULL,
        FilePath        NVARCHAR(1000) NOT NULL,
        FileType        NVARCHAR(20) NOT NULL,
        FileSizeBytes   BIGINT NULL,
        UploadedBy      INT NULL,
        Status          NVARCHAR(30) NOT NULL CONSTRAINT DF_Documents_Status DEFAULT N'Uploaded',
        ErrorMessage    NVARCHAR(MAX) NULL,
        UploadedAt      DATETIME2(0) NOT NULL CONSTRAINT DF_Documents_UploadedAt DEFAULT SYSUTCDATETIME(),
        IndexedAt       DATETIME2(0) NULL,
        IsSystemManaged BIT NOT NULL CONSTRAINT DF_Documents_IsSystemManaged DEFAULT 0,

        CONSTRAINT FK_Documents_Subjects FOREIGN KEY (SubjectId) REFERENCES dbo.Subjects(Id),
        CONSTRAINT FK_Documents_Users_UploadedBy FOREIGN KEY (UploadedBy) REFERENCES dbo.Users(Id),
        CONSTRAINT CK_Documents_FileType CHECK (FileType IN (N'PDF', N'DOCX', N'PPTX', N'TXT')),
        CONSTRAINT CK_Documents_Status CHECK (Status IN (N'Uploaded', N'Processing', N'Indexed', N'Failed', N'Rejected', N'NeedsReview', N'Deleted'))
    );
END
GO

IF COL_LENGTH(N'dbo.Documents', N'IsSystemManaged') IS NULL
BEGIN
    ALTER TABLE dbo.Documents
        ADD IsSystemManaged BIT NOT NULL
            CONSTRAINT DF_Documents_IsSystemManaged DEFAULT 0 WITH VALUES;
END
GO

IF OBJECT_ID(N'dbo.CK_Documents_Status', N'C') IS NOT NULL
BEGIN
    ALTER TABLE dbo.Documents DROP CONSTRAINT CK_Documents_Status;
END
GO

IF OBJECT_ID(N'dbo.CK_Documents_Status', N'C') IS NULL
BEGIN
    ALTER TABLE dbo.Documents
    ADD CONSTRAINT CK_Documents_Status CHECK (Status IN (N'Uploaded', N'Processing', N'Indexed', N'Failed', N'Rejected', N'NeedsReview', N'Deleted'));
END
GO

/* =========================================================
   5. DocumentChunks
   Stores chunked text. Embedding can be stored in VectorDb by VectorId.
   EmbeddingJson is optional for demo if you want to keep vectors in SQL.
   ========================================================= */
IF OBJECT_ID(N'dbo.DocumentChunks', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DocumentChunks
    (
        Id              INT IDENTITY(1,1) PRIMARY KEY,
        DocumentId      INT NOT NULL,
        ChunkIndex      INT NOT NULL,
        Content         NVARCHAR(MAX) NOT NULL,
        PageNumber      INT NULL,
        SlideNumber     INT NULL,
        TokenCount      INT NULL,
        VectorId        NVARCHAR(100) NULL,
        EmbeddingModel  NVARCHAR(100) NULL,
        EmbeddingJson   NVARCHAR(MAX) NULL,
        CreatedAt       DATETIME2(0) NOT NULL CONSTRAINT DF_DocumentChunks_CreatedAt DEFAULT SYSUTCDATETIME(),

        CONSTRAINT FK_DocumentChunks_Documents FOREIGN KEY (DocumentId) REFERENCES dbo.Documents(Id) ON DELETE CASCADE,
        CONSTRAINT UQ_DocumentChunks_Document_ChunkIndex UNIQUE (DocumentId, ChunkIndex)
    );
END
GO

/* =========================================================
   6. DocumentChunkEmbeddings
   Stores one embedding row per chunk and embedding model.
   ========================================================= */
IF OBJECT_ID(N'dbo.DocumentChunkEmbeddings', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DocumentChunkEmbeddings
    (
        Id                  INT IDENTITY(1,1) PRIMARY KEY,
        DocumentChunkId     INT NOT NULL,
        EmbeddingModel      NVARCHAR(100) NOT NULL,
        EmbeddingProvider   NVARCHAR(50) NOT NULL,
        Dimension           INT NOT NULL,
        VectorId            NVARCHAR(100) NULL,
        VectorStore         NVARCHAR(50) NULL,
        EmbeddingJson       NVARCHAR(MAX) NULL,
        CreatedAt           DATETIME2(0) NOT NULL CONSTRAINT DF_DocumentChunkEmbeddings_CreatedAt DEFAULT SYSUTCDATETIME(),

        CONSTRAINT FK_DocumentChunkEmbeddings_DocumentChunks FOREIGN KEY (DocumentChunkId) REFERENCES dbo.DocumentChunks(Id) ON DELETE CASCADE,
        CONSTRAINT UQ_DocumentChunkEmbeddings_Chunk_Model UNIQUE (DocumentChunkId, EmbeddingModel)
    );
END
GO

/* =========================================================
   6.1. DocumentConflictReviews
   Stores conflict review sessions for documents that need head-teacher approval.
   ========================================================= */
IF OBJECT_ID(N'dbo.DocumentConflictReviews', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DocumentConflictReviews
    (
        Id                      INT IDENTITY(1,1) PRIMARY KEY,
        SubjectId               INT NOT NULL,
        NewDocumentId           INT NOT NULL,
        Status                  NVARCHAR(30) NOT NULL CONSTRAINT DF_DocumentConflictReviews_Status DEFAULT N'Pending',
        Summary                 NVARCHAR(MAX) NOT NULL,
        HighestSimilarityScore  DECIMAL(9,6) NOT NULL,
        FindingCount            INT NOT NULL,
        ResolutionChoice        NVARCHAR(50) NULL,
        ResolvedBy              INT NULL,
        ResolvedAt              DATETIME2(0) NULL,
        ResolutionNote          NVARCHAR(MAX) NULL,
        CreatedAt               DATETIME2(0) NOT NULL CONSTRAINT DF_DocumentConflictReviews_CreatedAt DEFAULT SYSUTCDATETIME(),

        CONSTRAINT FK_DocumentConflictReviews_Subjects FOREIGN KEY (SubjectId) REFERENCES dbo.Subjects(Id),
        CONSTRAINT FK_DocumentConflictReviews_NewDocument FOREIGN KEY (NewDocumentId) REFERENCES dbo.Documents(Id),
        CONSTRAINT FK_DocumentConflictReviews_ResolvedBy FOREIGN KEY (ResolvedBy) REFERENCES dbo.Users(Id),
        CONSTRAINT CK_DocumentConflictReviews_Status CHECK (Status IN (N'Pending', N'Resolved')),
        CONSTRAINT CK_DocumentConflictReviews_ResolutionChoice CHECK (ResolutionChoice IS NULL OR ResolutionChoice IN (N'AcceptNew', N'KeepExisting', N'NoConflict'))
    );
END
GO

/* =========================================================
   6.2. DocumentConflictCandidates
   Stores indexed documents that were close enough to compare with a new document.
   ========================================================= */
IF OBJECT_ID(N'dbo.DocumentConflictCandidates', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DocumentConflictCandidates
    (
        Id                   INT IDENTITY(1,1) PRIMARY KEY,
        ReviewId             INT NOT NULL,
        CandidateDocumentId  INT NOT NULL,
        MaxSimilarityScore   DECIMAL(9,6) NOT NULL,
        FindingCount         INT NOT NULL,
        Summary              NVARCHAR(MAX) NULL,
        CreatedAt            DATETIME2(0) NOT NULL CONSTRAINT DF_DocumentConflictCandidates_CreatedAt DEFAULT SYSUTCDATETIME(),

        CONSTRAINT FK_DocumentConflictCandidates_Reviews FOREIGN KEY (ReviewId) REFERENCES dbo.DocumentConflictReviews(Id) ON DELETE CASCADE,
        CONSTRAINT FK_DocumentConflictCandidates_Documents FOREIGN KEY (CandidateDocumentId) REFERENCES dbo.Documents(Id)
    );
END
GO

/* =========================================================
   6.3. DocumentConflictFindings
   Stores chunk-level differences for audit and teacher review.
   ========================================================= */
IF OBJECT_ID(N'dbo.DocumentConflictFindings', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DocumentConflictFindings
    (
        Id                INT IDENTITY(1,1) PRIMARY KEY,
        CandidateId       INT NOT NULL,
        NewChunkId        INT NOT NULL,
        ExistingChunkId   INT NOT NULL,
        SimilarityScore   DECIMAL(9,6) NOT NULL,
        TextSimilarityScore DECIMAL(9,6) NOT NULL CONSTRAINT DF_DocumentConflictFindings_TextSimilarityScore DEFAULT 0,
        Severity          NVARCHAR(30) NOT NULL,
        Explanation       NVARCHAR(MAX) NOT NULL,
        NewSnippet        NVARCHAR(MAX) NOT NULL,
        ExistingSnippet   NVARCHAR(MAX) NOT NULL,
        CreatedAt         DATETIME2(0) NOT NULL CONSTRAINT DF_DocumentConflictFindings_CreatedAt DEFAULT SYSUTCDATETIME(),

        CONSTRAINT FK_DocumentConflictFindings_Candidates FOREIGN KEY (CandidateId) REFERENCES dbo.DocumentConflictCandidates(Id) ON DELETE CASCADE,
        CONSTRAINT FK_DocumentConflictFindings_NewChunk FOREIGN KEY (NewChunkId) REFERENCES dbo.DocumentChunks(Id),
        CONSTRAINT FK_DocumentConflictFindings_ExistingChunk FOREIGN KEY (ExistingChunkId) REFERENCES dbo.DocumentChunks(Id),
        CONSTRAINT CK_DocumentConflictFindings_Severity CHECK (Severity IN (N'Low', N'Medium', N'High'))
    );
END
GO

IF OBJECT_ID(N'dbo.DocumentConflictFindings', N'U') IS NOT NULL
    AND COL_LENGTH(N'dbo.DocumentConflictFindings', N'TextSimilarityScore') IS NULL
BEGIN
    ALTER TABLE dbo.DocumentConflictFindings
    ADD TextSimilarityScore DECIMAL(9,6) NOT NULL
        CONSTRAINT DF_DocumentConflictFindings_TextSimilarityScore DEFAULT 0;
END
GO

/* =========================================================
   7. ChatSessions
   One conversation belongs to one user and usually one subject.
   ========================================================= */
IF OBJECT_ID(N'dbo.ChatSessions', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.ChatSessions
    (
        Id          INT IDENTITY(1,1) PRIMARY KEY,
        UserId      INT NULL,
        SubjectId   INT NULL,
        Title       NVARCHAR(255) NULL,
        CreatedAt   DATETIME2(0) NOT NULL CONSTRAINT DF_ChatSessions_CreatedAt DEFAULT SYSUTCDATETIME(),
        UpdatedAt   DATETIME2(0) NULL,

        CONSTRAINT FK_ChatSessions_Users FOREIGN KEY (UserId) REFERENCES dbo.Users(Id),
        CONSTRAINT FK_ChatSessions_Subjects FOREIGN KEY (SubjectId) REFERENCES dbo.Subjects(Id)
    );
END
GO

/* =========================================================
   7.1. Notifications
   In-app notifications for teachers and students.
   ========================================================= */
IF OBJECT_ID(N'dbo.Notifications', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Notifications
    (
        Id               INT IDENTITY(1,1) PRIMARY KEY,
        UserId           INT NOT NULL,
        Title            NVARCHAR(200) NOT NULL,
        Message          NVARCHAR(1000) NOT NULL,
        Type             NVARCHAR(50) NOT NULL,
        RelatedSubjectId INT NULL,
        IsRead           BIT NOT NULL CONSTRAINT DF_Notifications_IsRead DEFAULT 0,
        CreatedAt        DATETIME2(0) NOT NULL CONSTRAINT DF_Notifications_CreatedAt DEFAULT SYSUTCDATETIME(),
        ReadAt           DATETIME2(0) NULL,

        CONSTRAINT FK_Notifications_Users FOREIGN KEY (UserId) REFERENCES dbo.Users(Id),
        CONSTRAINT FK_Notifications_Subjects FOREIGN KEY (RelatedSubjectId) REFERENCES dbo.Subjects(Id)
    );
END
GO

/* =========================================================
   8. ChatMessages
   Stores user questions and assistant answers.
   ========================================================= */
IF OBJECT_ID(N'dbo.ChatMessages', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.ChatMessages
    (
        Id              INT IDENTITY(1,1) PRIMARY KEY,
        ChatSessionId   INT NOT NULL,
        Role            NVARCHAR(30) NOT NULL,
        Content         NVARCHAR(MAX) NOT NULL,
        ModelName       NVARCHAR(100) NULL,
        PromptTokens    INT NULL,
        CompletionTokens INT NULL,
        CreatedAt       DATETIME2(0) NOT NULL CONSTRAINT DF_ChatMessages_CreatedAt DEFAULT SYSUTCDATETIME(),

        CONSTRAINT FK_ChatMessages_ChatSessions FOREIGN KEY (ChatSessionId) REFERENCES dbo.ChatSessions(Id) ON DELETE CASCADE,
        CONSTRAINT CK_ChatMessages_Role CHECK (Role IN (N'User', N'Assistant', N'System'))
    );
END
GO

/* =========================================================
   9. Citations
   Links assistant answers to source chunks.
   ========================================================= */
IF OBJECT_ID(N'dbo.Citations', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Citations
    (
        Id              INT IDENTITY(1,1) PRIMARY KEY,
        ChatMessageId   INT NOT NULL,
        DocumentId      INT NOT NULL,
        ChunkId         INT NOT NULL,
        PageNumber      INT NULL,
        SlideNumber     INT NULL,
        SimilarityScore DECIMAL(9,6) NULL,
        CreatedAt       DATETIME2(0) NOT NULL CONSTRAINT DF_Citations_CreatedAt DEFAULT SYSUTCDATETIME(),

        CONSTRAINT FK_Citations_ChatMessages FOREIGN KEY (ChatMessageId) REFERENCES dbo.ChatMessages(Id) ON DELETE CASCADE,
        CONSTRAINT FK_Citations_Documents FOREIGN KEY (DocumentId) REFERENCES dbo.Documents(Id),
        CONSTRAINT FK_Citations_DocumentChunks FOREIGN KEY (ChunkId) REFERENCES dbo.DocumentChunks(Id)
    );
END
GO

/* =========================================================
   10. EvaluationQuestions
   Test set for 50 questions and ground-truth answers.
   ========================================================= */
IF OBJECT_ID(N'dbo.EvaluationQuestions', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.EvaluationQuestions
    (
        Id              INT IDENTITY(1,1) PRIMARY KEY,
        SubjectId       INT NOT NULL,
        Question        NVARCHAR(MAX) NOT NULL,
        GroundTruthAnswer NVARCHAR(MAX) NOT NULL,
        IsAnswerable    BIT NOT NULL CONSTRAINT DF_EvaluationQuestions_IsAnswerable DEFAULT 1,
        CreatedBy       INT NULL,
        CreatedAt       DATETIME2(0) NOT NULL CONSTRAINT DF_EvaluationQuestions_CreatedAt DEFAULT SYSUTCDATETIME(),

        CONSTRAINT FK_EvaluationQuestions_Subjects FOREIGN KEY (SubjectId) REFERENCES dbo.Subjects(Id),
        CONSTRAINT FK_EvaluationQuestions_Users_CreatedBy FOREIGN KEY (CreatedBy) REFERENCES dbo.Users(Id)
    );
END
GO


/* =========================================================
   10.1 EvaluationQuestionGoldChunks
   Human-reviewed relevance labels for retrieval benchmarks.
   ========================================================= */
IF OBJECT_ID(N'dbo.EvaluationQuestionGoldChunks', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.EvaluationQuestionGoldChunks
    (
        EvaluationQuestionId INT NOT NULL,
        DocumentChunkId      INT NOT NULL,
        RelevanceGrade       TINYINT NOT NULL,
        CreatedAt            DATETIME2(0) NOT NULL CONSTRAINT DF_EvaluationQuestionGoldChunks_CreatedAt DEFAULT SYSUTCDATETIME(),

        CONSTRAINT PK_EvaluationQuestionGoldChunks PRIMARY KEY (EvaluationQuestionId, DocumentChunkId),
        CONSTRAINT CK_EvaluationQuestionGoldChunks_RelevanceGrade CHECK (RelevanceGrade IN (1, 2)),
        CONSTRAINT FK_EvaluationQuestionGoldChunks_EvaluationQuestions
            FOREIGN KEY (EvaluationQuestionId) REFERENCES dbo.EvaluationQuestions(Id) ON DELETE CASCADE,
        CONSTRAINT FK_EvaluationQuestionGoldChunks_DocumentChunks
            FOREIGN KEY (DocumentChunkId) REFERENCES dbo.DocumentChunks(Id) ON DELETE CASCADE
    );
END
GO
/* =========================================================
   11. RagasBenchmarkResults
   Stores RAGAS/benchmark results from experiments.
   ========================================================= */
IF OBJECT_ID(N'dbo.RagasBenchmarkResults', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.RagasBenchmarkResults
    (
        Id                  INT IDENTITY(1,1) PRIMARY KEY,
        EvaluationQuestionId INT NOT NULL,
        RunId               NVARCHAR(50) NOT NULL,
        EmbeddingModel      NVARCHAR(100) NOT NULL,
        LlmModel            NVARCHAR(100) NULL,
        VectorStore         NVARCHAR(50) NULL,
        ChunkingStrategy    NVARCHAR(100) NOT NULL,
        GeneratedAnswer     NVARCHAR(MAX) NULL,
        RetrievedContextsJson NVARCHAR(MAX) NULL,
        RetrievedChunkIdsJson NVARCHAR(MAX) NULL,
        CitationChunkIdsJson  NVARCHAR(MAX) NULL,
        RecallAt5           DECIMAL(9,6) NULL,
        MrrAt10             DECIMAL(9,6) NULL,
        NdcgAt5             DECIMAL(9,6) NULL,
        AnswerCorrectness   DECIMAL(9,6) NULL,
        Faithfulness        DECIMAL(9,6) NULL,
        CitationPrecision   DECIMAL(9,6) NULL,
        CitationRecall      DECIMAL(9,6) NULL,
        CitationF1          DECIMAL(9,6) NULL,
        ExpectedNoAnswer    BIT NOT NULL CONSTRAINT DF_RagasBenchmarkResults_ExpectedNoAnswer DEFAULT 0,
        PredictedNoAnswer   BIT NOT NULL CONSTRAINT DF_RagasBenchmarkResults_PredictedNoAnswer DEFAULT 0,
        EmbeddingLatencyMs  BIGINT NOT NULL CONSTRAINT DF_RagasBenchmarkResults_EmbeddingLatencyMs DEFAULT 0,
        RetrievalLatencyMs  BIGINT NOT NULL CONSTRAINT DF_RagasBenchmarkResults_RetrievalLatencyMs DEFAULT 0,
        GenerationLatencyMs BIGINT NOT NULL CONSTRAINT DF_RagasBenchmarkResults_GenerationLatencyMs DEFAULT 0,
        EndToEndLatencyMs   BIGINT NOT NULL CONSTRAINT DF_RagasBenchmarkResults_EndToEndLatencyMs DEFAULT 0,
        CreatedAt           DATETIME2(0) NOT NULL CONSTRAINT DF_RagasBenchmarkResults_CreatedAt DEFAULT SYSUTCDATETIME(),

        CONSTRAINT FK_RagasBenchmarkResults_EvaluationQuestions FOREIGN KEY (EvaluationQuestionId) REFERENCES dbo.EvaluationQuestions(Id) ON DELETE CASCADE
    );
END
GO

/* =========================================================
   Indexes
   ========================================================= */
CREATE INDEX IX_Subjects_SubjectName ON dbo.Subjects(SubjectName);
CREATE INDEX IX_Documents_SubjectId ON dbo.Documents(SubjectId);
CREATE INDEX IX_Documents_Status ON dbo.Documents(Status);
CREATE INDEX IX_DocumentChunks_DocumentId ON dbo.DocumentChunks(DocumentId);
CREATE INDEX IX_DocumentChunks_VectorId ON dbo.DocumentChunks(VectorId) WHERE VectorId IS NOT NULL;
CREATE INDEX IX_EvaluationQuestionGoldChunks_DocumentChunkId ON dbo.EvaluationQuestionGoldChunks(DocumentChunkId);
CREATE INDEX IX_DocumentChunkEmbeddings_DocumentChunkId ON dbo.DocumentChunkEmbeddings(DocumentChunkId);
CREATE INDEX IX_DocumentChunkEmbeddings_VectorId ON dbo.DocumentChunkEmbeddings(VectorId) WHERE VectorId IS NOT NULL;
CREATE INDEX IX_DocumentConflictReviews_NewDocumentId ON dbo.DocumentConflictReviews(NewDocumentId);
CREATE INDEX IX_DocumentConflictReviews_SubjectId ON dbo.DocumentConflictReviews(SubjectId);
CREATE INDEX IX_DocumentConflictReviews_Status ON dbo.DocumentConflictReviews(Status);
CREATE INDEX IX_DocumentConflictCandidates_ReviewId ON dbo.DocumentConflictCandidates(ReviewId);
CREATE INDEX IX_DocumentConflictCandidates_CandidateDocumentId ON dbo.DocumentConflictCandidates(CandidateDocumentId);
CREATE INDEX IX_DocumentConflictFindings_CandidateId ON dbo.DocumentConflictFindings(CandidateId);
CREATE INDEX IX_DocumentConflictFindings_NewChunkId ON dbo.DocumentConflictFindings(NewChunkId);
CREATE INDEX IX_DocumentConflictFindings_ExistingChunkId ON dbo.DocumentConflictFindings(ExistingChunkId);
CREATE INDEX IX_ChatSessions_UserId ON dbo.ChatSessions(UserId);
CREATE INDEX IX_ChatSessions_SubjectId ON dbo.ChatSessions(SubjectId);
CREATE INDEX IX_ChatMessages_ChatSessionId ON dbo.ChatMessages(ChatSessionId);
CREATE INDEX IX_Citations_ChatMessageId ON dbo.Citations(ChatMessageId);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Subjects_IsDeleted' AND object_id = OBJECT_ID(N'dbo.Subjects'))
BEGIN
    CREATE INDEX IX_Subjects_IsDeleted ON dbo.Subjects(IsDeleted);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Notifications_User_Read_CreatedAt' AND object_id = OBJECT_ID(N'dbo.Notifications'))
BEGIN
    CREATE INDEX IX_Notifications_User_Read_CreatedAt ON dbo.Notifications(UserId, IsRead, CreatedAt DESC);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Notifications_RelatedSubjectId' AND object_id = OBJECT_ID(N'dbo.Notifications'))
BEGIN
    CREATE INDEX IX_Notifications_RelatedSubjectId ON dbo.Notifications(RelatedSubjectId);
END
GO

/* =========================================================
   Seed data
   Demo login passwords are listed below after the user seed block.
   ========================================================= */
IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE Email = N'admin@chataiweb.local')
BEGIN
    INSERT INTO dbo.Users (FullName, Email, PasswordHash, Role)
    VALUES
    (N'Quản trị hệ thống', N'admin@chataiweb.local', N'PBKDF2-HMACSHA256$100000$Q2hhdEFJV2ViQWRtaW5fXw==$3G8Y7aSse368ibrsOFvz6jC1xHtRCogwHId2ACh66qg=', N'Admin'),
    (N'Giảng viên Demo', N'teacher@chataiweb.local', N'PBKDF2-HMACSHA256$100000$Q2hhdEFJV2ViVGVhY2hlcg==$MnyMqV23QsQhkLuV4ApM5LWVwasxCHniABxZxwb4uy4=', N'Teacher'),
    (N'Sinh viên Demo', N'student@chataiweb.local', N'PBKDF2-HMACSHA256$100000$Q2hhdEFJV2ViU3R1ZGVudA==$vZpTrUVuZTGibulis2S6aU9fpOMqt2N57ddjH2Gz+Ek=', N'Student'),
    -- Additional teachers (password: Teacher@123 — reuses the demo teacher hash)
    (N'Trần Văn An',     N'an.tran@chataiweb.local',     N'PBKDF2-HMACSHA256$100000$Q2hhdEFJV2ViVGVhY2hlcg==$MnyMqV23QsQhkLuV4ApM5LWVwasxCHniABxZxwb4uy4=', N'Teacher'),
    (N'Nguyễn Thị Bình', N'binh.nguyen@chataiweb.local', N'PBKDF2-HMACSHA256$100000$Q2hhdEFJV2ViVGVhY2hlcg==$MnyMqV23QsQhkLuV4ApM5LWVwasxCHniABxZxwb4uy4=', N'Teacher'),
    (N'Lê Văn Cường',    N'cuong.le@chataiweb.local',    N'PBKDF2-HMACSHA256$100000$Q2hhdEFJV2ViVGVhY2hlcg==$MnyMqV23QsQhkLuV4ApM5LWVwasxCHniABxZxwb4uy4=', N'Teacher'),
    -- Additional students (password: Student@123 — reuses the demo student hash)
    (N'Phạm Thị Dung',   N'dung.pham@chataiweb.local',   N'PBKDF2-HMACSHA256$100000$Q2hhdEFJV2ViU3R1ZGVudA==$vZpTrUVuZTGibulis2S6aU9fpOMqt2N57ddjH2Gz+Ek=', N'Student'),
    (N'Hoàng Văn Em',    N'em.hoang@chataiweb.local',    N'PBKDF2-HMACSHA256$100000$Q2hhdEFJV2ViU3R1ZGVudA==$vZpTrUVuZTGibulis2S6aU9fpOMqt2N57ddjH2Gz+Ek=', N'Student'),
    (N'Vũ Thị Phương',   N'phuong.vu@chataiweb.local',   N'PBKDF2-HMACSHA256$100000$Q2hhdEFJV2ViU3R1ZGVudA==$vZpTrUVuZTGibulis2S6aU9fpOMqt2N57ddjH2Gz+Ek=', N'Student'),
    (N'Đỗ Văn Giang',    N'giang.do@chataiweb.local',    N'PBKDF2-HMACSHA256$100000$Q2hhdEFJV2ViU3R1ZGVudA==$vZpTrUVuZTGibulis2S6aU9fpOMqt2N57ddjH2Gz+Ek=', N'Student'),
    (N'Bùi Thị Hà',      N'ha.bui@chataiweb.local',      N'PBKDF2-HMACSHA256$100000$Q2hhdEFJV2ViU3R1ZGVudA==$vZpTrUVuZTGibulis2S6aU9fpOMqt2N57ddjH2Gz+Ek=', N'Student'),
    (N'Ngô Văn Khoa',    N'khoa.ngo@chataiweb.local',    N'PBKDF2-HMACSHA256$100000$Q2hhdEFJV2ViU3R1ZGVudA==$vZpTrUVuZTGibulis2S6aU9fpOMqt2N57ddjH2Gz+Ek=', N'Student'),
    (N'Lý Thị Lan',      N'lan.ly@chataiweb.local',      N'PBKDF2-HMACSHA256$100000$Q2hhdEFJV2ViU3R1ZGVudA==$vZpTrUVuZTGibulis2S6aU9fpOMqt2N57ddjH2Gz+Ek=', N'Student'),
    -- More teachers (password: Teacher@123 — reuses the demo teacher hash)
    (N'Phan Thị Mai',    N'mai.phan@chataiweb.local',    N'PBKDF2-HMACSHA256$100000$Q2hhdEFJV2ViVGVhY2hlcg==$MnyMqV23QsQhkLuV4ApM5LWVwasxCHniABxZxwb4uy4=', N'Teacher'),
    (N'Trịnh Văn Nam',   N'nam.trinh@chataiweb.local',   N'PBKDF2-HMACSHA256$100000$Q2hhdEFJV2ViVGVhY2hlcg==$MnyMqV23QsQhkLuV4ApM5LWVwasxCHniABxZxwb4uy4=', N'Teacher'),
    (N'Đặng Thị Oanh',   N'oanh.dang@chataiweb.local',   N'PBKDF2-HMACSHA256$100000$Q2hhdEFJV2ViVGVhY2hlcg==$MnyMqV23QsQhkLuV4ApM5LWVwasxCHniABxZxwb4uy4=', N'Teacher'),
    (N'Hồ Văn Phúc',     N'phuc.ho@chataiweb.local',     N'PBKDF2-HMACSHA256$100000$Q2hhdEFJV2ViVGVhY2hlcg==$MnyMqV23QsQhkLuV4ApM5LWVwasxCHniABxZxwb4uy4=', N'Teacher'),
    (N'Võ Thị Quỳnh',    N'quynh.vo@chataiweb.local',    N'PBKDF2-HMACSHA256$100000$Q2hhdEFJV2ViVGVhY2hlcg==$MnyMqV23QsQhkLuV4ApM5LWVwasxCHniABxZxwb4uy4=', N'Teacher'),
    (N'Lương Văn Sơn',   N'son.luong@chataiweb.local',   N'PBKDF2-HMACSHA256$100000$Q2hhdEFJV2ViVGVhY2hlcg==$MnyMqV23QsQhkLuV4ApM5LWVwasxCHniABxZxwb4uy4=', N'Teacher'),
    -- More students (password: Student@123 — reuses the demo student hash)
    (N'Trương Thị Tâm',  N'tam.truong@chataiweb.local',  N'PBKDF2-HMACSHA256$100000$Q2hhdEFJV2ViU3R1ZGVudA==$vZpTrUVuZTGibulis2S6aU9fpOMqt2N57ddjH2Gz+Ek=', N'Student'),
    (N'Đinh Văn Tuấn',   N'tuan.dinh@chataiweb.local',   N'PBKDF2-HMACSHA256$100000$Q2hhdEFJV2ViU3R1ZGVudA==$vZpTrUVuZTGibulis2S6aU9fpOMqt2N57ddjH2Gz+Ek=', N'Student'),
    (N'Mai Thị Uyên',    N'uyen.mai@chataiweb.local',    N'PBKDF2-HMACSHA256$100000$Q2hhdEFJV2ViU3R1ZGVudA==$vZpTrUVuZTGibulis2S6aU9fpOMqt2N57ddjH2Gz+Ek=', N'Student'),
    (N'Tô Văn Vũ',       N'vu.to@chataiweb.local',       N'PBKDF2-HMACSHA256$100000$Q2hhdEFJV2ViU3R1ZGVudA==$vZpTrUVuZTGibulis2S6aU9fpOMqt2N57ddjH2Gz+Ek=', N'Student'),
    (N'Phùng Thị Xuân',  N'xuan.phung@chataiweb.local',  N'PBKDF2-HMACSHA256$100000$Q2hhdEFJV2ViU3R1ZGVudA==$vZpTrUVuZTGibulis2S6aU9fpOMqt2N57ddjH2Gz+Ek=', N'Student'),
    (N'Cao Văn Đông',    N'dong.cao@chataiweb.local',    N'PBKDF2-HMACSHA256$100000$Q2hhdEFJV2ViU3R1ZGVudA==$vZpTrUVuZTGibulis2S6aU9fpOMqt2N57ddjH2Gz+Ek=', N'Student'),
    (N'Hà Thị Anh',      N'anh.ha@chataiweb.local',      N'PBKDF2-HMACSHA256$100000$Q2hhdEFJV2ViU3R1ZGVudA==$vZpTrUVuZTGibulis2S6aU9fpOMqt2N57ddjH2Gz+Ek=', N'Student'),
    (N'Dương Văn Bảo',   N'bao.duong@chataiweb.local',   N'PBKDF2-HMACSHA256$100000$Q2hhdEFJV2ViU3R1ZGVudA==$vZpTrUVuZTGibulis2S6aU9fpOMqt2N57ddjH2Gz+Ek=', N'Student'),
    (N'Tạ Thị Châu',     N'chau.ta@chataiweb.local',     N'PBKDF2-HMACSHA256$100000$Q2hhdEFJV2ViU3R1ZGVudA==$vZpTrUVuZTGibulis2S6aU9fpOMqt2N57ddjH2Gz+Ek=', N'Student'),
    (N'Lưu Văn Đạt',     N'dat.luu@chataiweb.local',     N'PBKDF2-HMACSHA256$100000$Q2hhdEFJV2ViU3R1ZGVudA==$vZpTrUVuZTGibulis2S6aU9fpOMqt2N57ddjH2Gz+Ek=', N'Student'),
    (N'Tống Thị Hồng',   N'hong.tong@chataiweb.local',   N'PBKDF2-HMACSHA256$100000$Q2hhdEFJV2ViU3R1ZGVudA==$vZpTrUVuZTGibulis2S6aU9fpOMqt2N57ddjH2Gz+Ek=', N'Student'),
    (N'Chu Văn Hùng',    N'hung.chu@chataiweb.local',    N'PBKDF2-HMACSHA256$100000$Q2hhdEFJV2ViU3R1ZGVudA==$vZpTrUVuZTGibulis2S6aU9fpOMqt2N57ddjH2Gz+Ek=', N'Student'),
    (N'Nguyễn Văn Quân', N'quan.nguyen@chataiweb.local', N'PBKDF2-HMACSHA256$100000$Q2hhdEFJV2ViU3R1ZGVudA==$vZpTrUVuZTGibulis2S6aU9fpOMqt2N57ddjH2Gz+Ek=', N'Student'),
    (N'Trần Thị Thảo',   N'thao.tran@chataiweb.local',   N'PBKDF2-HMACSHA256$100000$Q2hhdEFJV2ViU3R1ZGVudA==$vZpTrUVuZTGibulis2S6aU9fpOMqt2N57ddjH2Gz+Ek=', N'Student'),
    (N'Lê Văn Tiến',     N'tien.le@chataiweb.local',     N'PBKDF2-HMACSHA256$100000$Q2hhdEFJV2ViU3R1ZGVudA==$vZpTrUVuZTGibulis2S6aU9fpOMqt2N57ddjH2Gz+Ek=', N'Student'),
    (N'Phạm Thị Linh',   N'linh.pham@chataiweb.local',   N'PBKDF2-HMACSHA256$100000$Q2hhdEFJV2ViU3R1ZGVudA==$vZpTrUVuZTGibulis2S6aU9fpOMqt2N57ddjH2Gz+Ek=', N'Student'),
    (N'Hoàng Văn Long',  N'long.hoang@chataiweb.local',  N'PBKDF2-HMACSHA256$100000$Q2hhdEFJV2ViU3R1ZGVudA==$vZpTrUVuZTGibulis2S6aU9fpOMqt2N57ddjH2Gz+Ek=', N'Student'),
    (N'Vũ Thị Hương',    N'huong.vu@chataiweb.local',    N'PBKDF2-HMACSHA256$100000$Q2hhdEFJV2ViU3R1ZGVudA==$vZpTrUVuZTGibulis2S6aU9fpOMqt2N57ddjH2Gz+Ek=', N'Student'),
    (N'Đỗ Văn Khánh',    N'khanh.do@chataiweb.local',    N'PBKDF2-HMACSHA256$100000$Q2hhdEFJV2ViU3R1ZGVudA==$vZpTrUVuZTGibulis2S6aU9fpOMqt2N57ddjH2Gz+Ek=', N'Student'),
    (N'Bùi Thị Ngọc',    N'ngoc.bui@chataiweb.local',    N'PBKDF2-HMACSHA256$100000$Q2hhdEFJV2ViU3R1ZGVudA==$vZpTrUVuZTGibulis2S6aU9fpOMqt2N57ddjH2Gz+Ek=', N'Student'),
    (N'Ngô Văn Phong',   N'phong.ngo@chataiweb.local',   N'PBKDF2-HMACSHA256$100000$Q2hhdEFJV2ViU3R1ZGVudA==$vZpTrUVuZTGibulis2S6aU9fpOMqt2N57ddjH2Gz+Ek=', N'Student'),
    (N'Lý Thị Quyên',    N'quyen.ly@chataiweb.local',    N'PBKDF2-HMACSHA256$100000$Q2hhdEFJV2ViU3R1ZGVudA==$vZpTrUVuZTGibulis2S6aU9fpOMqt2N57ddjH2Gz+Ek=', N'Student'),
    (N'Phan Văn Sang',   N'sang.phan@chataiweb.local',   N'PBKDF2-HMACSHA256$100000$Q2hhdEFJV2ViU3R1ZGVudA==$vZpTrUVuZTGibulis2S6aU9fpOMqt2N57ddjH2Gz+Ek=', N'Student'),
    (N'Trịnh Thị Thu',   N'thu.trinh@chataiweb.local',   N'PBKDF2-HMACSHA256$100000$Q2hhdEFJV2ViU3R1ZGVudA==$vZpTrUVuZTGibulis2S6aU9fpOMqt2N57ddjH2Gz+Ek=', N'Student'),
    (N'Đặng Văn Toàn',   N'toan.dang@chataiweb.local',   N'PBKDF2-HMACSHA256$100000$Q2hhdEFJV2ViU3R1ZGVudA==$vZpTrUVuZTGibulis2S6aU9fpOMqt2N57ddjH2Gz+Ek=', N'Student'),
    (N'Hồ Thị Trang',    N'trang.ho@chataiweb.local',    N'PBKDF2-HMACSHA256$100000$Q2hhdEFJV2ViU3R1ZGVudA==$vZpTrUVuZTGibulis2S6aU9fpOMqt2N57ddjH2Gz+Ek=', N'Student'),
    (N'Võ Văn Việt',     N'viet.vo@chataiweb.local',     N'PBKDF2-HMACSHA256$100000$Q2hhdEFJV2ViU3R1ZGVudA==$vZpTrUVuZTGibulis2S6aU9fpOMqt2N57ddjH2Gz+Ek=', N'Student'),
    (N'Lương Thị Yến',   N'yen.luong@chataiweb.local',   N'PBKDF2-HMACSHA256$100000$Q2hhdEFJV2ViU3R1ZGVudA==$vZpTrUVuZTGibulis2S6aU9fpOMqt2N57ddjH2Gz+Ek=', N'Student'),
    (N'Trương Văn Đức',  N'duc.truong@chataiweb.local',  N'PBKDF2-HMACSHA256$100000$Q2hhdEFJV2ViU3R1ZGVudA==$vZpTrUVuZTGibulis2S6aU9fpOMqt2N57ddjH2Gz+Ek=', N'Student'),
    (N'Đinh Thị Hằng',   N'hang.dinh@chataiweb.local',   N'PBKDF2-HMACSHA256$100000$Q2hhdEFJV2ViU3R1ZGVudA==$vZpTrUVuZTGibulis2S6aU9fpOMqt2N57ddjH2Gz+Ek=', N'Student'),
    (N'Mai Văn Khánh',   N'khanh.mai@chataiweb.local',   N'PBKDF2-HMACSHA256$100000$Q2hhdEFJV2ViU3R1ZGVudA==$vZpTrUVuZTGibulis2S6aU9fpOMqt2N57ddjH2Gz+Ek=', N'Student');
END
GO

/* Demo login passwords:
   admin@chataiweb.local   / Admin@123
   teacher@chataiweb.local / Teacher@123
   student@chataiweb.local / Student@123
*/
UPDATE dbo.Users
SET FullName = N'Quản trị hệ thống',
    PasswordHash = N'PBKDF2-HMACSHA256$100000$Q2hhdEFJV2ViQWRtaW5fXw==$3G8Y7aSse368ibrsOFvz6jC1xHtRCogwHId2ACh66qg='
WHERE Email = N'admin@chataiweb.local';

UPDATE dbo.Users
SET FullName = N'Giảng viên Demo',
    PasswordHash = N'PBKDF2-HMACSHA256$100000$Q2hhdEFJV2ViVGVhY2hlcg==$MnyMqV23QsQhkLuV4ApM5LWVwasxCHniABxZxwb4uy4='
WHERE Email = N'teacher@chataiweb.local';

UPDATE dbo.Users
SET FullName = N'Sinh viên Demo',
    PasswordHash = N'PBKDF2-HMACSHA256$100000$Q2hhdEFJV2ViU3R1ZGVudA==$vZpTrUVuZTGibulis2S6aU9fpOMqt2N57ddjH2Gz+Ek='
WHERE Email = N'student@chataiweb.local';
GO

/* =========================================================
   Seed: per-user token usage demo for AdminTokenUsage
   UTC timestamps correspond to noon in Vietnam, 06-12/07/2026.
   ========================================================= */
DECLARE @TokenUsageSeedTitle NVARCHAR(255) = N'[SeedDemo] Token usage 06-12/07/2026';
DECLARE @TokenUsageStartUtc DATETIME2(0) = CONVERT(DATETIME2(0), '2026-07-06T05:00:00');

DELETE FROM dbo.ChatSessions
WHERE Title = @TokenUsageSeedTitle;

INSERT INTO dbo.ChatSessions (UserId, SubjectId, Title, CreatedAt, UpdatedAt)
SELECT
    userAccount.Id,
    NULL,
    @TokenUsageSeedTitle,
    @TokenUsageStartUtc,
    DATEADD
    (
        DAY,
        CASE
            WHEN userAccount.Email = N'teacher@chataiweb.local' THEN 6
            WHEN userAccount.Role = N'Admin' THEN 3
            WHEN userAccount.Role = N'Teacher' THEN 4 + (userAccount.Id % 2)
            ELSE 2 + (userAccount.Id % 4)
        END,
        @TokenUsageStartUtc
    )
FROM dbo.Users userAccount;

DECLARE @TokenUsageDays TABLE (DayOffset INT NOT NULL PRIMARY KEY);
INSERT INTO @TokenUsageDays (DayOffset)
VALUES (0), (1), (2), (3), (4), (5), (6);

INSERT INTO dbo.ChatMessages
    (ChatSessionId, Role, Content, ModelName, PromptTokens, CompletionTokens, CreatedAt)
SELECT
    session.Id,
    N'Assistant',
    N'Dữ liệu demo thống kê token theo người dùng.',
    N'gemini-2.0-flash',
    CASE
        WHEN userAccount.Email = N'teacher@chataiweb.local' THEN 650 + (usageDay.DayOffset * 55)
        WHEN userAccount.Role = N'Admin' THEN 55 + (usageDay.DayOffset * 4)
        WHEN userAccount.Role = N'Teacher' THEN 300 + ((userAccount.Id % 5) * 25) + (usageDay.DayOffset * 20)
        ELSE 180 + ((userAccount.Id % 7) * 20) + (usageDay.DayOffset * 15)
    END,
    CASE
        WHEN userAccount.Email = N'teacher@chataiweb.local' THEN 420 + (usageDay.DayOffset * 35)
        WHEN userAccount.Role = N'Admin' THEN 35 + (usageDay.DayOffset * 3)
        WHEN userAccount.Role = N'Teacher' THEN 180 + ((userAccount.Id % 4) * 18) + (usageDay.DayOffset * 12)
        ELSE 100 + ((userAccount.Id % 5) * 12) + (usageDay.DayOffset * 10)
    END,
    DATEADD(MINUTE, userAccount.Id % 60, DATEADD(DAY, usageDay.DayOffset, @TokenUsageStartUtc))
FROM dbo.ChatSessions session
INNER JOIN dbo.Users userAccount ON userAccount.Id = session.UserId
CROSS JOIN @TokenUsageDays usageDay
WHERE session.Title = @TokenUsageSeedTitle
  AND usageDay.DayOffset <
      CASE
          WHEN userAccount.Email = N'teacher@chataiweb.local' THEN 7
          WHEN userAccount.Role = N'Admin' THEN 4
          WHEN userAccount.Role = N'Teacher' THEN 5 + (userAccount.Id % 2)
          ELSE 3 + (userAccount.Id % 4)
      END;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Subjects WHERE SubjectCode = N'CS101')
BEGIN
    INSERT INTO dbo.Subjects (SubjectCode, SubjectName, Description, CreatedBy)
    VALUES
    (N'CS101',   N'Nhập môn lập trình',          N'Tài liệu bài giảng nhập môn lập trình dùng để demo chatbot RAG.',          4),
    (N'DB201',   N'Cơ sở dữ liệu',               N'Tài liệu môn cơ sở dữ liệu, SQL, ERD và chuẩn hóa dữ liệu.',               5),
    (N'AI301',   N'Trí tuệ nhân tạo',            N'Tài liệu môn trí tuệ nhân tạo, machine learning và RAG.',                  6),
    (N'PRN222',  N'Lập trình ASP.NET Core MVC',  N'Tài liệu môn PRN222: ASP.NET Core MVC, EF Core, SignalR, kiến trúc 3-lớp.',14),
    (N'PRO192',  N'Lập trình hướng đối tượng',   N'Tài liệu môn lập trình hướng đối tượng với C#: lớp, kế thừa, đa hình.',    15),
    (N'CSI104',  N'Nhập môn ngành công nghệ thông tin', N'Tài liệu giới thiệu ngành CNTT, các nhánh chuyên môn và kỹ năng nền tảng.', 17),
    (N'SWE201',  N'Nhập môn kỹ thuật phần mềm',  N'Tài liệu môn kỹ thuật phần mềm: vòng đời SDLC, Agile, kiểm thử, quản lý cấu hình.', 18),
    (N'VNR202',  N'Lịch sử Đảng Cộng sản Việt Nam', N'Tài liệu môn Lịch sử Đảng: quá trình thành lập, các kỳ Đại hội và đường lối lãnh đạo cách mạng Việt Nam.', 2),
    (N'NWC203',  N'Mạng máy tính',                N'Tài liệu môn Mạng máy tính: mô hình OSI/TCP-IP, định tuyến, giao thức tầng ứng dụng và bảo mật mạng.', 6);
END
GO

IF NOT EXISTS (SELECT 1 FROM dbo.SubjectEnrollments)
BEGIN
    -- User Ids:
    --   Teachers (10): 2=Teacher Demo, 4=An, 5=Bình, 6=Cường, 14=Mai, 15=Nam, 16=Oanh, 17=Phúc, 18=Quỳnh, 19=Sơn
    --   Students (39): 3=Student Demo, 7=Dung, 8=Em, 9=Phương, 10=Giang, 11=Hà, 12=Khoa, 13=Lan,
    --                  20=Tâm, 21=Tuấn, 22=Uyên, 23=Vũ, 24=Xuân, 25=Đông, 26=Anh, 27=Bảo, 28=Châu, 29=Đạt,
    --                  30=Hồng, 31=Hùng, 32=Quân, 33=Thảo, 34=Tiến, 35=Linh, 36=Long, 37=Hương, 38=Khánh,
    --                  39=Ngọc, 40=Phong, 41=Quyên, 42=Sang, 43=Thu, 44=Toàn, 45=Trang, 46=Việt, 47=Yến,
    --                  48=Đức, 49=Hằng, 50=Khánh
    -- Subject Ids: 1=CS101, 2=DB201, 3=AI301, 4=PRN222, 5=PRO192, 6=CSI104, 7=SWE201, 8=VNR202, 9=NWC203
    INSERT INTO dbo.SubjectEnrollments (SubjectId, UserId, RoleInClass)
    VALUES
    -- CS101 — Nhập môn lập trình
    (1, 2, N'Teacher'), (1, 4, N'Teacher'), (1, 14, N'Teacher'),
    (1, 3, N'Student'), (1, 7, N'Student'), (1, 8, N'Student'), (1, 9, N'Student'),
    (1, 20, N'Student'), (1, 21, N'Student'), (1, 22, N'Student'), (1, 23, N'Student'),
    (1, 24, N'Student'), (1, 38, N'Student'),
    -- DB201 — Cơ sở dữ liệu
    (2, 2, N'Teacher'), (2, 5, N'Teacher'), (2, 15, N'Teacher'),
    (2, 3, N'Student'), (2, 10, N'Student'), (2, 11, N'Student'),
    (2, 25, N'Student'), (2, 26, N'Student'), (2, 27, N'Student'), (2, 28, N'Student'),
    (2, 39, N'Student'),
    -- AI301 — Trí tuệ nhân tạo
    (3, 2, N'Teacher'), (3, 6, N'Teacher'), (3, 16, N'Teacher'),
    (3, 3, N'Student'), (3, 7, N'Student'), (3, 12, N'Student'), (3, 13, N'Student'),
    (3, 29, N'Student'), (3, 30, N'Student'), (3, 31, N'Student'), (3, 32, N'Student'),
    (3, 40, N'Student'),
    -- PRN222 — ASP.NET Core MVC
    (4, 4, N'Teacher'), (4, 5, N'Teacher'), (4, 17, N'Teacher'),
    (4, 3, N'Student'), (4, 8, N'Student'), (4, 9, N'Student'), (4, 10, N'Student'), (4, 11, N'Student'),
    (4, 33, N'Student'), (4, 34, N'Student'), (4, 35, N'Student'), (4, 36, N'Student'),
    (4, 41, N'Student'),
    -- PRO192 — Lập trình hướng đối tượng
    (5, 4, N'Teacher'), (5, 14, N'Teacher'),
    (5, 3, N'Student'), (5, 7, N'Student'), (5, 9, N'Student'), (5, 12, N'Student'),
    (5, 20, N'Student'), (5, 25, N'Student'), (5, 33, N'Student'), (5, 42, N'Student'),
    (5, 43, N'Student'),
    -- CSI104 — Nhập môn ngành CNTT
    (6, 6, N'Teacher'), (6, 18, N'Teacher'),
    (6, 3, N'Student'), (6, 7, N'Student'), (6, 8, N'Student'), (6, 13, N'Student'),
    (6, 21, N'Student'), (6, 26, N'Student'), (6, 34, N'Student'), (6, 44, N'Student'),
    (6, 45, N'Student'),
    -- SWE201 — Nhập môn kỹ thuật phần mềm
    (7, 5, N'Teacher'), (7, 6, N'Teacher'), (7, 19, N'Teacher'),
    (7, 11, N'Student'), (7, 12, N'Student'), (7, 13, N'Student'),
    (7, 22, N'Student'), (7, 27, N'Student'), (7, 35, N'Student'), (7, 46, N'Student'),
    (7, 47, N'Student'), (7, 48, N'Student'),
    -- VNR202 — Lịch sử Đảng Cộng sản Việt Nam (môn đại cương — đông sinh viên)
    (8, 5, N'Teacher'), (8, 6, N'Teacher'), (8, 18, N'Teacher'), (8, 19, N'Teacher'),
    (8, 3, N'Student'), (8, 7, N'Student'), (8, 8, N'Student'), (8, 9, N'Student'),
    (8, 10, N'Student'), (8, 11, N'Student'), (8, 12, N'Student'), (8, 13, N'Student'),
    (8, 20, N'Student'), (8, 23, N'Student'), (8, 28, N'Student'), (8, 29, N'Student'),
    (8, 32, N'Student'), (8, 36, N'Student'), (8, 37, N'Student'), (8, 38, N'Student'),
    (8, 41, N'Student'), (8, 42, N'Student'), (8, 46, N'Student'), (8, 49, N'Student'),
    (8, 50, N'Student'),
    -- NWC203 — Mạng máy tính
    (9, 17, N'Teacher'), (9, 19, N'Teacher'),
    (9, 3, N'Student'), (9, 30, N'Student'), (9, 31, N'Student'), (9, 37, N'Student'),
    (9, 39, N'Student'), (9, 40, N'Student'), (9, 43, N'Student'), (9, 44, N'Student'),
    (9, 47, N'Student'), (9, 48, N'Student'), (9, 49, N'Student'), (9, 50, N'Student');
END
GO

/* =========================================================
   Seed: EvaluationQuestions
   Sample ground-truth Q&A used by the RAGAS benchmark page.
   ========================================================= */
IF NOT EXISTS (SELECT 1 FROM dbo.EvaluationQuestions)
BEGIN
    INSERT INTO dbo.EvaluationQuestions (SubjectId, Question, GroundTruthAnswer, CreatedBy)
    VALUES
    -- CS101 — Nhập môn lập trình
    (1, N'Biến trong lập trình là gì?',
        N'Biến là vùng nhớ có tên dùng để lưu giá trị, có kiểu dữ liệu xác định và có thể thay đổi giá trị trong quá trình chạy chương trình.', 2),
    (1, N'Vòng lặp for và while khác nhau như thế nào?',
        N'Vòng lặp for thường dùng khi đã biết trước số lần lặp; vòng lặp while dùng khi điều kiện dừng phụ thuộc vào trạng thái chạy chương trình.', 2),
    (1, N'Hàm (function) trong lập trình dùng để làm gì?',
        N'Hàm là khối lệnh có tên, có thể nhận tham số và trả về kết quả, giúp tái sử dụng mã, tách logic và giảm trùng lặp.', 2),

    -- DB201 — Cơ sở dữ liệu
    (2, N'Khoá chính (primary key) là gì?',
        N'Khoá chính là một hoặc nhiều cột định danh duy nhất mỗi bản ghi trong bảng, không được trùng và không được NULL.', 2),
    (2, N'Chuẩn hoá 3NF nhằm mục đích gì?',
        N'Chuẩn 3NF loại bỏ các phụ thuộc bắc cầu giữa các thuộc tính không khoá vào khoá chính, giúp giảm dư thừa và tránh dị thường khi cập nhật.', 2),
    (2, N'Khác nhau giữa INNER JOIN và LEFT JOIN?',
        N'INNER JOIN chỉ trả về các bản ghi có khớp ở cả hai bảng; LEFT JOIN trả về toàn bộ bản ghi của bảng bên trái và NULL cho các cột bên phải khi không có khớp.', 2),

    -- AI301 — Trí tuệ nhân tạo
    (3, N'RAG (Retrieval-Augmented Generation) là gì?',
        N'RAG là kỹ thuật kết hợp truy xuất tài liệu liên quan với mô hình sinh ngôn ngữ, để mô hình trả lời dựa trên ngữ cảnh được truy xuất thay vì chỉ dựa vào tham số đã học.', 2),
    (3, N'Embedding vector trong NLP biểu diễn cái gì?',
        N'Embedding là vector số thực biểu diễn ngữ nghĩa của từ, câu hoặc tài liệu, sao cho các nội dung có ý nghĩa gần nhau sẽ có khoảng cách cosine nhỏ.', 2),
    (3, N'Cosine similarity được tính như thế nào?',
        N'Cosine similarity giữa hai vector A và B bằng tích vô hướng A·B chia cho tích độ dài |A|·|B|, kết quả nằm trong khoảng từ -1 đến 1.', 2),

    -- PRN222 — ASP.NET Core MVC
    (4, N'Vai trò của Controller trong mô hình MVC là gì?',
        N'Controller nhận yêu cầu HTTP, gọi service hoặc model để xử lý dữ liệu, sau đó chọn View hoặc kết quả trả về cho client; Controller nên giữ mỏng và không chứa nghiệp vụ.', 2),
    (4, N'Dependency Injection trong ASP.NET Core hoạt động như thế nào?',
        N'ASP.NET Core có sẵn container DI; các service được đăng ký qua AddScoped/AddSingleton/AddTransient trong Program.cs và được inject qua constructor của controller hoặc service.', 2),
    (4, N'Razor View và ViewModel khác nhau ở điểm nào?',
        N'Razor View là tệp .cshtml chịu trách nhiệm render HTML; ViewModel là lớp C# chỉ chứa dữ liệu và quy tắc validation cần thiết cho View, tách biệt khỏi entity nghiệp vụ.', 2),
    (4, N'SignalR dùng để làm gì trong ứng dụng web?',
        N'SignalR là thư viện cho phép server đẩy thông điệp thời gian thực tới client qua WebSocket (hoặc fallback), thường dùng cho chat, thông báo và cập nhật tiến trình.', 2),

    -- PRO192 — Lập trình hướng đối tượng
    (5, N'Bốn đặc tính cốt lõi của OOP là gì?',
        N'Bốn đặc tính của OOP gồm: đóng gói (encapsulation), kế thừa (inheritance), đa hình (polymorphism) và trừu tượng hoá (abstraction).', 4),
    (5, N'Interface và abstract class khác nhau ra sao trong C#?',
        N'Interface chỉ khai báo hành vi và một lớp có thể triển khai nhiều interface; abstract class có thể chứa cả phương thức trừu tượng lẫn cài đặt sẵn nhưng một lớp chỉ được kế thừa một abstract class.', 4),

    -- CSI104 — Nhập môn ngành CNTT
    (6, N'CPU và RAM khác nhau như thế nào?',
        N'CPU là bộ xử lý trung tâm, thực thi lệnh; RAM là bộ nhớ truy cập ngẫu nhiên, lưu tạm dữ liệu và lệnh đang chạy. Dữ liệu RAM mất khi tắt máy, CPU không lưu trữ dữ liệu lâu dài.', 6),
    (6, N'Phần mềm hệ thống khác phần mềm ứng dụng ra sao?',
        N'Phần mềm hệ thống (như hệ điều hành, driver) quản lý tài nguyên phần cứng và cung cấp nền tảng cho phần mềm khác; phần mềm ứng dụng phục vụ tác vụ cụ thể của người dùng cuối.', 6),

    -- SWE201 — Nhập môn kỹ thuật phần mềm
    (7, N'Vòng đời phát triển phần mềm (SDLC) gồm các giai đoạn nào?',
        N'SDLC thường gồm các giai đoạn: phân tích yêu cầu, thiết kế, lập trình, kiểm thử, triển khai và bảo trì.', 5),
    (7, N'Agile khác mô hình thác nước (Waterfall) như thế nào?',
        N'Waterfall thực hiện các giai đoạn tuần tự, hoàn tất giai đoạn trước rồi mới sang giai đoạn sau; Agile lặp theo các iteration ngắn, giao sản phẩm gia tăng và chấp nhận thay đổi yêu cầu liên tục.', 5),

    -- VNR202 — Lịch sử Đảng Cộng sản Việt Nam
    (8, N'Đảng Cộng sản Việt Nam được thành lập vào ngày tháng năm nào và ở đâu?',
        N'Đảng Cộng sản Việt Nam được thành lập ngày 3 tháng 2 năm 1930 tại Hương Cảng (Hồng Kông, Trung Quốc) thông qua Hội nghị hợp nhất ba tổ chức cộng sản, do Nguyễn Ái Quốc chủ trì.', 5),
    (8, N'Cương lĩnh chính trị đầu tiên của Đảng do ai soạn thảo và xác định những nội dung cốt lõi gì?',
        N'Cương lĩnh chính trị đầu tiên do Nguyễn Ái Quốc soạn thảo, xác định đường lối cách mạng Việt Nam là tiến hành cách mạng tư sản dân quyền và thổ địa cách mạng để đi tới xã hội cộng sản, với hai nhiệm vụ chiến lược là chống đế quốc và chống phong kiến, do giai cấp công nhân lãnh đạo thông qua Đảng.', 5),
    (8, N'Cách mạng Tháng Tám năm 1945 thành công có ý nghĩa lịch sử như thế nào?',
        N'Cách mạng Tháng Tám năm 1945 đập tan ách thống trị của thực dân Pháp và phát xít Nhật, lật đổ chế độ phong kiến, lập nên nước Việt Nam Dân chủ Cộng hoà ngày 2 tháng 9 năm 1945; mở ra kỷ nguyên độc lập dân tộc gắn liền với chủ nghĩa xã hội.', 5),
    (8, N'Đại hội đại biểu toàn quốc lần thứ VI của Đảng (năm 1986) có ý nghĩa gì?',
        N'Đại hội VI (tháng 12 năm 1986) khởi xướng đường lối Đổi mới toàn diện, chuyển từ nền kinh tế kế hoạch hoá tập trung bao cấp sang nền kinh tế hàng hoá nhiều thành phần vận hành theo cơ chế thị trường có sự quản lý của Nhà nước, theo định hướng xã hội chủ nghĩa.', 5),
    (8, N'Tư tưởng Hồ Chí Minh là gì và có vai trò như thế nào đối với cách mạng Việt Nam?',
        N'Tư tưởng Hồ Chí Minh là hệ thống quan điểm toàn diện và sâu sắc về những vấn đề cơ bản của cách mạng Việt Nam, kết quả của sự vận dụng và phát triển sáng tạo chủ nghĩa Mác – Lênin vào điều kiện cụ thể của Việt Nam, kế thừa tinh hoa văn hoá dân tộc và nhân loại; cùng với chủ nghĩa Mác – Lênin, đây là nền tảng tư tưởng và kim chỉ nam cho hành động của Đảng.', 5);
END
GO


/* =========================================================
   Seed: VNR202 benchmark questions and gold chunks
   Source: curated 50-question ground-truth set for Lich su Dang.
   ========================================================= */
DECLARE @Vnr202SubjectId INT = (SELECT TOP (1) Id FROM dbo.Subjects WHERE SubjectCode = N'VNR202');
DECLARE @Vnr202TeacherId INT = COALESCE(
    (SELECT TOP (1) UserId FROM dbo.SubjectEnrollments WHERE SubjectId = @Vnr202SubjectId AND RoleInClass = N'Teacher' ORDER BY UserId),
    (SELECT TOP (1) Id FROM dbo.Users WHERE Role = N'Teacher' ORDER BY Id),
    (SELECT TOP (1) Id FROM dbo.Users ORDER BY Id)
);

IF @Vnr202SubjectId IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dbo.Documents WHERE SubjectId = @Vnr202SubjectId AND StoredFileName = N'vnr202-lich-su-dang-benchmark-seed.pdf')
    BEGIN
        INSERT INTO dbo.Documents
            (SubjectId, Title, OriginalFileName, StoredFileName, FilePath, FileType, FileSizeBytes, UploadedBy, Status, UploadedAt, IndexedAt, IsSystemManaged)
        VALUES
            (@Vnr202SubjectId,
             N'Lịch sử Đảng Cộng sản Việt Nam - benchmark seed',
             N'VNR202_LichSuDang_Benchmark.pdf',
             N'vnr202-lich-su-dang-benchmark-seed.pdf',
             N'App_Data/SeedDocuments/VNR202_LichSuDang_Benchmark.pdf',
             N'PDF',
             0,
             @Vnr202TeacherId,
             N'Indexed',
             SYSUTCDATETIME(),
             SYSUTCDATETIME(),
             1);
    END;

    UPDATE dbo.Documents
    SET IsSystemManaged = 1
    WHERE SubjectId = @Vnr202SubjectId
      AND StoredFileName = N'vnr202-lich-su-dang-benchmark-seed.pdf';

    DECLARE @Vnr202DocumentId INT = (
        SELECT TOP (1) Id
        FROM dbo.Documents
        WHERE SubjectId = @Vnr202SubjectId
          AND StoredFileName = N'vnr202-lich-su-dang-benchmark-seed.pdf'
        ORDER BY Id
    );

    DECLARE @Vnr202Questions TABLE
    (
        Ordinal INT NOT NULL PRIMARY KEY,
        Question NVARCHAR(MAX) NOT NULL,
        GroundTruthAnswer NVARCHAR(MAX) NOT NULL,
        IsAnswerable BIT NOT NULL
    );

    INSERT INTO @Vnr202Questions (Ordinal, Question, GroundTruthAnswer, IsAnswerable)
    VALUES
    (1, N'Đối tượng nghiên cứu của môn học Lịch sử Đảng Cộng sản Việt Nam là gì?', N'Đối tượng nghiên cứu của môn học là sự ra đời, phát triển và hoạt động lãnh đạo của Đảng qua các thời kỳ lịch sử, hệ thống các sự kiện lịch sử Đảng, làm sáng tỏ nội dung, tính chất, bản chất của các sự kiện đó gắn liền với sự lãnh đạo của Đảng.', 1),
    (2, N'Khi nghiên cứu Lịch sử Đảng, cần phân biệt sự kiện lịch sử Đảng gắn trực tiếp với sự lãnh đạo của Đảng với nội dung nào?', N'Cần phân biệt sự kiện lịch sử Đảng với sự kiện lịch sử dân tộc và lịch sử quân sự trong cùng thời kỳ, thời điểm lịch sử.', 1),
    (3, N'Giáo trình nêu rõ Lịch sử Đảng có đối tượng nghiên cứu sâu sắc về nội dung nào của Đảng bên cạnh Cương lĩnh và đường lối?', N'Đối tượng nghiên cứu còn là quá trình Đảng lãnh đạo, thể chế hóa Cương lĩnh, đường lối thành chủ trương, chính sách lớn và chỉ đạo thực tiễn, cơ sở lý luận, thực tiễn và giá trị hiện thực của đường lối trong tiến trình phát triển của cách mạng.', 1),
    (4, N'Chức năng nhận thức của khoa học Lịch sử Đảng giúp người học làm sáng tỏ nội dung gì trong sự nghiệp giải phóng dân tộc và xây dựng đất nước?', N'Nhận thức đầy đủ, hệ thống những tri thức lịch sử về sự lãnh đạo, đấu tranh và cầm quyền của Đảng; quy luật ra đời và phát triển của Đảng; quy luật đi lên chủ nghĩa xã hội ở Việt Nam.', 1),
    (5, N'Chức năng giáo dục của môn học Lịch sử Đảng hướng tới việc bồi đắp điều gì cho thế hệ trẻ và người học?', N'Giáo dục sâu sắc tinh thần yêu nước, ý thức, niềm tự hào, tự tôn, ý chí tự lực tự cường dân tộc; giáo dục lý tưởng cách mạng với mục tiêu độc lập dân tộc và chủ nghĩa xã hội.', 1),
    (6, N'Ngoài chức năng nhận thức và giáo dục, khoa học Lịch sử Đảng còn có chức năng cơ bản nào khác?', N'Đó chính là chức năng dự báo và phê phán.', 1),
    (7, N'Trong các nhiệm vụ của khoa học Lịch sử Đảng, nhiệm vụ hàng đầu là gì?', N'Khẳng định, chứng minh giá trị khoa học và hiện thực của những mục tiêu chiến lược và sách lược cách mạng mà Đảng đề ra trong Cương lĩnh, đường lối từ khi Đảng ra đời và suốt quá trình lãnh đạo cách mạng.', 1),
    (8, N'Khoa học Lịch sử Đảng sử dụng những phương pháp cụ thể nào làm phương pháp cơ bản để nghiên cứu?', N'Phương pháp lịch sử và phương pháp logic.', 1),
    (9, N'Phương pháp lịch sử yêu cầu điều gì khi tái hiện tiến trình phát triển của Lịch sử Đảng?', N'Đòi hỏi nghiên cứu thấu đáo mọi chi tiết lịch sử để hiểu vai trò, tâm lý, tình cảm của quần chúng, hiểu điểm và diện, tổng thể đến cụ thể, tái hiện lịch sử đúng như nó đã diễn ra trong không gian, thời gian và địa điểm cụ thể.', 1),
    (10, N'Nhiệm vụ tổng kết lịch sử của khoa học Lịch sử Đảng nhằm mục đích gì?', N'Nhằm làm rõ kinh nghiệm, bài học, quy luật và những vấn đề lý luận của cách mạng Việt Nam, từ đó nâng cao năng lực lãnh đạo, quản lý và vận dụng lý luận vào thực tiễn hiện nay.', 1),
    (11, N'Sự kiện thực dân Pháp nổ súng xâm lược Việt Nam diễn ra vào ngày tháng năm nào và ở đâu?', N'Ngày 1/9/1858 tại cửa biển Đà Nẵng.', 1),
    (12, N'Để chia rẽ khối đoàn kết dân tộc của Việt Nam, thực dân Pháp đã dùng chính sách ''chia để trị'' bằng cách chia đất nước thành ba kỳ với các chế độ chính trị khác nhau là những kỳ nào?', N'Bắc Kỳ (nửa bảo hộ), Trung Kỳ (bảo hộ) và Nam Kỳ (thuộc địa). Các chế độ chính trị khác nhau này nằm trong Liên bang Đông Dương thuộc Pháp.', 1),
    (13, N'Thực dân Pháp bắt đầu tiến hành các cuộc khai thác thuộc địa quy mô lớn ở Việt Nam từ năm nào?', N'Từ năm 1897, thực dân Pháp bắt đầu tiến hành các cuộc khai thác thuộc địa quy mô lớn: Cuộc khai thác thuộc địa lần thứ nhất (1897 - 1914) và cuộc khai thác thuộc địa lần thứ hai (1919 - 1929).', 1),
    (14, N'Dưới chế độ cai trị của thực dân Pháp, giai cấp nông dân chiếm khoảng bao nhiêu phần trăm dân số và có địa vị ra sao?', N'Giai cấp nông dân chiếm số lượng đông đảo nhất, khoảng hơn 90% dân số. Đây là giai cấp bị áp bức, bóc lột nặng nề nhất, có mâu thuẫn sâu sắc với thực dân Pháp xâm lược và phong kiến địa chủ.', 1),
    (15, N'Cuộc khởi nghĩa Yên Bái do Việt Nam Quốc dân Đảng lãnh đạo nổ ra vào thời gian nào và có kết quả ra sao?', N'Cuộc khởi nghĩa nổ ra vào tháng 2/1930 dưới sự lãnh đạo của Nguyễn Thái Học, tuy oanh liệt nhưng nhanh chóng bị thực dân Pháp đàn áp dã man và thất bại.', 1),
    (50, N'Kế hoạch Nhà nước 5 năm lần thứ nhất xây dựng chủ nghĩa xã hội ở miền Bắc xã hội chủ nghĩa diễn ra trong giai đoạn nào?', N'Kế hoạch Nhà nước 5 năm lần thứ nhất diễn ra từ năm 1961 đến năm 1965.', 1),
    (51, N'Mức lương tối thiểu, chế độ phụ cấp và thời giờ làm việc định mức của công nhân xưởng cơ khí và phu mỏ tại các đồn điền cao su thuộc sở hữu của tư bản Pháp trong cuộc khai thác thuộc địa lần thứ hai (1919 - 1929) là bao nhiêu?', N'Không có thông tin trong tài liệu.', 0),
    (52, N'Tiểu sử chi tiết, quá trình học tập tại nước ngoài và hoạt động cách mạng trước năm 1930 của tất cả các đại biểu chính thức tham dự Hội nghị hợp nhất thành lập Đảng tại Cửu Long (Hồng Kông) vào đầu năm 1930 là gì?', N'Không có thông tin trong tài liệu.', 0),
    (53, N'Thống kê chi tiết về số lượng máy in thủ công, sản lượng giấy tiêu thụ và sơ đồ mạng lưới phân phát bí mật của tờ báo Búa liềm (cơ quan ngôn luận của Đông Dương Cộng sản Đảng) trong năm 1929?', N'Không có thông tin trong tài liệu.', 0),
    (54, N'Danh sách đầy đủ họ tên, chức vụ và nhiệm vụ cụ thể của từng thành viên trong phái đoàn Tổng hội Sinh viên Cứu quốc đã tổ chức và điều hành buổi mít tinh lịch sử tại Nhà hát Lớn Hà Nội vào ngày 17/8/1945?', N'Không có thông tin trong tài liệu.', 0);

    DELETE eq
    FROM dbo.EvaluationQuestions eq
    LEFT JOIN @Vnr202Questions q ON q.Question = eq.Question
    WHERE eq.SubjectId = @Vnr202SubjectId
      AND q.Ordinal IS NULL;

    MERGE dbo.EvaluationQuestions AS target
    USING @Vnr202Questions AS source
        ON target.SubjectId = @Vnr202SubjectId
       AND target.Question = source.Question
    WHEN MATCHED THEN
        UPDATE SET GroundTruthAnswer = source.GroundTruthAnswer, IsAnswerable = source.IsAnswerable, CreatedBy = @Vnr202TeacherId
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (SubjectId, Question, GroundTruthAnswer, IsAnswerable, CreatedBy)
        VALUES (@Vnr202SubjectId, source.Question, source.GroundTruthAnswer, source.IsAnswerable, @Vnr202TeacherId);

    DECLARE @Vnr202PageChunks TABLE
    (
        PageNumber INT NOT NULL PRIMARY KEY,
        Content NVARCHAR(MAX) NOT NULL,
        TokenCount INT NOT NULL
    );

    INSERT INTO @Vnr202PageChunks (PageNumber, Content, TokenCount)
    VALUES
    (13, N'Trang 13 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Đối tượng nghiên cứu của môn học Lịch sử Đảng Cộng sản Việt Nam là gì? Đáp án chuẩn: Đối tượng nghiên cứu của môn học là sự ra đời, phát triển và hoạt động lãnh đạo của Đảng qua các thời kỳ lịch sử, hệ thống các sự kiện lịch sử Đảng, làm sáng tỏ nội dung, tính chất, bản chất của các sự kiện đó gắn liền với sự lãnh đạo của Đảng. Câu hỏi benchmark: Khi nghiên cứu Lịch sử Đảng, cần phân biệt sự kiện lịch sử Đảng gắn trực tiếp với sự lãnh đạo của Đảng với nội dung nào? Đáp án chuẩn: Cần phân biệt sự kiện lịch sử Đảng với sự kiện lịch sử dân tộc và lịch sử quân sự trong cùng thời kỳ, thời điểm lịch sử.', 167),
    (14, N'Trang 14 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Đối tượng nghiên cứu của môn học Lịch sử Đảng Cộng sản Việt Nam là gì? Đáp án chuẩn: Đối tượng nghiên cứu của môn học là sự ra đời, phát triển và hoạt động lãnh đạo của Đảng qua các thời kỳ lịch sử, hệ thống các sự kiện lịch sử Đảng, làm sáng tỏ nội dung, tính chất, bản chất của các sự kiện đó gắn liền với sự lãnh đạo của Đảng. Câu hỏi benchmark: Khi nghiên cứu Lịch sử Đảng, cần phân biệt sự kiện lịch sử Đảng gắn trực tiếp với sự lãnh đạo của Đảng với nội dung nào? Đáp án chuẩn: Cần phân biệt sự kiện lịch sử Đảng với sự kiện lịch sử dân tộc và lịch sử quân sự trong cùng thời kỳ, thời điểm lịch sử. Câu hỏi benchmark: Giáo trình nêu rõ Lịch sử Đảng có đối tượng nghiên cứu sâu sắc về nội dung nào của Đảng bên cạnh Cương lĩnh và đường lối? Đáp án chuẩn: Đối tượng nghiên cứu còn là quá trình Đảng lãnh đạo, thể chế hóa Cương lĩnh, đường lối thành chủ trương, chính sách lớn và chỉ đạo thực tiễn, cơ sở lý luận, thực tiễn và giá trị hiện thực của đường lối trong tiến trình phát triển của cách mạng.', 267),
    (15, N'Trang 15 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Giáo trình nêu rõ Lịch sử Đảng có đối tượng nghiên cứu sâu sắc về nội dung nào của Đảng bên cạnh Cương lĩnh và đường lối? Đáp án chuẩn: Đối tượng nghiên cứu còn là quá trình Đảng lãnh đạo, thể chế hóa Cương lĩnh, đường lối thành chủ trương, chính sách lớn và chỉ đạo thực tiễn, cơ sở lý luận, thực tiễn và giá trị hiện thực của đường lối trong tiến trình phát triển của cách mạng.', 111),
    (17, N'Trang 17 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Chức năng nhận thức của khoa học Lịch sử Đảng giúp người học làm sáng tỏ nội dung gì trong sự nghiệp giải phóng dân tộc và xây dựng đất nước? Đáp án chuẩn: Nhận thức đầy đủ, hệ thống những tri thức lịch sử về sự lãnh đạo, đấu tranh và cầm quyền của Đảng; quy luật ra đời và phát triển của Đảng; quy luật đi lên chủ nghĩa xã hội ở Việt Nam. Câu hỏi benchmark: Ngoài chức năng nhận thức và giáo dục, khoa học Lịch sử Đảng còn có chức năng cơ bản nào khác? Đáp án chuẩn: Đó chính là chức năng dự báo và phê phán.', 143),
    (18, N'Trang 18 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Chức năng nhận thức của khoa học Lịch sử Đảng giúp người học làm sáng tỏ nội dung gì trong sự nghiệp giải phóng dân tộc và xây dựng đất nước? Đáp án chuẩn: Nhận thức đầy đủ, hệ thống những tri thức lịch sử về sự lãnh đạo, đấu tranh và cầm quyền của Đảng; quy luật ra đời và phát triển của Đảng; quy luật đi lên chủ nghĩa xã hội ở Việt Nam.', 101),
    (19, N'Trang 19 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Chức năng giáo dục của môn học Lịch sử Đảng hướng tới việc bồi đắp điều gì cho thế hệ trẻ và người học? Đáp án chuẩn: Giáo dục sâu sắc tinh thần yêu nước, ý thức, niềm tự hào, tự tôn, ý chí tự lực tự cường dân tộc; giáo dục lý tưởng cách mạng với mục tiêu độc lập dân tộc và chủ nghĩa xã hội.', 89),
    (20, N'Trang 20 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Chức năng giáo dục của môn học Lịch sử Đảng hướng tới việc bồi đắp điều gì cho thế hệ trẻ và người học? Đáp án chuẩn: Giáo dục sâu sắc tinh thần yêu nước, ý thức, niềm tự hào, tự tôn, ý chí tự lực tự cường dân tộc; giáo dục lý tưởng cách mạng với mục tiêu độc lập dân tộc và chủ nghĩa xã hội. Câu hỏi benchmark: Ngoài chức năng nhận thức và giáo dục, khoa học Lịch sử Đảng còn có chức năng cơ bản nào khác? Đáp án chuẩn: Đó chính là chức năng dự báo và phê phán.', 131),
    (21, N'Trang 21 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Trong các nhiệm vụ của khoa học Lịch sử Đảng, nhiệm vụ hàng đầu là gì? Đáp án chuẩn: Khẳng định, chứng minh giá trị khoa học và hiện thực của những mục tiêu chiến lược và sách lược cách mạng mà Đảng đề ra trong Cương lĩnh, đường lối từ khi Đảng ra đời và suốt quá trình lãnh đạo cách mạng.', 88),
    (22, N'Trang 22 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Trong các nhiệm vụ của khoa học Lịch sử Đảng, nhiệm vụ hàng đầu là gì? Đáp án chuẩn: Khẳng định, chứng minh giá trị khoa học và hiện thực của những mục tiêu chiến lược và sách lược cách mạng mà Đảng đề ra trong Cương lĩnh, đường lối từ khi Đảng ra đời và suốt quá trình lãnh đạo cách mạng. Câu hỏi benchmark: Nhiệm vụ tổng kết lịch sử của khoa học Lịch sử Đảng nhằm mục đích gì? Đáp án chuẩn: Nhằm làm rõ kinh nghiệm, bài học, quy luật và những vấn đề lý luận của cách mạng Việt Nam, từ đó nâng cao năng lực lãnh đạo, quản lý và vận dụng lý luận vào thực tiễn hiện nay.', 158),
    (23, N'Trang 23 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Nhiệm vụ tổng kết lịch sử của khoa học Lịch sử Đảng nhằm mục đích gì? Đáp án chuẩn: Nhằm làm rõ kinh nghiệm, bài học, quy luật và những vấn đề lý luận của cách mạng Việt Nam, từ đó nâng cao năng lực lãnh đạo, quản lý và vận dụng lý luận vào thực tiễn hiện nay.', 81),
    (25, N'Trang 25 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Khoa học Lịch sử Đảng sử dụng những phương pháp cụ thể nào làm phương pháp cơ bản để nghiên cứu? Đáp án chuẩn: Phương pháp lịch sử và phương pháp logic.', 54),
    (26, N'Trang 26 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Khoa học Lịch sử Đảng sử dụng những phương pháp cụ thể nào làm phương pháp cơ bản để nghiên cứu? Đáp án chuẩn: Phương pháp lịch sử và phương pháp logic. Câu hỏi benchmark: Phương pháp lịch sử yêu cầu điều gì khi tái hiện tiến trình phát triển của Lịch sử Đảng? Đáp án chuẩn: Đòi hỏi nghiên cứu thấu đáo mọi chi tiết lịch sử để hiểu vai trò, tâm lý, tình cảm của quần chúng, hiểu điểm và diện, tổng thể đến cụ thể, tái hiện lịch sử đúng như nó đã diễn ra trong không gian, thời gian và địa điểm cụ thể.', 141),
    (27, N'Trang 27 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Khoa học Lịch sử Đảng sử dụng những phương pháp cụ thể nào làm phương pháp cơ bản để nghiên cứu? Đáp án chuẩn: Phương pháp lịch sử và phương pháp logic. Câu hỏi benchmark: Phương pháp lịch sử yêu cầu điều gì khi tái hiện tiến trình phát triển của Lịch sử Đảng? Đáp án chuẩn: Đòi hỏi nghiên cứu thấu đáo mọi chi tiết lịch sử để hiểu vai trò, tâm lý, tình cảm của quần chúng, hiểu điểm và diện, tổng thể đến cụ thể, tái hiện lịch sử đúng như nó đã diễn ra trong không gian, thời gian và địa điểm cụ thể.', 141),
    (38, N'Trang 38 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Sự kiện thực dân Pháp nổ súng xâm lược Việt Nam diễn ra vào ngày tháng năm nào và ở đâu? Đáp án chuẩn: Ngày 1/9/1858 tại cửa biển Đà Nẵng.', 50),
    (39, N'Trang 39 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Sự kiện thực dân Pháp nổ súng xâm lược Việt Nam diễn ra vào ngày tháng năm nào và ở đâu? Đáp án chuẩn: Ngày 1/9/1858 tại cửa biển Đà Nẵng. Câu hỏi benchmark: Để chia rẽ khối đoàn kết dân tộc của Việt Nam, thực dân Pháp đã dùng chính sách ''chia để trị'' bằng cách chia đất nước thành ba kỳ với các chế độ chính trị khác nhau là những kỳ nào? Đáp án chuẩn: Bắc Kỳ (nửa bảo hộ), Trung Kỳ (bảo hộ) và Nam Kỳ (thuộc địa). Các chế độ chính trị khác nhau này nằm trong Liên bang Đông Dương thuộc Pháp. Câu hỏi benchmark: Thực dân Pháp bắt đầu tiến hành các cuộc khai thác thuộc địa quy mô lớn ở Việt Nam từ năm nào? Đáp án chuẩn: Từ năm 1897, thực dân Pháp bắt đầu tiến hành các cuộc khai thác thuộc địa quy mô lớn: Cuộc khai thác thuộc địa lần thứ nhất (1897 - 1914) và cuộc khai thác thuộc địa lần thứ hai (1919 - 1929).', 219),
    (40, N'Trang 40 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Để chia rẽ khối đoàn kết dân tộc của Việt Nam, thực dân Pháp đã dùng chính sách ''chia để trị'' bằng cách chia đất nước thành ba kỳ với các chế độ chính trị khác nhau là những kỳ nào? Đáp án chuẩn: Bắc Kỳ (nửa bảo hộ), Trung Kỳ (bảo hộ) và Nam Kỳ (thuộc địa). Các chế độ chính trị khác nhau này nằm trong Liên bang Đông Dương thuộc Pháp.', 100),
    (41, N'Trang 41 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Thực dân Pháp bắt đầu tiến hành các cuộc khai thác thuộc địa quy mô lớn ở Việt Nam từ năm nào? Đáp án chuẩn: Từ năm 1897, thực dân Pháp bắt đầu tiến hành các cuộc khai thác thuộc địa quy mô lớn: Cuộc khai thác thuộc địa lần thứ nhất (1897 - 1914) và cuộc khai thác thuộc địa lần thứ hai (1919 - 1929). Câu hỏi benchmark: Dưới chế độ cai trị của thực dân Pháp, giai cấp nông dân chiếm khoảng bao nhiêu phần trăm dân số và có địa vị ra sao? Đáp án chuẩn: Giai cấp nông dân chiếm số lượng đông đảo nhất, khoảng hơn 90% dân số. Đây là giai cấp bị áp bức, bóc lột nặng nề nhất, có mâu thuẫn sâu sắc với thực dân Pháp xâm lược và phong kiến địa chủ.', 177),
    (42, N'Trang 42 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Dưới chế độ cai trị của thực dân Pháp, giai cấp nông dân chiếm khoảng bao nhiêu phần trăm dân số và có địa vị ra sao? Đáp án chuẩn: Giai cấp nông dân chiếm số lượng đông đảo nhất, khoảng hơn 90% dân số. Đây là giai cấp bị áp bức, bóc lột nặng nề nhất, có mâu thuẫn sâu sắc với thực dân Pháp xâm lược và phong kiến địa chủ.', 96),
    (45, N'Trang 45 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Cuộc khởi nghĩa Yên Bái do Việt Nam Quốc dân Đảng lãnh đạo nổ ra vào thời gian nào và có kết quả ra sao? Đáp án chuẩn: Cuộc khởi nghĩa nổ ra vào tháng 2/1930 dưới sự lãnh đạo của Nguyễn Thái Học, tuy oanh liệt nhưng nhanh chóng bị thực dân Pháp đàn áp dã man và thất bại.', 84),
    (48, N'Trang 48 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Cuộc khởi nghĩa Yên Bái do Việt Nam Quốc dân Đảng lãnh đạo nổ ra vào thời gian nào và có kết quả ra sao? Đáp án chuẩn: Cuộc khởi nghĩa nổ ra vào tháng 2/1930 dưới sự lãnh đạo của Nguyễn Thái Học, tuy oanh liệt nhưng nhanh chóng bị thực dân Pháp đàn áp dã man và thất bại. Câu hỏi benchmark: Sự thất bại của các phong trào yêu nước chống Pháp cuối thế kỷ XIX, đầu thế kỷ XX (theo xu hướng phong kiến và tư sản) chứng tỏ điều gì về đường lối cứu nước lúc bấy giờ? Đáp án chuẩn: Sự thất bại đó chứng tỏ đường lối cứu nước theo khuynh hướng phong kiến (Cần Vương) và khuynh hướng dân chủ tư sản, tiểu tư sản đều lần lượt bị thất bại trước yêu cầu lịch sử, dẫn đến khủng hoảng sâu sắc về đường lối và giai cấp lãnh đạo.', 194),
    (49, N'Trang 49 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Sự thất bại của các phong trào yêu nước chống Pháp cuối thế kỷ XIX, đầu thế kỷ XX (theo xu hướng phong kiến và tư sản) chứng tỏ điều gì về đường lối cứu nước lúc bấy giờ? Đáp án chuẩn: Sự thất bại đó chứng tỏ đường lối cứu nước theo khuynh hướng phong kiến (Cần Vương) và khuynh hướng dân chủ tư sản, tiểu tư sản đều lần lượt bị thất bại trước yêu cầu lịch sử, dẫn đến khủng hoảng sâu sắc về đường lối và giai cấp lãnh đạo. Câu hỏi benchmark: Nguyễn Tất Thành quyết định ra đi tìm đường cứu nước vào năm nào để tìm kiếm con đường giải phóng dân tộc mới? Đáp án chuẩn: Năm 1911, Nguyễn Tất Thành quyết định ra đi tìm đường cứu nước, giải phóng dân tộc.', 179),
    (50, N'Trang 50 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Nguyễn Tất Thành quyết định ra đi tìm đường cứu nước vào năm nào để tìm kiếm con đường giải phóng dân tộc mới? Đáp án chuẩn: Năm 1911, Nguyễn Tất Thành quyết định ra đi tìm đường cứu nước, giải phóng dân tộc. Câu hỏi benchmark: Bản ''Yêu sách của nhân dân An Nam'' gồm 8 điểm được Nguyễn Ái Quốc gửi tới Hội nghị Versailles vào ngày tháng năm nào? Đáp án chuẩn: Ngày 18/6/1919, Nguyễn Ái Quốc đại diện những người An Nam yêu nước gửi tới Hội nghị bản Yêu sách của nhân dân An Nam đòi các quyền tự do tối thiểu. Câu hỏi benchmark: Nguyễn Ái Quốc đọc bản Sơ thảo lần thứ nhất những luận cương về vấn đề dân tộc và vấn đề thuộc địa của Lênin vào thời gian nào? Đáp án chuẩn: Tháng 7/1920, Người đọc bản Sơ thảo lần thứ nhất những luận cương về vấn đề dân tộc và vấn đề thuộc địa đăng trên báo L''Humanité.', 216),
    (51, N'Trang 51 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Bản ''Yêu sách của nhân dân An Nam'' gồm 8 điểm được Nguyễn Ái Quốc gửi tới Hội nghị Versailles vào ngày tháng năm nào? Đáp án chuẩn: Ngày 18/6/1919, Nguyễn Ái Quốc đại diện những người An Nam yêu nước gửi tới Hội nghị bản Yêu sách của nhân dân An Nam đòi các quyền tự do tối thiểu. Câu hỏi benchmark: Nguyễn Ái Quốc đọc bản Sơ thảo lần thứ nhất những luận cương về vấn đề dân tộc và vấn đề thuộc địa của Lênin vào thời gian nào? Đáp án chuẩn: Tháng 7/1920, Người đọc bản Sơ thảo lần thứ nhất những luận cương về vấn đề dân tộc và vấn đề thuộc địa đăng trên báo L''Humanité. Câu hỏi benchmark: Tại Đại hội lần thứ XVIII của Đảng Xã hội Pháp (12/1920), Nguyễn Ái Quốc đã có quyết định lịch sử nào đánh dấu bước chuyển từ chủ nghĩa yêu nước sang chủ nghĩa cộng sản? Đáp án chuẩn: Người đã bỏ phiếu tán thành gia nhập Quốc tế III (Quốc tế Cộng sản) và tham gia thành lập Phân bộ Pháp của Quốc tế Cộng sản (tức Đảng Cộng sản Pháp).', 247),
    (52, N'Trang 52 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Tại Đại hội lần thứ XVIII của Đảng Xã hội Pháp (12/1920), Nguyễn Ái Quốc đã có quyết định lịch sử nào đánh dấu bước chuyển từ chủ nghĩa yêu nước sang chủ nghĩa cộng sản? Đáp án chuẩn: Người đã bỏ phiếu tán thành gia nhập Quốc tế III (Quốc tế Cộng sản) và tham gia thành lập Phân bộ Pháp của Quốc tế Cộng sản (tức Đảng Cộng sản Pháp).', 99),
    (53, N'Trang 53 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Trong tác phẩm ''Đường cách mệnh'' (1927), Nguyễn Ái Quốc nhấn mạnh yếu tố cốt lõi nào để cách mạng thành công? Đáp án chuẩn: Người khẳng định: ''Đảng muốn vững thì phải có chủ nghĩa làm cốt, trong đảng ai cũng phải hiểu, ai cũng phải theo chủ nghĩa ấy. Đảng mà không có chủ nghĩa cũng giống như người không có trí khôn, tàu không có bàn chỉ nam.'' Chủ nghĩa đó là chủ nghĩa Mác - Lênin.', 112),
    (54, N'Trang 54 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Trong tác phẩm ''Đường cách mệnh'' (1927), Nguyễn Ái Quốc nhấn mạnh yếu tố cốt lõi nào để cách mạng thành công? Đáp án chuẩn: Người khẳng định: ''Đảng muốn vững thì phải có chủ nghĩa làm cốt, trong đảng ai cũng phải hiểu, ai cũng phải theo chủ nghĩa ấy. Đảng mà không có chủ nghĩa cũng giống như người không có trí khôn, tàu không có bàn chỉ nam.'' Chủ nghĩa đó là chủ nghĩa Mác - Lênin.', 112),
    (55, N'Trang 55 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Hội Việt Nam Cách mạng Thanh niên do Nguyễn Ái Quốc sáng lập vào tháng năm nào và đặt trụ sở tại đâu? Đáp án chuẩn: Thành lập tháng 6/1925 tại Quảng Châu (Trung Quốc), cơ quan ngôn luận là tờ báo Thanh niên.', 68),
    (56, N'Trang 56 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Hội Việt Nam Cách mạng Thanh niên do Nguyễn Ái Quốc sáng lập vào tháng năm nào và đặt trụ sở tại đâu? Đáp án chuẩn: Thành lập tháng 6/1925 tại Quảng Châu (Trung Quốc), cơ quan ngôn luận là tờ báo Thanh niên.', 68),
    (58, N'Trang 58 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Tổ chức Đông Dương Cộng sản Đảng được thành lập vào thời gian nào và xuất bản tờ báo nào làm cơ quan ngôn luận? Đáp án chuẩn: Đông Dương Cộng sản Đảng được thành lập vào tháng 6/1929, quyết định lấy cờ đỏ búa liềm làm Đảng kỳ và xuất bản báo ''Búa liềm'' làm cơ quan ngôn luận.', 85),
    (59, N'Trang 59 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Tổ chức Đông Dương Cộng sản Đảng được thành lập vào thời gian nào và xuất bản tờ báo nào làm cơ quan ngôn luận? Đáp án chuẩn: Đông Dương Cộng sản Đảng được thành lập vào tháng 6/1929, quyết định lấy cờ đỏ búa liềm làm Đảng kỳ và xuất bản báo ''Búa liềm'' làm cơ quan ngôn luận.', 85),
    (61, N'Trang 61 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Hội nghị thành lập Đảng Cộng sản Việt Nam đầu năm 1930 diễn ra tại địa điểm cụ thể nào? Đáp án chuẩn: Hội nghị được tiến hành tại Cửu Long (Hồng Kông, Trung Quốc) dưới sự chủ trì của đồng chí Nguyễn Ái Quốc. Câu hỏi benchmark: Nguyễn Ái Quốc viết trong Báo cáo gửi Quốc tế Cộng sản ngày 18/2/1930 rằng Hội nghị thành lập Đảng bắt đầu họp vào ngày nào? Đáp án chuẩn: Trong báo cáo, Người viết: ''Chúng tôi họp vào ngày mồng 6/1.'' Tức là ngày 6/1/1930. Câu hỏi benchmark: Đại biểu của những tổ chức cộng sản nào đã tham gia Hội nghị thành lập Đảng đầu năm 1930? Đáp án chuẩn: Hội nghị gồm các đại biểu của Đông Dương Cộng sản Đảng (Trịnh Đình Cửu, Nguyễn Đức Cảnh) và An Nam Cộng sản Đảng (Châu Văn Liêm, Nguyễn Thiệu). Câu hỏi benchmark: Tên gọi chính thức của Đảng ta được quyết định tại Hội nghị thành lập Đảng (đầu năm 1930) là gì? Đáp án chuẩn: Được sự thống nhất cao, Hội nghị quyết định định tên Đảng là Đảng Cộng sản Việt Nam.', 249),
    (62, N'Trang 62 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Hội nghị thành lập Đảng Cộng sản Việt Nam đầu năm 1930 diễn ra tại địa điểm cụ thể nào? Đáp án chuẩn: Hội nghị được tiến hành tại Cửu Long (Hồng Kông, Trung Quốc) dưới sự chủ trì của đồng chí Nguyễn Ái Quốc. Câu hỏi benchmark: Nguyễn Ái Quốc viết trong Báo cáo gửi Quốc tế Cộng sản ngày 18/2/1930 rằng Hội nghị thành lập Đảng bắt đầu họp vào ngày nào? Đáp án chuẩn: Trong báo cáo, Người viết: ''Chúng tôi họp vào ngày mồng 6/1.'' Tức là ngày 6/1/1930. Câu hỏi benchmark: Đại biểu của những tổ chức cộng sản nào đã tham gia Hội nghị thành lập Đảng đầu năm 1930? Đáp án chuẩn: Hội nghị gồm các đại biểu của Đông Dương Cộng sản Đảng (Trịnh Đình Cửu, Nguyễn Đức Cảnh) và An Nam Cộng sản Đảng (Châu Văn Liêm, Nguyễn Thiệu). Câu hỏi benchmark: Tên gọi chính thức của Đảng ta được quyết định tại Hội nghị thành lập Đảng (đầu năm 1930) là gì? Đáp án chuẩn: Được sự thống nhất cao, Hội nghị quyết định định tên Đảng là Đảng Cộng sản Việt Nam.', 249),
    (64, N'Trang 64 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Cương lĩnh chính trị đầu tiên của Đảng (đầu năm 1930) xác định nhiệm vụ cốt lõi về mặt xã hội là gì? Đáp án chuẩn: Về phương diện xã hội, Cương lĩnh xác định: a) Dân chúng được tự do tổ chức; b) Nam nữ bình quyền; c) Phổ thông giáo dục theo công nông hóa.', 80),
    (65, N'Trang 65 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Cương lĩnh chính trị đầu tiên của Đảng (đầu năm 1930) xác định nhiệm vụ cốt lõi về mặt xã hội là gì? Đáp án chuẩn: Về phương diện xã hội, Cương lĩnh xác định: a) Dân chúng được tự do tổ chức; b) Nam nữ bình quyền; c) Phổ thông giáo dục theo công nông hóa.', 80),
    (73, N'Trang 73 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Phong trào cách mạng 1930 - 1931 đạt đến đỉnh cao tại hai tỉnh nào của Việt Nam? Đáp án chuẩn: Tại vùng nông thôn hai tỉnh Nghệ An và Hà Tĩnh, hình thành nên các Xô viết tự quản của nhân dân (phong trào Xô viết Nghệ - Tĩnh).', 72),
    (74, N'Trang 74 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Phong trào cách mạng 1930 - 1931 đạt đến đỉnh cao tại hai tỉnh nào của Việt Nam? Đáp án chuẩn: Tại vùng nông thôn hai tỉnh Nghệ An và Hà Tĩnh, hình thành nên các Xô viết tự quản của nhân dân (phong trào Xô viết Nghệ - Tĩnh).', 72),
    (75, N'Trang 75 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Ban Chấp hành Trung ương Đảng quyết định đổi tên Đảng Cộng sản Việt Nam thành Đảng Cộng sản Đông Dương tại Hội nghị nào, vào thời gian nào? Đáp án chuẩn: Tại Hội nghị lần thứ nhất họp từ ngày 14 đến ngày 31/10/1930 tại Hương Cảng (Hồng Kông). Câu hỏi benchmark: Đồng chí Trần Phú được bầu làm Tổng Bí thư của Đảng Cộng sản Đông Dương vào thời gian nào? Đáp án chuẩn: Đồng chí Trần Phú được bầu làm Tổng Bí thư tại Hội nghị lần thứ nhất của Ban Chấp hành Trung ương Đảng vào tháng 10/1930.', 138),
    (76, N'Trang 76 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Ban Chấp hành Trung ương Đảng quyết định đổi tên Đảng Cộng sản Việt Nam thành Đảng Cộng sản Đông Dương tại Hội nghị nào, vào thời gian nào? Đáp án chuẩn: Tại Hội nghị lần thứ nhất họp từ ngày 14 đến ngày 31/10/1930 tại Hương Cảng (Hồng Kông).', 76),
    (78, N'Trang 78 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Đồng chí Trần Phú được bầu làm Tổng Bí thư của Đảng Cộng sản Đông Dương vào thời gian nào? Đáp án chuẩn: Đồng chí Trần Phú được bầu làm Tổng Bí thư tại Hội nghị lần thứ nhất của Ban Chấp hành Trung ương Đảng vào tháng 10/1930.', 72),
    (82, N'Trang 82 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Đại hội đại biểu lần thứ I của Đảng Cộng sản Đông Dương diễn ra vào thời gian nào và ở đâu? Đáp án chuẩn: Diễn ra vào tháng 3/1935 tại Ma Cao (Trung Quốc), đề ra ba nhiệm vụ trước mắt để phục hồi và phát triển phong trào cách mạng Đông Dương.', 76),
    (83, N'Trang 83 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Đại hội đại biểu lần thứ I của Đảng Cộng sản Đông Dương diễn ra vào thời gian nào và ở đâu? Đáp án chuẩn: Diễn ra vào tháng 3/1935 tại Ma Cao (Trung Quốc), đề ra ba nhiệm vụ trước mắt để phục hồi và phát triển phong trào cách mạng Đông Dương.', 76),
    (85, N'Trang 85 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Trong phong trào dân chủ 1936 - 1939, Đảng chủ trương thành lập Mặt trận nào để tập hợp rộng rãi quần chúng đấu tranh đòi tự do, cơm áo, hòa bình? Đáp án chuẩn: Mặt trận Thống nhất nhân dân phản đế Đông Dương (sau đổi thành Mặt trận Dân chủ Đông Dương vào năm 1938).', 82),
    (86, N'Trang 86 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Trong phong trào dân chủ 1936 - 1939, Đảng chủ trương thành lập Mặt trận nào để tập hợp rộng rãi quần chúng đấu tranh đòi tự do, cơm áo, hòa bình? Đáp án chuẩn: Mặt trận Thống nhất nhân dân phản đế Đông Dương (sau đổi thành Mặt trận Dân chủ Đông Dương vào năm 1938).', 82),
    (95, N'Trang 95 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Hội nghị lần thứ tám Ban Chấp hành Trung ương Đảng (5/1941) đã quyết định thành lập tổ chức Mặt trận nào nhằm đoàn kết toàn dân chống Nhật, Pháp? Đáp án chuẩn: Quyết định thành lập Mặt trận Việt Nam Độc lập Đồng minh, gọi tắt là Mặt trận Việt Minh.', 78),
    (96, N'Trang 96 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Hội nghị lần thứ tám Ban Chấp hành Trung ương Đảng (5/1941) đã quyết định thành lập tổ chức Mặt trận nào nhằm đoàn kết toàn dân chống Nhật, Pháp? Đáp án chuẩn: Quyết định thành lập Mặt trận Việt Nam Độc lập Đồng minh, gọi tắt là Mặt trận Việt Minh.', 78),
    (117, N'Trang 117 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Bản Tuyên ngôn Độc lập khai sinh nước Việt Nam Dân chủ Cộng hòa được Chủ tịch Hồ Chí Minh đọc tại Quảng trường Ba Đình vào ngày tháng năm nào? Đáp án chuẩn: Ngày 2/9/1945, tại Quảng trường Ba Đình, Hà Nội.', 67),
    (118, N'Trang 118 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Bản Tuyên ngôn Độc lập khai sinh nước Việt Nam Dân chủ Cộng hòa được Chủ tịch Hồ Chí Minh đọc tại Quảng trường Ba Đình vào ngày tháng năm nào? Đáp án chuẩn: Ngày 2/9/1945, tại Quảng trường Ba Đình, Hà Nội.', 67),
    (131, N'Trang 131 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Chính phủ lâm thời họp phiên đầu tiên dưới sự chủ trì của Chủ tịch Hồ Chí Minh vào ngày tháng năm nào để xác định các nhiệm vụ cấp bách? Đáp án chuẩn: Ngày 3/9/1945, ngay sau ngày Tuyên bố độc lập, phiên họp đã xác định ngay các nhiệm vụ diệt giặc đói, diệt giặc dốt và diệt giặc ngoại xâm. Câu hỏi benchmark: Trung ương Đảng ra Chỉ thị ''Kháng chiến kiến quốc'' vào ngày tháng năm nào để vạch ra đường lối xây dựng và bảo vệ đất nước sau Cách mạng Tháng Tám? Đáp án chuẩn: Ban Chấp hành Trung ương Đảng ra Chỉ thị Kháng chiến kiến quốc vào ngày 25/11/1945.', 155),
    (132, N'Trang 132 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Chính phủ lâm thời họp phiên đầu tiên dưới sự chủ trì của Chủ tịch Hồ Chí Minh vào ngày tháng năm nào để xác định các nhiệm vụ cấp bách? Đáp án chuẩn: Ngày 3/9/1945, ngay sau ngày Tuyên bố độc lập, phiên họp đã xác định ngay các nhiệm vụ diệt giặc đói, diệt giặc dốt và diệt giặc ngoại xâm. Câu hỏi benchmark: Trung ương Đảng ra Chỉ thị ''Kháng chiến kiến quốc'' vào ngày tháng năm nào để vạch ra đường lối xây dựng và bảo vệ đất nước sau Cách mạng Tháng Tám? Đáp án chuẩn: Ban Chấp hành Trung ương Đảng ra Chỉ thị Kháng chiến kiến quốc vào ngày 25/11/1945.', 155),
    (134, N'Trang 134 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Cuộc Tổng tuyển cử đầu tiên để bầu ra Quốc hội khóa I của nước Việt Nam mới được tiến hành vào ngày tháng năm nào? Đáp án chuẩn: Ngày 6/1/1946, nhân dân cả nước tham gia bầu cử đại biểu Quốc hội đầu tiên của nước Việt Nam Dân chủ Cộng hòa. Câu hỏi benchmark: Bản Hiến pháp đầu tiên của nước Việt Nam Dân chủ Cộng hòa được Quốc hội thông qua vào ngày tháng năm nào? Đáp án chuẩn: Ngày 9/11/1946, tại Kỳ họp thứ 2, Quốc hội khóa I thông qua bản Hiến pháp đầu tiên (Hiến pháp năm 1946).', 137),
    (135, N'Trang 135 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Cuộc Tổng tuyển cử đầu tiên để bầu ra Quốc hội khóa I của nước Việt Nam mới được tiến hành vào ngày tháng năm nào? Đáp án chuẩn: Ngày 6/1/1946, nhân dân cả nước tham gia bầu cử đại biểu Quốc hội đầu tiên của nước Việt Nam Dân chủ Cộng hòa. Câu hỏi benchmark: Bản Hiến pháp đầu tiên của nước Việt Nam Dân chủ Cộng hòa được Quốc hội thông qua vào ngày tháng năm nào? Đáp án chuẩn: Ngày 9/11/1946, tại Kỳ họp thứ 2, Quốc hội khóa I thông qua bản Hiến pháp đầu tiên (Hiến pháp năm 1946).', 137),
    (147, N'Trang 147 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Lời kêu gọi toàn quốc kháng chiến của Chủ tịch Hồ Chí Minh chính thức được phát đi rộng rãi vào thời gian nào? Đáp án chuẩn: Được phát đi sau khi cuộc kháng chiến bùng nổ, ngày 19/12/1946. Đêm 19/12/1946, quân và dân Hà Nội nổ súng mở đầu cuộc kháng chiến toàn quốc.', 83),
    (148, N'Trang 148 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Lời kêu gọi toàn quốc kháng chiến của Chủ tịch Hồ Chí Minh chính thức được phát đi rộng rãi vào thời gian nào? Đáp án chuẩn: Được phát đi sau khi cuộc kháng chiến bùng nổ, ngày 19/12/1946. Đêm 19/12/1946, quân và dân Hà Nội nổ súng mở đầu cuộc kháng chiến toàn quốc.', 83),
    (149, N'Trang 149 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Đường lối kháng chiến chống thực dân Pháp xâm lược của Đảng được thể hiện tập trung trong những văn kiện nào? Đáp án chuẩn: Thể hiện trong ba văn kiện: Chỉ thị ''Toàn dân kháng chiến'' của Trung ương Đảng (12/12/1946), ''Lời kêu gọi toàn quốc kháng chiến'' của Chủ tịch Hồ Chí Minh (19/12/1946) và tác phẩm ''Kháng chiến nhất định thắng lợi'' của đồng chí Trường Chinh (8/1947).', 109),
    (150, N'Trang 150 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Đường lối kháng chiến chống thực dân Pháp xâm lược của Đảng được thể hiện tập trung trong những văn kiện nào? Đáp án chuẩn: Thể hiện trong ba văn kiện: Chỉ thị ''Toàn dân kháng chiến'' của Trung ương Đảng (12/12/1946), ''Lời kêu gọi toàn quốc kháng chiến'' của Chủ tịch Hồ Chí Minh (19/12/1946) và tác phẩm ''Kháng chiến nhất định thắng lợi'' của đồng chí Trường Chinh (8/1947).', 109),
    (160, N'Trang 160 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Đại hội đại biểu lần thứ II của Đảng diễn ra vào thời gian nào, tại đâu? Đáp án chuẩn: Diễn ra từ ngày 11 đến ngày 19/2/1951 tại xã Vinh Quang (nay là Kim Bình), huyện Chiêm Hóa, tỉnh Tuyên Quang. Câu hỏi benchmark: Đại hội đại biểu lần thứ II (1951) đã quyết định đổi tên Đảng thành gì để lãnh đạo cuộc kháng chiến chống Pháp đi đến thắng lợi? Đáp án chuẩn: Quyết định thành lập Đảng riêng biệt ở mỗi nước Đông Dương; ở Việt Nam, Đảng ra hoạt động công khai lấy tên là Đảng Lao động Việt Nam.', 139),
    (161, N'Trang 161 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Đại hội đại biểu lần thứ II của Đảng diễn ra vào thời gian nào, tại đâu? Đáp án chuẩn: Diễn ra từ ngày 11 đến ngày 19/2/1951 tại xã Vinh Quang (nay là Kim Bình), huyện Chiêm Hóa, tỉnh Tuyên Quang. Câu hỏi benchmark: Đại hội đại biểu lần thứ II (1951) đã quyết định đổi tên Đảng thành gì để lãnh đạo cuộc kháng chiến chống Pháp đi đến thắng lợi? Đáp án chuẩn: Quyết định thành lập Đảng riêng biệt ở mỗi nước Đông Dương; ở Việt Nam, Đảng ra hoạt động công khai lấy tên là Đảng Lao động Việt Nam. Câu hỏi benchmark: Ai được bầu làm Chủ tịch Đảng và ai được bầu làm Tổng Bí thư tại Đại hội lần thứ II của Đảng (1951)? Đáp án chuẩn: Chủ tịch Hồ Chí Minh được bầu làm Chủ tịch Đảng, đồng chí Trường Chinh được bầu làm Tổng Bí thư Ban Chấp hành Trung ương Đảng.', 205),
    (164, N'Trang 164 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Ai được bầu làm Chủ tịch Đảng và ai được bầu làm Tổng Bí thư tại Đại hội lần thứ II của Đảng (1951)? Đáp án chuẩn: Chủ tịch Hồ Chí Minh được bầu làm Chủ tịch Đảng, đồng chí Trường Chinh được bầu làm Tổng Bí thư Ban Chấp hành Trung ương Đảng.', 76),
    (169, N'Trang 169 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Kế hoạch quân sự Nava của thực dân Pháp và can thiệp Mỹ được đề ra vào tháng năm nào nhằm xoay chuyển cục diện chiến tranh Đông Dương? Đáp án chuẩn: Được đề ra vào tháng 5/1953 dưới sự chủ trì của Tổng chỉ huy quân đội Pháp Henri Navarre.', 76),
    (170, N'Trang 170 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Kế hoạch quân sự Nava của thực dân Pháp và can thiệp Mỹ được đề ra vào tháng năm nào nhằm xoay chuyển cục diện chiến tranh Đông Dương? Đáp án chuẩn: Được đề ra vào tháng 5/1953 dưới sự chủ trì của Tổng chỉ huy quân đội Pháp Henri Navarre. Câu hỏi benchmark: Bộ Chính trị quyết định mở Chiến dịch Điện Biên Phủ vào ngày tháng năm nào và giao cho ai làm Bí thư Đảng ủy kiêm Tư lệnh chiến dịch? Đáp án chuẩn: Quyết định mở chiến dịch ngày 6/12/1953, giao cho Đại tướng Võ Nguyên Giáp làm Bí thư Đảng ủy kiêm Tư lệnh chiến dịch.', 147),
    (171, N'Trang 171 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Bộ Chính trị quyết định mở Chiến dịch Điện Biên Phủ vào ngày tháng năm nào và giao cho ai làm Bí thư Đảng ủy kiêm Tư lệnh chiến dịch? Đáp án chuẩn: Quyết định mở chiến dịch ngày 6/12/1953, giao cho Đại tướng Võ Nguyên Giáp làm Bí thư Đảng ủy kiêm Tư lệnh chiến dịch.', 83),
    (173, N'Trang 173 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Hiệp định Giơnevơ về chấm dứt chiến tranh, lập lại hòa bình ở Đông Dương được ký kết vào ngày tháng năm nào? Đáp án chuẩn: Ký kết ngày 21/7/1954, thừa nhận các quyền dân tộc cơ bản của ba nước Việt Nam, Lào, Campuchia.', 71),
    (174, N'Trang 174 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Hiệp định Giơnevơ về chấm dứt chiến tranh, lập lại hòa bình ở Đông Dương được ký kết vào ngày tháng năm nào? Đáp án chuẩn: Ký kết ngày 21/7/1954, thừa nhận các quyền dân tộc cơ bản của ba nước Việt Nam, Lào, Campuchia.', 71),
    (190, N'Trang 190 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Sau năm 1954, Hội nghị Trung ương lần thứ 15 (mở rộng) họp tháng 1/1959 đã đề ra Nghị quyết lịch sử nào đối với cách mạng miền Nam? Đáp án chuẩn: Nghị quyết 15 (mở rộng) xác định phương hướng tiến lên của cách mạng miền Nam là khởi nghĩa giành chính quyền về tay nhân dân, sử dụng con đường bạo lực cách mạng.', 93),
    (191, N'Trang 191 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Sau năm 1954, Hội nghị Trung ương lần thứ 15 (mở rộng) họp tháng 1/1959 đã đề ra Nghị quyết lịch sử nào đối với cách mạng miền Nam? Đáp án chuẩn: Nghị quyết 15 (mở rộng) xác định phương hướng tiến lên của cách mạng miền Nam là khởi nghĩa giành chính quyền về tay nhân dân, sử dụng con đường bạo lực cách mạng.', 93),
    (193, N'Trang 193 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Đại hội đại biểu toàn quốc lần thứ III của Đảng họp vào thời gian nào và tại đâu? Đáp án chuẩn: Đại hội III họp từ ngày 5 đến ngày 10/9/1960 tại Thủ đô Hà Nội.', 56),
    (194, N'Trang 194 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Đại hội đại biểu toàn quốc lần thứ III của Đảng họp vào thời gian nào và tại đâu? Đáp án chuẩn: Đại hội III họp từ ngày 5 đến ngày 10/9/1960 tại Thủ đô Hà Nội.', 56),
    (198, N'Trang 198 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Kế hoạch Nhà nước 5 năm lần thứ nhất xây dựng chủ nghĩa xã hội ở miền Bắc xã hội chủ nghĩa diễn ra trong giai đoạn nào? Đáp án chuẩn: Kế hoạch Nhà nước 5 năm lần thứ nhất diễn ra từ năm 1961 đến năm 1965.', 67),
    (199, N'Trang 199 - Lịch sử Đảng Cộng sản Việt Nam. Câu hỏi benchmark: Kế hoạch Nhà nước 5 năm lần thứ nhất xây dựng chủ nghĩa xã hội ở miền Bắc xã hội chủ nghĩa diễn ra trong giai đoạn nào? Đáp án chuẩn: Kế hoạch Nhà nước 5 năm lần thứ nhất diễn ra từ năm 1961 đến năm 1965.', 67);

    MERGE dbo.DocumentChunks AS target
    USING @Vnr202PageChunks AS source
        ON target.DocumentId = @Vnr202DocumentId
       AND target.PageNumber = source.PageNumber
       AND target.SlideNumber IS NULL
    WHEN MATCHED THEN
        UPDATE SET Content = source.Content, TokenCount = source.TokenCount
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (DocumentId, ChunkIndex, Content, PageNumber, SlideNumber, TokenCount, VectorId, EmbeddingModel, EmbeddingJson)
        VALUES (@Vnr202DocumentId, source.PageNumber, source.Content, source.PageNumber, NULL, source.TokenCount, NULL, NULL, NULL);

    /* =====================================================
       Seed: embedding token usage demo for AdminTokenUsage
       UTC timestamps corresponding to noon in Vietnam (06/07/2026 - 12/07/2026).
       SeedDemo rows have no vector payload and are excluded
       from retrieval by the EmbeddingJson != NULL condition.
       ===================================================== */
    DELETE embedding
    FROM dbo.DocumentChunkEmbeddings embedding
    INNER JOIN dbo.DocumentChunks chunk ON chunk.Id = embedding.DocumentChunkId
    WHERE chunk.DocumentId = @Vnr202DocumentId
      AND embedding.VectorStore = N'SeedDemo';

    DECLARE @EmbeddingUsageDemoModels TABLE
    (
        EmbeddingModel NVARCHAR(100) NOT NULL PRIMARY KEY,
        EmbeddingProvider NVARCHAR(50) NOT NULL,
        Dimension INT NOT NULL,
        TargetChunkCount INT NOT NULL,
        DayOffset INT NOT NULL
    );

    INSERT INTO @EmbeddingUsageDemoModels
        (EmbeddingModel, EmbeddingProvider, Dimension, TargetChunkCount, DayOffset)
    VALUES
        (N'mxbai-embed-large', N'Ollama', 1024, 20, 2),
        (N'bge-m3', N'Ollama', 1024, 18, 0),
        (N'nomic-embed-text', N'Ollama', 768, 15, 1),
        (N'phobert-base', N'PhoBert', 768, 12, 3);

    ;WITH RankedChunks AS
    (
        SELECT
            chunk.Id,
            ROW_NUMBER() OVER (ORDER BY chunk.PageNumber, chunk.Id) AS ChunkRank
        FROM dbo.DocumentChunks chunk
        WHERE chunk.DocumentId = @Vnr202DocumentId
    )
    INSERT INTO dbo.DocumentChunkEmbeddings
        (DocumentChunkId, EmbeddingModel, EmbeddingProvider, Dimension, VectorId, VectorStore, EmbeddingJson, CreatedAt)
    SELECT
        chunk.Id,
        model.EmbeddingModel,
        model.EmbeddingProvider,
        model.Dimension,
        NULL,
        N'SeedDemo',
        NULL,
        DATEADD(DAY, (chunk.ChunkRank - 1 + model.DayOffset) % 7, CONVERT(DATETIME2(0), '2026-07-06T05:00:00'))
    FROM RankedChunks chunk
    CROSS JOIN @EmbeddingUsageDemoModels model
    WHERE chunk.ChunkRank <= model.TargetChunkCount
      AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.DocumentChunkEmbeddings embedding
          WHERE embedding.DocumentChunkId = chunk.Id
            AND embedding.EmbeddingModel = model.EmbeddingModel
      );

    DECLARE @Vnr202Gold TABLE
    (
        Ordinal INT NOT NULL,
        PageNumber INT NOT NULL,
        RelevanceGrade TINYINT NOT NULL,
        PRIMARY KEY (Ordinal, PageNumber)
    );

    INSERT INTO @Vnr202Gold (Ordinal, PageNumber, RelevanceGrade)
    VALUES
    (1, 13, 2),
    (1, 14, 1),
    (2, 13, 2),
    (2, 14, 1),
    (3, 14, 2),
    (3, 15, 1),
    (4, 17, 2),
    (4, 18, 1),
    (5, 19, 2),
    (5, 20, 1),
    (6, 20, 2),
    (6, 17, 1),
    (7, 21, 2),
    (7, 22, 1),
    (8, 25, 2),
    (8, 26, 1),
    (8, 27, 1),
    (9, 26, 2),
    (9, 27, 1),
    (10, 22, 2),
    (10, 23, 1),
    (11, 38, 2),
    (11, 39, 1),
    (12, 39, 2),
    (12, 40, 1),
    (13, 39, 2),
    (13, 41, 1),
    (14, 41, 2),
    (14, 42, 1),
    (15, 48, 2),
    (15, 45, 1),
    (16, 49, 2),
    (16, 48, 1),
    (17, 50, 2),
    (17, 49, 1),
    (18, 50, 2),
    (18, 51, 1),
    (19, 51, 2),
    (19, 50, 1),
    (20, 51, 2),
    (20, 52, 1),
    (21, 53, 2),
    (21, 54, 1),
    (22, 55, 2),
    (22, 56, 1),
    (23, 59, 2),
    (23, 58, 1),
    (24, 61, 2),
    (24, 62, 1),
    (25, 61, 2),
    (25, 62, 1),
    (26, 61, 2),
    (26, 62, 1),
    (27, 62, 2),
    (27, 61, 1),
    (28, 65, 2),
    (28, 64, 1),
    (29, 75, 2),
    (29, 76, 1),
    (30, 75, 2),
    (30, 78, 1),
    (31, 73, 2),
    (31, 74, 1),
    (32, 82, 2),
    (32, 83, 1),
    (33, 85, 2),
    (33, 86, 1),
    (34, 95, 2),
    (34, 96, 1),
    (35, 117, 2),
    (35, 118, 1),
    (36, 131, 2),
    (36, 132, 1),
    (37, 131, 2),
    (37, 132, 1),
    (38, 134, 2),
    (38, 135, 1),
    (39, 135, 2),
    (39, 134, 1),
    (40, 147, 2),
    (40, 148, 1),
    (41, 150, 2),
    (41, 149, 1),
    (42, 160, 2),
    (42, 161, 1),
    (43, 161, 2),
    (43, 160, 1),
    (44, 164, 2),
    (44, 161, 1),
    (45, 169, 2),
    (45, 170, 1),
    (46, 170, 2),
    (46, 171, 1),
    (47, 174, 2),
    (47, 173, 1),
    (48, 191, 2),
    (48, 190, 1),
    (49, 193, 2),
    (49, 194, 1),
    (50, 198, 2),
    (50, 199, 1);

    MERGE dbo.EvaluationQuestionGoldChunks AS target
    USING
    (
        SELECT eq.Id AS EvaluationQuestionId, dc.Id AS DocumentChunkId, g.RelevanceGrade
        FROM @Vnr202Gold g
        INNER JOIN @Vnr202Questions q ON q.Ordinal = g.Ordinal
        INNER JOIN dbo.EvaluationQuestions eq ON eq.SubjectId = @Vnr202SubjectId AND eq.Question = q.Question
        INNER JOIN dbo.DocumentChunks dc ON dc.DocumentId = @Vnr202DocumentId AND dc.PageNumber = g.PageNumber AND dc.SlideNumber IS NULL
    ) AS source
        ON target.EvaluationQuestionId = source.EvaluationQuestionId
       AND target.DocumentChunkId = source.DocumentChunkId
    WHEN MATCHED THEN
        UPDATE SET RelevanceGrade = source.RelevanceGrade
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (EvaluationQuestionId, DocumentChunkId, RelevanceGrade)
        VALUES (source.EvaluationQuestionId, source.DocumentChunkId, source.RelevanceGrade);
END
GO
PRINT N'ChatAIWebDb database script executed successfully.';
GO


