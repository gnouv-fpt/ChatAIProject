namespace BusinessObject.Constants;

// Values stored in ChatMessages.TurnState. Null means a legacy message created before durable turns.
public static class ChatTurnStates
{
    public const string Processing = "Processing";
    public const string Completed = "Completed";
    public const string Failed = "Failed";
}
