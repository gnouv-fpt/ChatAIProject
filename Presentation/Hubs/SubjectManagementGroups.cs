namespace Presentation.Hubs;

public static class SubjectManagementGroups
{
    public const string Admins = "subject-management:admins";

    public static string ForUser(int userId)
    {
        return $"subject-management:user:{userId}";
    }

    public static string ForMembers(int subjectId)
    {
        return $"subject-management:members:{subjectId}";
    }
}
