using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace DataAccess.Migrations
{
    /// <inheritdoc />
    public partial class RemoveUnnecessaryReportingTables : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "UsageReports");

            migrationBuilder.DropTable(
                name: "ViolationLogs");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "UsageReports",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    ReportDate = table.Column<DateOnly>(type: "date", nullable: false),
                    TotalQueries = table.Column<int>(type: "int", nullable: false),
                    TotalTokensUsed = table.Column<long>(type: "bigint", nullable: false),
                    TotalViolations = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_UsageReports", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "ViolationLogs",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ChatMessageId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    UserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    NotifiedViaEmail = table.Column<bool>(type: "bit", nullable: false),
                    ViolationKeywords = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ViolationLogs", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ViolationLogs_ChatMessages_ChatMessageId",
                        column: x => x.ChatMessageId,
                        principalTable: "ChatMessages",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_ViolationLogs_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_UsageReports_ReportDate",
                table: "UsageReports",
                column: "ReportDate",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_ViolationLogs_ChatMessageId",
                table: "ViolationLogs",
                column: "ChatMessageId");

            migrationBuilder.CreateIndex(
                name: "IX_ViolationLogs_CreatedAt",
                table: "ViolationLogs",
                column: "CreatedAt");

            migrationBuilder.CreateIndex(
                name: "IX_ViolationLogs_UserId",
                table: "ViolationLogs",
                column: "UserId");
        }
    }
}
