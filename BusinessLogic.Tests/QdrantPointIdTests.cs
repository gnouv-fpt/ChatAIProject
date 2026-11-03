using BusinessLogic.Infrastructure;

namespace BusinessLogic.Tests;

public sealed class QdrantPointIdTests
{
    [Theory]
    [InlineData("c8d4fc96-31ad-4b62-b1e7-74e6a4afee80", "37436611361940844")]
    [InlineData("f3eafe19-a7f1-4491-8789-03d752b66071", "2652498304821066359")]
    public void MatchesPythonQdrantPointMapping(string chunkId, string pointId)
    {
        Assert.Equal(pointId, QdrantPointIds.FromChunkId(Guid.Parse(chunkId)));
    }
}
