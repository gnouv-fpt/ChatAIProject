SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF COL_LENGTH(N'dbo.EvaluationQuestions', N'IsAnswerable') IS NULL
BEGIN
    ALTER TABLE dbo.EvaluationQuestions
        ADD IsAnswerable BIT NOT NULL
            CONSTRAINT DF_EvaluationQuestions_IsAnswerable DEFAULT 1;
END;

IF OBJECT_ID(N'dbo.EvaluationQuestionGoldChunks', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.EvaluationQuestionGoldChunks
    (
        EvaluationQuestionId INT NOT NULL,
        DocumentChunkId      INT NOT NULL,
        RelevanceGrade       TINYINT NOT NULL,
        CreatedAt            DATETIME2(0) NOT NULL
            CONSTRAINT DF_EvaluationQuestionGoldChunks_CreatedAt DEFAULT SYSUTCDATETIME(),

        CONSTRAINT PK_EvaluationQuestionGoldChunks
            PRIMARY KEY (EvaluationQuestionId, DocumentChunkId),
        CONSTRAINT CK_EvaluationQuestionGoldChunks_RelevanceGrade
            CHECK (RelevanceGrade IN (1, 2)),
        CONSTRAINT FK_EvaluationQuestionGoldChunks_EvaluationQuestions
            FOREIGN KEY (EvaluationQuestionId)
            REFERENCES dbo.EvaluationQuestions(Id) ON DELETE CASCADE,
        CONSTRAINT FK_EvaluationQuestionGoldChunks_DocumentChunks
            FOREIGN KEY (DocumentChunkId)
            REFERENCES dbo.DocumentChunks(Id) ON DELETE CASCADE
    );
END;

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = N'IX_EvaluationQuestionGoldChunks_DocumentChunkId'
      AND object_id = OBJECT_ID(N'dbo.EvaluationQuestionGoldChunks'))
BEGIN
    CREATE INDEX IX_EvaluationQuestionGoldChunks_DocumentChunkId
        ON dbo.EvaluationQuestionGoldChunks(DocumentChunkId);
END;

-- This block runs once when upgrading from the legacy RAGAS schema.
IF COL_LENGTH(N'dbo.RagasBenchmarkResults', N'RecallAt5') IS NULL
BEGIN
    DELETE FROM dbo.RagasBenchmarkResults;

    ALTER TABLE dbo.RagasBenchmarkResults ADD
        RetrievedChunkIdsJson NVARCHAR(MAX) NULL,
        CitationChunkIdsJson  NVARCHAR(MAX) NULL,
        RecallAt5             DECIMAL(9,6) NULL,
        MrrAt10               DECIMAL(9,6) NULL,
        NdcgAt5               DECIMAL(9,6) NULL,
        AnswerCorrectness     DECIMAL(9,6) NULL,
        CitationPrecision     DECIMAL(9,6) NULL,
        CitationRecall        DECIMAL(9,6) NULL,
        CitationF1            DECIMAL(9,6) NULL,
        ExpectedNoAnswer      BIT NOT NULL
            CONSTRAINT DF_RagasBenchmarkResults_ExpectedNoAnswer DEFAULT 0,
        PredictedNoAnswer     BIT NOT NULL
            CONSTRAINT DF_RagasBenchmarkResults_PredictedNoAnswer DEFAULT 0,
        EmbeddingLatencyMs    BIGINT NOT NULL
            CONSTRAINT DF_RagasBenchmarkResults_EmbeddingLatencyMs DEFAULT 0,
        RetrievalLatencyMs    BIGINT NOT NULL
            CONSTRAINT DF_RagasBenchmarkResults_RetrievalLatencyMs DEFAULT 0,
        GenerationLatencyMs   BIGINT NOT NULL
            CONSTRAINT DF_RagasBenchmarkResults_GenerationLatencyMs DEFAULT 0,
        EndToEndLatencyMs     BIGINT NOT NULL
            CONSTRAINT DF_RagasBenchmarkResults_EndToEndLatencyMs DEFAULT 0;
END;

COMMIT TRANSACTION;