using BusinessLogic.DTOs;
using BusinessLogic.Exceptions;
using BusinessLogic.Infrastructure.Settings;
using BusinessLogic.Protos;
using BusinessLogic.Services.Implementations;
using Grpc.Core;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace ChatAIWeb.Tests;

public sealed class GrpcAdapterTests
{
    private static ChatInferenceInputDto Input => new(Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), "test", [], [], 100);
    [Theory] [InlineData(StatusCode.Unavailable, 503)] [InlineData(StatusCode.DeadlineExceeded, 504)]
    public async Task RpcErrorsBecomeProblemStatusWithoutUpstreamDetails(StatusCode code, int expected)
    {
        var client = new FakeClient { Error = new RpcException(new Status(code, "private upstream details")) };
        var service = new GrpcInferenceService(client, NullLogger<GrpcInferenceService>.Instance, new ChatSettings());
        var exception = await Assert.ThrowsAnyAsync<AppException>(() => service.ProcessTurnAsync(Input));
        Assert.Equal(expected, exception.StatusCode); Assert.DoesNotContain("private", exception.Message);
    }
    [Fact] public async Task OldProtocolIsRejected()
    {
        var service = new GrpcInferenceService(new FakeClient { Response = new() }, NullLogger<GrpcInferenceService>.Instance, new ChatSettings());
        await Assert.ThrowsAsync<ServiceUnavailableException>(() => service.ProcessTurnAsync(Input));
    }
    [Fact] public async Task ImageHistoryRequestIdentityAndBudgetAreMapped()
    {
        var client = new FakeClient();
        var service = new GrpcInferenceService(client, NullLogger<GrpcInferenceService>.Instance, new ChatSettings());
        var input = Input with { Images = [new(Guid.NewGuid(), "image/png", [1, 2, 3])], History = [new("user", "previous question")] };
        await service.ProcessTurnAsync(input);
        Assert.Equal(input.RequestId.ToString(), client.Request!.RequestId);
        Assert.Equal(100, client.Request.MaxTokens); Assert.Single(client.Request.Images); Assert.Single(client.Request.History);
        Assert.NotNull(client.Options.Deadline);
    }
    [Fact] public async Task CallerCancellationIsPreserved()
    {
        using var ct = new CancellationTokenSource(); ct.Cancel();
        var service = new GrpcInferenceService(new FakeClient { Error = new RpcException(new Status(StatusCode.Cancelled, "cancelled")) }, NullLogger<GrpcInferenceService>.Instance, new ChatSettings());
        await Assert.ThrowsAnyAsync<OperationCanceledException>(() => service.ProcessTurnAsync(Input, ct.Token));
    }
    [Fact] public async Task MissingUsageIsNotInterpretedAsZero()
    {
        var client = new FakeClient(); client.Response.ClearTokensUsed();
        var service = new GrpcInferenceService(client, NullLogger<GrpcInferenceService>.Instance, new ChatSettings());
        await Assert.ThrowsAsync<ServiceUnavailableException>(() => service.ProcessTurnAsync(Input));
    }
    private sealed class FakeClient : TrafficRagInference.TrafficRagInferenceClient
    {
        public Exception? Error; public ChatInferenceRequest? Request; public CallOptions Options;
        public ChatInferenceResponse Response = new() { ContractVersion = 2, ResultStatus = "NoMatch", ResponseText = "Test fixture", ImagesProcessed = true, TokensUsed = 0 };
        public override AsyncUnaryCall<ChatInferenceResponse> ProcessChatMessageAsync(ChatInferenceRequest request, CallOptions options)
        {
            Request = request; Options = options;
            return new(Error == null ? Task.FromResult(Response) : Task.FromException<ChatInferenceResponse>(Error),
                Task.FromResult(new Metadata()), () => Status.DefaultSuccess, () => new Metadata(), () => { });
        }
    }
}
