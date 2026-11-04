using System.Text.Json;
using BusinessLogic.DTOs;
using BusinessLogic.Infrastructure.Settings;
using BusinessLogic.Services.Implementations;
using BusinessObject.Entities;
using DataAccess;
using DataAccess.Repositories.Implementations;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace Content.Tests;

public sealed class ContentSqlFactAttribute : FactAttribute
{
    public ContentSqlFactAttribute()
    {
        if (Environment.GetEnvironmentVariable("PHUC_TEST_SQL") is null)
            Skip = "Set PHUC_TEST_SQL to a server-only local SQL connection; this test creates and drops its own isolated Content DB.";
    }
}

public sealed class ContentSqlBankTests
{
    [ContentSqlFact]
    public async Task Reviewed600BankRoundTripsThroughSqlWith115AnimationsAndPublishedTemplate()
    {
        var connection = new SqlConnectionStringBuilder(Environment.GetEnvironmentVariable("PHUC_TEST_SQL"));
        Assert.True(string.IsNullOrEmpty(connection.InitialCatalog), "PHUC_TEST_SQL must not target an existing database.");
        var databaseName = "PhucContentTests_" + Guid.NewGuid().ToString("N");
        connection.InitialCatalog = databaseName;
        await using var db = new ContentDbContext(new DbContextOptionsBuilder<ContentDbContext>().UseSqlServer(connection.ConnectionString).Options);
        var created = false;
        try
        {
            // Apply only Vuong's existing Content migrations to the unique disposable test database.
            await db.Database.MigrateAsync(); created = true;
            var root = new DirectoryInfo(AppContext.BaseDirectory);
            while (root is not null && !Directory.Exists(Path.Combine(root.FullName, "content-bank"))) root = root.Parent;
            Assert.NotNull(root);
            var sourcePath = Path.Combine(root!.FullName, "content-bank", "csgt-2025-https", "package.json");
            var sourceBytes = await File.ReadAllBytesAsync(sourcePath);
            using var source = JsonDocument.Parse(sourceBytes);
            var json = new JsonSerializerOptions(JsonSerializerDefaults.Web);
            var bank = source.RootElement.GetProperty("bank").Deserialize<ContentBank>(json)!;
            var settings = new AnimationSettings { AllowedHosts = ["content-animations.vercel.app"] };
            var manifests = new ContentManifestService(settings);
            var preflight = manifests.Preview(new() { Bank = bank });
            Assert.True(preflight.CanImport, string.Join("; ", preflight.Issues.Select(i => i.Message)));
            Assert.Equal(600, preflight.QuestionCount); Assert.Equal(115, preflight.AnimationCount);
            var repository = new SqlContentBankRepository(db);
            var banks = new QuestionBankService(repository, settings);
            var importer = new ContentBankImportService(manifests, banks);
            var request = new ImportQuestionBankRequestDto { Bank = bank, ExpectedManifestHash = preflight.ManifestHash };
            var imported = await importer.ImportAsync(request, Guid.NewGuid());
            Assert.Equal(600, await db.TrafficQuestions.CountAsync());
            Assert.Empty(await banks.ListAsync(false));
            await banks.PublishAsync(bank.Id, bank.Version, new() { ExpectedHash = imported.Summary.Hash, SourceAndAnswersReviewed = true });
            var again = await importer.ImportAsync(request, Guid.NewGuid());
            Assert.Equal(imported.Summary.Hash, again.Summary.Hash);
            Assert.Equal(600, await db.TrafficQuestions.CountAsync());
            Assert.Equal(115, await db.TrafficQuestions.CountAsync(q => q.ExplanationAnimationUrl != null));
            var preview = await banks.PreviewAsync(bank.Id, bank.Version);
            Assert.True(preview.Summary.IsPublished); Assert.Empty(preview.Errors);
            Assert.Equal(bank.Questions.Select(q => q.Id), preview.Bank.Questions.Select(q => q.Id));
            Assert.Equal(bank.Questions.Select(q => q.ExplanationAnimationUrl), preview.Bank.Questions.Select(q => q.ExplanationAnimationUrl));
            var page = await banks.GetQuestionsAsync(bank.Id, bank.Version, null, 486, 600, 1, 100);
            Assert.Equal(115, page.TotalCount);
            var publicJson = JsonSerializer.Serialize(page);
            Assert.DoesNotContain("Explanation", publicJson); Assert.DoesNotContain("CorrectOption", publicJson);
            var templates = new ExamTemplateService(new ExamTemplateRepository(db), new QuestionCatalogRepository(db), repository);
            var template = source.RootElement.GetProperty("templates")[0].Deserialize<ImportExamTemplateRequest>(json)!;
            var draft = await templates.ImportAsync(template, CancellationToken.None);
            Assert.False(draft.IsPublished);
            var published = await templates.PublishAsync(template.ExamCode, template.Version, CancellationToken.None);
            Assert.True(published.IsPublished); Assert.Equal(template.QuestionIds, published.QuestionIds);
            Assert.Equal(sourceBytes, await File.ReadAllBytesAsync(sourcePath));
        }
        finally
        {
            if (created)
            {
                Assert.StartsWith("PhucContentTests_", db.Database.GetDbConnection().Database);
                await db.Database.EnsureDeletedAsync();
            }
        }
    }
}
