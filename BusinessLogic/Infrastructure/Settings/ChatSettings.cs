namespace BusinessLogic.Infrastructure.Settings;

public sealed class ChatSettings
{
    public int ReservationTokens { get; set; } = 4096;
    public int InferenceTimeoutSeconds { get; set; } = 60;
    public string AttachmentRoot { get; set; } = "data/attachments";
    public int AttachmentRetentionHours { get; set; } = 24;
    public int MaxAttachmentBytes { get; set; } = 5 * 1024 * 1024;
    public long MaxUserAttachmentBytes { get; set; } = 50 * 1024 * 1024;
}
