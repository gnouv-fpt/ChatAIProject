using System.Buffers.Binary;
using System.Globalization;
using System.Security.Cryptography;
using System.Text;

namespace BusinessLogic.Infrastructure;

public static class QdrantPointIds
{
    // Must match grpc_inference_service/rag/vector_store.py:chunk_id_to_point_id.
    public static string FromChunkId(Guid chunkId)
    {
        var hash = SHA256.HashData(Encoding.UTF8.GetBytes(chunkId.ToString("D")));
        var value = BinaryPrimitives.ReadUInt64BigEndian(hash.AsSpan(0, 8)) & long.MaxValue;
        return value.ToString(CultureInfo.InvariantCulture);
    }
}
