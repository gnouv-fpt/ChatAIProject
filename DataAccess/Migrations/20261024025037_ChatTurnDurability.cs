using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace DataAccess.Migrations
{
    /// <inheritdoc />
    public partial class ChatTurnDurability : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "ContentHash",
                table: "Citations",
                type: "nvarchar(64)",
                maxLength: 64,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "PointNumber",
                table: "Citations",
                type: "nvarchar(50)",
                maxLength: 50,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "EventPayload",
                table: "ChatMessages",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "EventPublishedAt",
                table: "ChatMessages",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "LeaseExpiresAt",
                table: "ChatMessages",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "LeaseId",
                table: "ChatMessages",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "QuotaSettledAt",
                table: "ChatMessages",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "RequestContext",
                table: "ChatMessages",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "RequestHash",
                table: "ChatMessages",
                type: "nvarchar(64)",
                maxLength: 64,
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "RequestId",
                table: "ChatMessages",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "ReservedTokens",
                table: "ChatMessages",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<string>(
                name: "ResultStatus",
                table: "ChatMessages",
                type: "nvarchar(30)",
                maxLength: 30,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "TurnState",
                table: "ChatMessages",
                type: "nvarchar(20)",
                maxLength: 20,
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_ChatMessages_SessionId_RequestId",
                table: "ChatMessages",
                columns: new[] { "SessionId", "RequestId" },
                unique: true,
                filter: "[RequestId] IS NOT NULL");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_ChatMessages_SessionId_RequestId",
                table: "ChatMessages");

            migrationBuilder.DropColumn(
                name: "ContentHash",
                table: "Citations");

            migrationBuilder.DropColumn(
                name: "PointNumber",
                table: "Citations");

            migrationBuilder.DropColumn(
                name: "EventPayload",
                table: "ChatMessages");

            migrationBuilder.DropColumn(
                name: "EventPublishedAt",
                table: "ChatMessages");

            migrationBuilder.DropColumn(
                name: "LeaseExpiresAt",
                table: "ChatMessages");

            migrationBuilder.DropColumn(
                name: "LeaseId",
                table: "ChatMessages");

            migrationBuilder.DropColumn(
                name: "QuotaSettledAt",
                table: "ChatMessages");

            migrationBuilder.DropColumn(
                name: "RequestContext",
                table: "ChatMessages");

            migrationBuilder.DropColumn(
                name: "RequestHash",
                table: "ChatMessages");

            migrationBuilder.DropColumn(
                name: "RequestId",
                table: "ChatMessages");

            migrationBuilder.DropColumn(
                name: "ReservedTokens",
                table: "ChatMessages");

            migrationBuilder.DropColumn(
                name: "ResultStatus",
                table: "ChatMessages");

            migrationBuilder.DropColumn(
                name: "TurnState",
                table: "ChatMessages");
        }
    }
}
