using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace DataAccess.Migrations
{
    /// <inheritdoc />
    public partial class CoreStateConstraints : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Normalise legacy rows so the new CHECK constraints can be created on an existing database.
            migrationBuilder.Sql("UPDATE [Users] SET [TokenBalance] = 0 WHERE [TokenBalance] < 0");
            migrationBuilder.Sql("UPDATE [Users] SET [TokenQuota] = 0 WHERE [TokenQuota] < 0");
            migrationBuilder.Sql("UPDATE [ChatMessages] SET [TokensUsed] = 0 WHERE [TokensUsed] < 0");

            migrationBuilder.AddColumn<string>(
                name: "ContentHash",
                table: "LegalDocuments",
                type: "nvarchar(64)",
                maxLength: 64,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "EventPayload",
                table: "LegalDocuments",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "EventPublishedAt",
                table: "LegalDocuments",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "Version",
                table: "LegalDocuments",
                type: "int",
                nullable: false,
                defaultValue: 1);

            migrationBuilder.AddCheckConstraint(
                name: "CK_Users_TokenBalance",
                table: "Users",
                sql: "[TokenBalance] >= 0");

            migrationBuilder.AddCheckConstraint(
                name: "CK_Users_TokenQuota",
                table: "Users",
                sql: "[TokenQuota] >= 0");

            migrationBuilder.CreateIndex(
                name: "IX_LegalDocuments_UnpublishedEvents",
                table: "LegalDocuments",
                column: "CreatedAt",
                filter: "[EventPayload] IS NOT NULL AND [EventPublishedAt] IS NULL");

            migrationBuilder.AddCheckConstraint(
                name: "CK_LegalDocuments_Version",
                table: "LegalDocuments",
                sql: "[Version] >= 1");

            migrationBuilder.CreateIndex(
                name: "IX_ChatMessages_OpenReservations",
                table: "ChatMessages",
                columns: new[] { "TurnState", "LeaseExpiresAt" },
                filter: "[QuotaSettledAt] IS NULL AND [ReservedTokens] > 0");

            migrationBuilder.CreateIndex(
                name: "IX_ChatMessages_UnpublishedEvents",
                table: "ChatMessages",
                column: "CreatedAt",
                filter: "[EventPayload] IS NOT NULL AND [EventPublishedAt] IS NULL");

            migrationBuilder.AddCheckConstraint(
                name: "CK_ChatMessages_Request",
                table: "ChatMessages",
                sql: "[RequestId] IS NULL OR [RequestHash] IS NOT NULL");

            migrationBuilder.AddCheckConstraint(
                name: "CK_ChatMessages_Tokens",
                table: "ChatMessages",
                sql: "[TokensUsed] >= 0 AND [ReservedTokens] >= 0");

            migrationBuilder.AddCheckConstraint(
                name: "CK_ChatMessages_TurnState",
                table: "ChatMessages",
                sql: "[TurnState] IS NULL OR [TurnState] IN ('Processing', 'Completed', 'Failed')");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "CK_Users_TokenBalance",
                table: "Users");

            migrationBuilder.DropCheckConstraint(
                name: "CK_Users_TokenQuota",
                table: "Users");

            migrationBuilder.DropIndex(
                name: "IX_LegalDocuments_UnpublishedEvents",
                table: "LegalDocuments");

            migrationBuilder.DropCheckConstraint(
                name: "CK_LegalDocuments_Version",
                table: "LegalDocuments");

            migrationBuilder.DropIndex(
                name: "IX_ChatMessages_OpenReservations",
                table: "ChatMessages");

            migrationBuilder.DropIndex(
                name: "IX_ChatMessages_UnpublishedEvents",
                table: "ChatMessages");

            migrationBuilder.DropCheckConstraint(
                name: "CK_ChatMessages_Request",
                table: "ChatMessages");

            migrationBuilder.DropCheckConstraint(
                name: "CK_ChatMessages_Tokens",
                table: "ChatMessages");

            migrationBuilder.DropCheckConstraint(
                name: "CK_ChatMessages_TurnState",
                table: "ChatMessages");

            migrationBuilder.DropColumn(
                name: "ContentHash",
                table: "LegalDocuments");

            migrationBuilder.DropColumn(
                name: "EventPayload",
                table: "LegalDocuments");

            migrationBuilder.DropColumn(
                name: "EventPublishedAt",
                table: "LegalDocuments");

            migrationBuilder.DropColumn(
                name: "Version",
                table: "LegalDocuments");
        }
    }
}
