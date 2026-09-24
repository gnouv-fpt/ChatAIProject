namespace BusinessLogic.Exceptions;

// Thrown by services; the Presentation global exception handler maps StatusCode to the HTTP response.
public class AppException : Exception
{
    public AppException(int statusCode, string message)
        : base(message)
    {
        StatusCode = statusCode;
    }

    public int StatusCode { get; }
}

public sealed class BadRequestException(string message) : AppException(400, message);

public sealed class UnauthorizedException(string message) : AppException(401, message);

public sealed class ForbiddenException(string message) : AppException(403, message);

public sealed class NotFoundException(string message) : AppException(404, message);

public sealed class ConflictException(string message) : AppException(409, message);
