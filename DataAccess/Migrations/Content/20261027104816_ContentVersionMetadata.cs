using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace DataAccess.Migrations.Content
{
    /// <inheritdoc />
    public partial class ContentVersionMetadata : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "AllowOptionShuffle",
                table: "TrafficQuestions",
                type: "bit",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<string>(
                name: "ContentHash",
                table: "LegalDocuments",
                type: "nvarchar(64)",
                maxLength: 64,
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "Version",
                table: "LegalDocuments",
                type: "int",
                nullable: false,
                defaultValue: 1);

            migrationBuilder.AddCheckConstraint(
                name: "CK_LegalDocuments_Version",
                table: "LegalDocuments",
                sql: "[Version] > 0");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "CK_LegalDocuments_Version",
                table: "LegalDocuments");

            migrationBuilder.DropColumn(
                name: "AllowOptionShuffle",
                table: "TrafficQuestions");

            migrationBuilder.DropColumn(
                name: "ContentHash",
                table: "LegalDocuments");

            migrationBuilder.DropColumn(
                name: "Version",
                table: "LegalDocuments");
        }
    }
}
