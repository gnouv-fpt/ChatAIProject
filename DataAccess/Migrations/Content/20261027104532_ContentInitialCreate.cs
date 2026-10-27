using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace DataAccess.Migrations.Content
{
    /// <inheritdoc />
    public partial class ContentInitialCreate : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "ExamTemplates",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ExamCode = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    Version = table.Column<int>(type: "int", nullable: false),
                    Title = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: false),
                    DurationMinutes = table.Column<int>(type: "int", nullable: false),
                    PassingScore = table.Column<int>(type: "int", nullable: false),
                    IsPublished = table.Column<bool>(type: "bit", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ExamTemplates", x => x.Id);
                    table.CheckConstraint("CK_ExamTemplates_Duration", "[DurationMinutes] > 0");
                    table.CheckConstraint("CK_ExamTemplates_PassingScore", "[PassingScore] >= 0");
                    table.CheckConstraint("CK_ExamTemplates_Version", "[Version] > 0");
                });

            migrationBuilder.CreateTable(
                name: "LegalDocuments",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    DocumentNumber = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    Title = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: false),
                    DocumentType = table.Column<string>(type: "nvarchar(30)", maxLength: 30, nullable: false),
                    IssuingAuthority = table.Column<string>(type: "nvarchar(255)", maxLength: 255, nullable: true),
                    EffectiveDate = table.Column<DateTime>(type: "datetime2", nullable: true),
                    ExpirationDate = table.Column<DateTime>(type: "datetime2", nullable: true),
                    IsActive = table.Column<bool>(type: "bit", nullable: false),
                    VerificationStatus = table.Column<string>(type: "nvarchar(30)", maxLength: 30, nullable: false),
                    LastVerifiedAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    SourceUrl = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_LegalDocuments", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "TrafficQuestionCategories",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Type = table.Column<string>(type: "nvarchar(30)", maxLength: 30, nullable: false),
                    SubCategoryCode = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false),
                    Name = table.Column<string>(type: "nvarchar(255)", maxLength: 255, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TrafficQuestionCategories", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "LegalDocumentChunks",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    DocumentId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Chapter = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true),
                    Article = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true),
                    Clause = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true),
                    Point = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: true),
                    Content = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    TokenCount = table.Column<int>(type: "int", nullable: false),
                    VectorId = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true),
                    IsVerified = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_LegalDocumentChunks", x => x.Id);
                    table.ForeignKey(
                        name: "FK_LegalDocumentChunks_LegalDocuments_DocumentId",
                        column: x => x.DocumentId,
                        principalTable: "LegalDocuments",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "TrafficQuestions",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CategoryId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    LegalDocumentChunkId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    BankCode = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    BankVersion = table.Column<int>(type: "int", nullable: false),
                    QuestionCode = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    IsParalysisQuestion = table.Column<bool>(type: "bit", nullable: false),
                    QuestionPayloadJson = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    CorrectAnswerKey = table.Column<string>(type: "nvarchar(30)", maxLength: 30, nullable: false),
                    ExplanationText = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    ExplanationAnimationUrl = table.Column<string>(type: "nvarchar(2000)", maxLength: 2000, nullable: true),
                    SourceUrl = table.Column<string>(type: "nvarchar(2000)", maxLength: 2000, nullable: true),
                    IsPublished = table.Column<bool>(type: "bit", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TrafficQuestions", x => x.Id);
                    table.CheckConstraint("CK_TrafficQuestions_Payload", "ISJSON([QuestionPayloadJson]) = 1");
                    table.CheckConstraint("CK_TrafficQuestions_Version", "[BankVersion] > 0");
                    table.ForeignKey(
                        name: "FK_TrafficQuestions_LegalDocumentChunks_LegalDocumentChunkId",
                        column: x => x.LegalDocumentChunkId,
                        principalTable: "LegalDocumentChunks",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_TrafficQuestions_TrafficQuestionCategories_CategoryId",
                        column: x => x.CategoryId,
                        principalTable: "TrafficQuestionCategories",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "ExamTemplateItems",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ExamTemplateId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    QuestionId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    OrderIndex = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ExamTemplateItems", x => x.Id);
                    table.CheckConstraint("CK_ExamTemplateItems_Order", "[OrderIndex] > 0");
                    table.ForeignKey(
                        name: "FK_ExamTemplateItems_ExamTemplates_ExamTemplateId",
                        column: x => x.ExamTemplateId,
                        principalTable: "ExamTemplates",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_ExamTemplateItems_TrafficQuestions_QuestionId",
                        column: x => x.QuestionId,
                        principalTable: "TrafficQuestions",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_ExamTemplateItems_ExamTemplateId_OrderIndex",
                table: "ExamTemplateItems",
                columns: new[] { "ExamTemplateId", "OrderIndex" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_ExamTemplateItems_ExamTemplateId_QuestionId",
                table: "ExamTemplateItems",
                columns: new[] { "ExamTemplateId", "QuestionId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_ExamTemplateItems_QuestionId",
                table: "ExamTemplateItems",
                column: "QuestionId");

            migrationBuilder.CreateIndex(
                name: "IX_ExamTemplates_ExamCode_Version",
                table: "ExamTemplates",
                columns: new[] { "ExamCode", "Version" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_LegalDocumentChunks_DocumentId",
                table: "LegalDocumentChunks",
                column: "DocumentId");

            migrationBuilder.CreateIndex(
                name: "IX_LegalDocuments_DocumentNumber",
                table: "LegalDocuments",
                column: "DocumentNumber",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_LegalDocuments_IsActive_VerificationStatus",
                table: "LegalDocuments",
                columns: new[] { "IsActive", "VerificationStatus" });

            migrationBuilder.CreateIndex(
                name: "IX_TrafficQuestionCategories_SubCategoryCode",
                table: "TrafficQuestionCategories",
                column: "SubCategoryCode",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_TrafficQuestions_BankCode_BankVersion_QuestionCode",
                table: "TrafficQuestions",
                columns: new[] { "BankCode", "BankVersion", "QuestionCode" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_TrafficQuestions_CategoryId",
                table: "TrafficQuestions",
                column: "CategoryId");

            migrationBuilder.CreateIndex(
                name: "IX_TrafficQuestions_IsPublished_CategoryId",
                table: "TrafficQuestions",
                columns: new[] { "IsPublished", "CategoryId" });

            migrationBuilder.CreateIndex(
                name: "IX_TrafficQuestions_LegalDocumentChunkId",
                table: "TrafficQuestions",
                column: "LegalDocumentChunkId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ExamTemplateItems");

            migrationBuilder.DropTable(
                name: "ExamTemplates");

            migrationBuilder.DropTable(
                name: "TrafficQuestions");

            migrationBuilder.DropTable(
                name: "LegalDocumentChunks");

            migrationBuilder.DropTable(
                name: "TrafficQuestionCategories");

            migrationBuilder.DropTable(
                name: "LegalDocuments");
        }
    }
}
