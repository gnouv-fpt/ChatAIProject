namespace BusinessObject.Constants;

// Statuses written by the quota module into ChatMessages.ResultStatus; other values come from the AI contract.
public static class ChatResultStatuses
{
    // The lease expired without a stored result, so provider usage for the turn is unknown.
    public const string UsageUnknown = "UsageUnknown";
}
