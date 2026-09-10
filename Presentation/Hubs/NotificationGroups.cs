namespace Presentation.Hubs;

public static class NotificationGroups
{
    public static string ForUser(int userId)
    {
        return $"notifications:user:{userId}";
    }
}
