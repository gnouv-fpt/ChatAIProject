using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace DataAccess.Migrations.User
{
    /// <inheritdoc />
    public partial class UserInitialCreate : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "Users",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Username = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false),
                    Email = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: false),
                    PasswordHash = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: false),
                    Role = table.Column<string>(type: "nvarchar(30)", maxLength: 30, nullable: false),
                    TokenQuota = table.Column<int>(type: "int", nullable: false),
                    TokenBalance = table.Column<int>(type: "int", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Users", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "ExamAttempts",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ExamCode = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    ExamVersion = table.Column<int>(type: "int", nullable: false),
                    Score = table.Column<int>(type: "int", nullable: false),
                    IsPassed = table.Column<bool>(type: "bit", nullable: false),
                    TimeSpentSeconds = table.Column<int>(type: "int", nullable: false),
                    UserAnswersJson = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    ExamSnapshotJson = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    SubmissionHash = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    SubmittedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ExamAttempts", x => x.Id);
                    table.CheckConstraint("CK_ExamAttempts_AnswersJson", "ISJSON([UserAnswersJson]) = 1");
                    table.CheckConstraint("CK_ExamAttempts_Score", "[Score] >= 0");
                    table.CheckConstraint("CK_ExamAttempts_SnapshotJson", "ISJSON([ExamSnapshotJson]) = 1");
                    table.CheckConstraint("CK_ExamAttempts_Time", "[TimeSpentSeconds] >= 0");
                    table.CheckConstraint("CK_ExamAttempts_Version", "[ExamVersion] > 0");
                    table.ForeignKey(
                        name: "FK_ExamAttempts_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "UserChatSessions",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Title = table.Column<string>(type: "nvarchar(255)", maxLength: 255, nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    LastUpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    IsDeleted = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_UserChatSessions", x => x.Id);
                    table.ForeignKey(
                        name: "FK_UserChatSessions_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "UserChatMessages",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    SessionId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    SenderRole = table.Column<string>(type: "nvarchar(30)", maxLength: 30, nullable: false),
                    Content = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    TokensUsed = table.Column<int>(type: "int", nullable: false),
                    IsViolation = table.Column<bool>(type: "bit", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    RequestId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    RequestHash = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: true),
                    TurnState = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: true),
                    LeaseId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    LeaseExpiresAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    ReservedTokens = table.Column<int>(type: "int", nullable: false),
                    RequestContext = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    ResultStatus = table.Column<string>(type: "nvarchar(30)", maxLength: 30, nullable: true),
                    EventPayload = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    EventPublishedAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    QuotaSettledAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    CitationsJson = table.Column<string>(type: "nvarchar(max)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_UserChatMessages", x => x.Id);
                    table.ForeignKey(
                        name: "FK_UserChatMessages_UserChatSessions_SessionId",
                        column: x => x.SessionId,
                        principalTable: "UserChatSessions",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_ExamAttempts_UserId_SubmittedAt",
                table: "ExamAttempts",
                columns: new[] { "UserId", "SubmittedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_UserChatMessages_SessionId_CreatedAt",
                table: "UserChatMessages",
                columns: new[] { "SessionId", "CreatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_UserChatMessages_SessionId_RequestId",
                table: "UserChatMessages",
                columns: new[] { "SessionId", "RequestId" },
                unique: true,
                filter: "[RequestId] IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_UserChatSessions_UserId_IsDeleted_LastUpdatedAt",
                table: "UserChatSessions",
                columns: new[] { "UserId", "IsDeleted", "LastUpdatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_Users_Email",
                table: "Users",
                column: "Email",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Users_Username",
                table: "Users",
                column: "Username",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ExamAttempts");

            migrationBuilder.DropTable(
                name: "UserChatMessages");

            migrationBuilder.DropTable(
                name: "UserChatSessions");

            migrationBuilder.DropTable(
                name: "Users");
        }
    }
}
