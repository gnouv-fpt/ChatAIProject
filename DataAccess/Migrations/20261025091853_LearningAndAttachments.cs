using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace DataAccess.Migrations
{
    /// <inheritdoc />
    public partial class LearningAndAttachments : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "ChatAttachments",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    SessionId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    StorageKey = table.Column<string>(type: "nvarchar(300)", maxLength: 300, nullable: false),
                    ContentType = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    SizeBytes = table.Column<long>(type: "bigint", nullable: false),
                    Sha256 = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    ExpiresAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    DeletedAt = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ChatAttachments", x => x.Id);
                    table.CheckConstraint("CK_ChatAttachments_Size", "[SizeBytes] > 0");
                    table.ForeignKey(
                        name: "FK_ChatAttachments_ChatSessions_SessionId",
                        column: x => x.SessionId,
                        principalTable: "ChatSessions",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_ChatAttachments_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "QuestionBanks",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Code = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false),
                    Version = table.Column<int>(type: "int", nullable: false),
                    Name = table.Column<string>(type: "nvarchar(255)", maxLength: 255, nullable: false),
                    LicenseClass = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: true),
                    Description = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: true),
                    SourceName = table.Column<string>(type: "nvarchar(255)", maxLength: 255, nullable: true),
                    SourceUrl = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: true),
                    ManifestHash = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    Status = table.Column<string>(type: "nvarchar(30)", maxLength: 30, nullable: false),
                    QuestionCount = table.Column<int>(type: "int", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    PublishedAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    RetiredAt = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_QuestionBanks", x => x.Id);
                    table.CheckConstraint("CK_QuestionBanks_Published", "[Status] <> 'Published' OR [PublishedAt] IS NOT NULL");
                    table.CheckConstraint("CK_QuestionBanks_QuestionCount", "[QuestionCount] >= 0");
                    table.CheckConstraint("CK_QuestionBanks_Version", "[Version] >= 1");
                });

            migrationBuilder.CreateTable(
                name: "ExamTemplates",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    BankId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Code = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false),
                    Name = table.Column<string>(type: "nvarchar(255)", maxLength: 255, nullable: false),
                    QuestionCount = table.Column<int>(type: "int", nullable: false),
                    DurationMinutes = table.Column<int>(type: "int", nullable: false),
                    PassingScore = table.Column<int>(type: "int", nullable: false),
                    FailOnCriticalWrong = table.Column<bool>(type: "bit", nullable: false),
                    TopicDistribution = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    FixedQuestionIds = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    SourceName = table.Column<string>(type: "nvarchar(255)", maxLength: 255, nullable: true),
                    IsActive = table.Column<bool>(type: "bit", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ExamTemplates", x => x.Id);
                    table.CheckConstraint("CK_ExamTemplates_Duration", "[DurationMinutes] >= 1");
                    table.CheckConstraint("CK_ExamTemplates_PassingScore", "[PassingScore] >= 0 AND [PassingScore] <= [QuestionCount]");
                    table.CheckConstraint("CK_ExamTemplates_QuestionCount", "[QuestionCount] >= 1");
                    table.ForeignKey(
                        name: "FK_ExamTemplates_QuestionBanks_BankId",
                        column: x => x.BankId,
                        principalTable: "QuestionBanks",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "Questions",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    BankId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Number = table.Column<int>(type: "int", nullable: false),
                    ExternalId = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    Content = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    ImagePath = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                    Topic = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    IsCritical = table.Column<bool>(type: "bit", nullable: false),
                    AllowOptionShuffle = table.Column<bool>(type: "bit", nullable: false),
                    CorrectOptionIds = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    Explanation = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    LegalReference = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                    ContentHash = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    Options = table.Column<string>(type: "nvarchar(max)", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Questions", x => x.Id);
                    table.CheckConstraint("CK_Questions_Number", "[Number] >= 1");
                    table.ForeignKey(
                        name: "FK_Questions_QuestionBanks_BankId",
                        column: x => x.BankId,
                        principalTable: "QuestionBanks",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "LearningAttempts",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    BankId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ExamTemplateId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    Mode = table.Column<string>(type: "nvarchar(30)", maxLength: 30, nullable: false),
                    Status = table.Column<string>(type: "nvarchar(30)", maxLength: 30, nullable: false),
                    SelectionCriteria = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    ProfileSnapshot = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    Seed = table.Column<int>(type: "int", nullable: false),
                    QuestionCount = table.Column<int>(type: "int", nullable: false),
                    StartedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    DeadlineAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    SubmittedAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    SubmitRequestId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    CorrectCount = table.Column<int>(type: "int", nullable: true),
                    WrongCount = table.Column<int>(type: "int", nullable: true),
                    UnansweredCount = table.Column<int>(type: "int", nullable: true),
                    Score = table.Column<int>(type: "int", nullable: true),
                    IsPassed = table.Column<bool>(type: "bit", nullable: true),
                    FailReason = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                    RowVersion = table.Column<byte[]>(type: "rowversion", rowVersion: true, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_LearningAttempts", x => x.Id);
                    table.CheckConstraint("CK_LearningAttempts_ExamDeadline", "[Mode] <> 'Exam' OR [DeadlineAt] IS NOT NULL");
                    table.CheckConstraint("CK_LearningAttempts_Graded", "[Status] IN ('InProgress', 'Abandoned') OR [SubmittedAt] IS NOT NULL");
                    table.CheckConstraint("CK_LearningAttempts_QuestionCount", "[QuestionCount] >= 1");
                    table.ForeignKey(
                        name: "FK_LearningAttempts_ExamTemplates_ExamTemplateId",
                        column: x => x.ExamTemplateId,
                        principalTable: "ExamTemplates",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_LearningAttempts_QuestionBanks_BankId",
                        column: x => x.BankId,
                        principalTable: "QuestionBanks",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_LearningAttempts_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "QuestionBookmarks",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    QuestionId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_QuestionBookmarks", x => x.Id);
                    table.ForeignKey(
                        name: "FK_QuestionBookmarks_Questions_QuestionId",
                        column: x => x.QuestionId,
                        principalTable: "Questions",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_QuestionBookmarks_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "AttemptAnswers",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    AttemptId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    QuestionId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Position = table.Column<int>(type: "int", nullable: false),
                    OptionOrder = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    CorrectOptionIds = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    SelectedOptionIds = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    IsCorrect = table.Column<bool>(type: "bit", nullable: true),
                    IsFlagged = table.Column<bool>(type: "bit", nullable: false),
                    AnsweredAt = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AttemptAnswers", x => x.Id);
                    table.CheckConstraint("CK_AttemptAnswers_Position", "[Position] >= 1");
                    table.ForeignKey(
                        name: "FK_AttemptAnswers_LearningAttempts_AttemptId",
                        column: x => x.AttemptId,
                        principalTable: "LearningAttempts",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_AttemptAnswers_Questions_QuestionId",
                        column: x => x.QuestionId,
                        principalTable: "Questions",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateIndex(
                name: "IX_AttemptAnswers_AttemptId_Position",
                table: "AttemptAnswers",
                columns: new[] { "AttemptId", "Position" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_AttemptAnswers_AttemptId_QuestionId",
                table: "AttemptAnswers",
                columns: new[] { "AttemptId", "QuestionId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_AttemptAnswers_QuestionId",
                table: "AttemptAnswers",
                column: "QuestionId");

            migrationBuilder.CreateIndex(
                name: "IX_ChatAttachments_ExpiresAt",
                table: "ChatAttachments",
                column: "ExpiresAt",
                filter: "[DeletedAt] IS NULL");

            migrationBuilder.CreateIndex(
                name: "IX_ChatAttachments_SessionId",
                table: "ChatAttachments",
                column: "SessionId");

            migrationBuilder.CreateIndex(
                name: "IX_ChatAttachments_StorageKey",
                table: "ChatAttachments",
                column: "StorageKey",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_ChatAttachments_UserId_DeletedAt",
                table: "ChatAttachments",
                columns: new[] { "UserId", "DeletedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_ExamTemplates_BankId_Code",
                table: "ExamTemplates",
                columns: new[] { "BankId", "Code" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_LearningAttempts_BankId",
                table: "LearningAttempts",
                column: "BankId");

            migrationBuilder.CreateIndex(
                name: "IX_LearningAttempts_DeadlineAt",
                table: "LearningAttempts",
                column: "DeadlineAt",
                filter: "[Status] = 'InProgress' AND [DeadlineAt] IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_LearningAttempts_ExamTemplateId",
                table: "LearningAttempts",
                column: "ExamTemplateId");

            migrationBuilder.CreateIndex(
                name: "IX_LearningAttempts_UserId_BankId_Status",
                table: "LearningAttempts",
                columns: new[] { "UserId", "BankId", "Status" });

            migrationBuilder.CreateIndex(
                name: "IX_LearningAttempts_UserId_StartedAt",
                table: "LearningAttempts",
                columns: new[] { "UserId", "StartedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_QuestionBanks_Code_Version",
                table: "QuestionBanks",
                columns: new[] { "Code", "Version" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_QuestionBanks_Status",
                table: "QuestionBanks",
                column: "Status");

            migrationBuilder.CreateIndex(
                name: "IX_QuestionBookmarks_QuestionId",
                table: "QuestionBookmarks",
                column: "QuestionId");

            migrationBuilder.CreateIndex(
                name: "IX_QuestionBookmarks_UserId_QuestionId",
                table: "QuestionBookmarks",
                columns: new[] { "UserId", "QuestionId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Questions_BankId_ExternalId",
                table: "Questions",
                columns: new[] { "BankId", "ExternalId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Questions_BankId_Number",
                table: "Questions",
                columns: new[] { "BankId", "Number" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Questions_BankId_Topic",
                table: "Questions",
                columns: new[] { "BankId", "Topic" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "AttemptAnswers");

            migrationBuilder.DropTable(
                name: "ChatAttachments");

            migrationBuilder.DropTable(
                name: "QuestionBookmarks");

            migrationBuilder.DropTable(
                name: "LearningAttempts");

            migrationBuilder.DropTable(
                name: "Questions");

            migrationBuilder.DropTable(
                name: "ExamTemplates");

            migrationBuilder.DropTable(
                name: "QuestionBanks");
        }
    }
}
