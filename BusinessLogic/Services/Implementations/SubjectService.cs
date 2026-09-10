using BusinessLogic.DTOs.Requests;
using BusinessLogic.DTOs.Responses;
using BusinessLogic.Infrastructure.Interfaces;
using BusinessLogic.Services.Interfaces;
using BusinessObject.Entities;
using BusinessObject.Enums;
using DataAccess.Repositories.Interfaces;
using DocumentFormat.OpenXml.Packaging;
using DocumentFormat.OpenXml.Spreadsheet;
using Microsoft.Extensions.Logging;

namespace BusinessLogic.Services.Implementations;

public sealed class SubjectService : ISubjectService
{
    private const string FilterCreated = "created";
    private const string FilterEnrolled = "enrolled";
    private const string FilterAll = "all";
    private const string FilterDeleted = "deleted";
    private const string FilterActive = "active";

    private readonly ISubjectRepository _subjectRepository;
    private readonly IUserRepository _userRepository;
    private readonly IChatRepository _chatRepository;
    private readonly ISubjectRealtimeNotifier _subjectRealtimeNotifier;
    private readonly INotificationService _notificationService;
    private readonly ILogger<SubjectService> _logger;

    public SubjectService(
        ISubjectRepository subjectRepository,
        IUserRepository userRepository,
        IChatRepository chatRepository,
        ISubjectRealtimeNotifier subjectRealtimeNotifier,
        INotificationService notificationService,
        ILogger<SubjectService> logger)
    {
        _subjectRepository = subjectRepository;
        _userRepository = userRepository;
        _chatRepository = chatRepository;
        _subjectRealtimeNotifier = subjectRealtimeNotifier;
        _notificationService = notificationService;
        _logger = logger;
    }

    public async Task<StudentDashboardDto> GetStudentDashboardAsync(
        int userId,
        CancellationToken cancellationToken = default)
    {
        var subjects = await _subjectRepository.GetAllAsync(cancellationToken);
        var userSessions = await _chatRepository.GetSessionsByUserAsync(userId, cancellationToken);

        var totalIndexed = subjects.Sum(s => s.Documents.Count(d => d.Status == DocumentStatus.Indexed));
        var sessionCount = userSessions.Count;

        var recentCourses = subjects
            .Take(6)
            .Select(s =>
            {
                var totalDocs = s.Documents.Count;
                var indexedDocs = s.Documents.Count(d => d.Status == DocumentStatus.Indexed);
                var chatCount = s.ChatSessions.Count(c => c.UserId == userId);
                var progress = totalDocs > 0 ? (int)Math.Round((double)indexedDocs / totalDocs * 100) : 0;
                return new RecentCourseDto(
                    s.Id,
                    s.SubjectCode,
                    s.SubjectName,
                    s.Description,
                    totalDocs,
                    indexedDocs,
                    chatCount,
                    progress);
            })
            .ToList();

        return new StudentDashboardDto(
            subjects.Count,
            sessionCount,
            totalIndexed,
            recentCourses);
    }

    public async Task<IReadOnlyList<SubjectDto>> GetAllSubjectsAsync(
        CancellationToken cancellationToken = default)
    {
        var subjects = await _subjectRepository.GetAllAsync(cancellationToken);
        return subjects.Select(subject => MapToDto(subject)).ToList();
    }

    public async Task<IReadOnlyList<SubjectDto>> GetManagementSubjectsAsync(
        int currentUserId,
        string? currentUserRole,
        string? filter,
        CancellationToken cancellationToken = default)
    {
        var subjects = string.Equals(currentUserRole, UserRoleNames.Admin, StringComparison.OrdinalIgnoreCase)
            ? await _subjectRepository.GetAllIncludingDeletedAsync(cancellationToken)
            : await _subjectRepository.GetAllAsync(cancellationToken);
        var normalizedFilter = NormalizeManagementFilter(filter, currentUserRole);

        var filteredSubjects = string.Equals(currentUserRole, UserRoleNames.Teacher, StringComparison.OrdinalIgnoreCase)
            ? subjects.Where(subject => IsTeacherParticipant(subject, currentUserId))
            : subjects;

        filteredSubjects = normalizedFilter switch
        {
            FilterDeleted => filteredSubjects.Where(subject => subject.IsDeleted),
            FilterAll => filteredSubjects,
            _ => filteredSubjects.Where(subject => !subject.IsDeleted)
        };

        return filteredSubjects
            .Select(subject => MapToDto(subject, currentUserId, currentUserRole))
            .ToList();
    }

    public async Task<IReadOnlyList<SubjectDto>> GetSelectableSubjectsAsync(
        int currentUserId,
        string? currentUserRole,
        string? filter,
        CancellationToken cancellationToken = default)
    {
        var subjects = await _subjectRepository.GetAllAsync(cancellationToken);

        if (string.Equals(currentUserRole, UserRoleNames.Student, StringComparison.OrdinalIgnoreCase))
        {
            return subjects
                .Where(subject => subject.Documents.Any(document => document.Status == DocumentStatus.Indexed))
                .Select(subject => MapToDto(subject, currentUserId, currentUserRole))
                .ToList();
        }

        if (string.Equals(currentUserRole, UserRoleNames.Teacher, StringComparison.OrdinalIgnoreCase))
        {
            return subjects
                .Where(subject => IsTeacherParticipant(subject, currentUserId))
                .Select(subject => MapToDto(subject, currentUserId, currentUserRole))
                .ToList();
        }

        return subjects
            .Select(subject => MapToDto(subject, currentUserId, currentUserRole))
            .ToList();
    }

    public async Task<SubjectDto?> GetSubjectByIdAsync(
        int id,
        CancellationToken cancellationToken = default)
    {
        var subject = await _subjectRepository.GetByIdAsync(id, cancellationToken);
        return subject is null ? null : MapToDto(subject);
    }

    public async Task<IReadOnlyList<SubjectMemberCandidateDto>> GetMemberCandidatesAsync(
        CancellationToken cancellationToken = default)
    {
        var users = await _userRepository.GetAllAsync(cancellationToken);
        return users
            .Where(user => user.IsActive && IsClassRole(user.Role))
            .Select(user => new SubjectMemberCandidateDto(
                user.Id,
                user.FullName,
                user.Email,
                NormalizeClassRole(user.Role)))
            .ToList();
    }

    public async Task<SubjectMembersDto?> GetSubjectMembersAsync(
        int subjectId,
        CancellationToken cancellationToken = default)
    {
        var subject = await _subjectRepository.GetByIdAsync(subjectId, cancellationToken);
        if (subject is null)
        {
            return null;
        }

        var candidates = await GetMemberCandidatesAsync(cancellationToken);
        var enrolledUserIds = subject.SubjectEnrollments.Select(enrollment => enrollment.UserId).ToHashSet();
        if (subject.CreatedBy.HasValue)
        {
            enrolledUserIds.Add(subject.CreatedBy.Value);
        }

        var headTeacher = ResolveHeadTeacher(subject);
        var members = subject.SubjectEnrollments
            .Where(enrollment => enrollment.User is not null)
            .Select(enrollment => new SubjectMemberDto(
                enrollment.Id,
                enrollment.UserId,
                enrollment.User.FullName,
                enrollment.User.Email,
                NormalizeClassRole(enrollment.RoleInClass),
                enrollment.CreatedAt,
                headTeacher?.Id == enrollment.UserId))
            .ToList();

        if (headTeacher is not null && members.All(member => member.UserId != headTeacher.Id))
        {
            members.Add(new SubjectMemberDto(
                null,
                headTeacher.Id,
                headTeacher.FullName,
                headTeacher.Email,
                UserRoleNames.Teacher,
                subject.CreatedAt,
                true));
        }

        return new SubjectMembersDto(
            subject.Id,
            subject.SubjectCode,
            subject.SubjectName,
            headTeacher?.Id,
            headTeacher?.FullName,
            members
                .OrderBy(member => member.RoleInClass == UserRoleNames.Teacher ? 0 : 1)
                .ThenBy(member => member.FullName)
                .ToList(),
            candidates
                .Where(candidate => !enrolledUserIds.Contains(candidate.UserId))
                .ToList());
    }

    public Task<bool> CanManageSubjectAsync(
        int subjectId,
        int currentUserId,
        string? currentUserRole,
        CancellationToken cancellationToken = default)
    {
        return Task.FromResult(string.Equals(currentUserRole, UserRoleNames.Admin, StringComparison.OrdinalIgnoreCase));
    }

    public async Task<OperationResult> EnrollStudentAsync(
        int subjectId,
        int studentId,
        CancellationToken cancellationToken = default)
    {
        var subject = await _subjectRepository.GetByIdAsync(subjectId, cancellationToken);
        if (subject is null)
        {
            return new OperationResult(false, "Không tìm thấy môn học.");
        }

        if (!subject.Documents.Any(document => document.Status == DocumentStatus.Indexed))
        {
            return new OperationResult(false, "Môn học này chưa có tài liệu đã index.");
        }

        var alreadyEnrolled = subject.SubjectEnrollments.Any(enrollment =>
            enrollment.UserId == studentId
            && string.Equals(enrollment.RoleInClass, UserRoleNames.Student, StringComparison.OrdinalIgnoreCase));

        if (alreadyEnrolled)
        {
            return new OperationResult(true, "Bạn đã tham gia môn học này.");
        }

        await _subjectRepository.AddEnrollmentAsync(
            new SubjectEnrollment
            {
                SubjectId = subjectId,
                UserId = studentId,
                RoleInClass = UserRoleNames.Student,
                CreatedAt = DateTime.UtcNow
            },
            cancellationToken);

        return new OperationResult(true, "Tham gia môn học thành công.");
    }

    public async Task<OperationResult> AddSubjectMemberAsync(
        AddSubjectMemberRequestDto request,
        CancellationToken cancellationToken = default)
    {
        var subject = await _subjectRepository.GetByIdAsync(request.SubjectId, cancellationToken);
        if (subject is null)
        {
            return new OperationResult(false, "Không tìm thấy môn học.");
        }

        var user = await _userRepository.GetByIdAsync(request.UserId, cancellationToken);
        if (user is null || !user.IsActive)
        {
            return new OperationResult(false, "Không tìm thấy người dùng hợp lệ.");
        }

        if (!TryNormalizeClassRole(request.RoleInClass, out var roleInClass)
            || !string.Equals(user.Role, roleInClass, StringComparison.OrdinalIgnoreCase))
        {
            return new OperationResult(false, "Role trong môn học phải khớp với role tài khoản.");
        }

        await _subjectRepository.AddOrUpdateEnrollmentAsync(
            request.SubjectId,
            request.UserId,
            roleInClass,
            cancellationToken);

        const string message = "Đã cập nhật thành viên môn học.";
        var recipients = await ResolveSubjectRecipientIdsAsync(
            request.SubjectId,
            cancellationToken,
            request.UserId);
        await NotifyUsersSafelyAsync(
            recipients,
            "Thành viên môn học đã thay đổi",
            message,
            "SubjectMemberAdded",
            request.SubjectId,
            cancellationToken);
        await NotifySubjectMembersChangedSafelyAsync(
            request.SubjectId,
            "SubjectMemberAdded",
            message,
            recipients,
            cancellationToken);

        return new OperationResult(true, message);
    }

    public async Task<OperationResult> RemoveSubjectMemberAsync(
        int subjectId,
        int enrollmentId,
        CancellationToken cancellationToken = default)
    {
        var subject = await _subjectRepository.GetByIdAsync(subjectId, cancellationToken);
        if (subject is null)
        {
            return new OperationResult(false, "Không tìm thấy môn học.");
        }

        var enrollment = subject.SubjectEnrollments.FirstOrDefault(item => item.Id == enrollmentId);
        if (enrollment is null)
        {
            return new OperationResult(false, "Không tìm thấy thành viên trong môn học.");
        }

        if (subject.CreatedBy == enrollment.UserId
            && string.Equals(enrollment.RoleInClass, UserRoleNames.Teacher, StringComparison.OrdinalIgnoreCase))
        {
            return new OperationResult(false, "Không thể xóa trưởng bộ môn. Hãy đổi trưởng bộ môn trước.");
        }

        var recipients = await ResolveSubjectRecipientIdsAsync(
            subjectId,
            cancellationToken,
            enrollment.UserId);

        await _subjectRepository.DeleteEnrollmentAsync(enrollmentId, cancellationToken);
        const string message = "Đã xóa thành viên khỏi môn học.";
        await NotifyUsersSafelyAsync(
            recipients,
            "Thành viên môn học đã thay đổi",
            message,
            "SubjectMemberRemoved",
            subjectId,
            cancellationToken);
        await NotifySubjectMembersChangedSafelyAsync(
            subjectId,
            "SubjectMemberRemoved",
            message,
            recipients,
            cancellationToken);

        return new OperationResult(true, message);
    }

    public async Task<OperationResult> ImportSubjectMembersAsync(
        ImportSubjectMembersRequestDto request,
        CancellationToken cancellationToken = default)
    {
        var subject = await _subjectRepository.GetByIdAsync(request.SubjectId, cancellationToken);
        if (subject is null)
        {
            return new OperationResult(false, "Không tìm thấy môn học.");
        }

        var rows = ReadImportRows(request.FileStream, request.FileName);
        if (rows.Count == 0)
        {
            return new OperationResult(false, "File import không có dữ liệu hợp lệ.");
        }

        var imported = 0;
        var skipped = 0;

        foreach (var row in rows)
        {
            cancellationToken.ThrowIfCancellationRequested();
            var result = await ImportMemberRowAsync(request.SubjectId, row.Email, row.RoleInClass, cancellationToken);
            if (result)
            {
                imported++;
            }
            else
            {
                skipped++;
            }
        }

        var message = imported > 0
            ? $"Đã import {imported} thành viên. Bỏ qua {skipped} dòng không hợp lệ."
            : "Không có dòng nào được import. Kiểm tra email và role trong file.";
        if (imported > 0)
        {
            var recipients = await ResolveSubjectRecipientIdsAsync(request.SubjectId, cancellationToken);
            await NotifyUsersSafelyAsync(
                recipients,
                "Danh sách lớp đã thay đổi",
                message,
                "SubjectMembersImported",
                request.SubjectId,
                cancellationToken);
            await NotifySubjectMembersChangedSafelyAsync(
                request.SubjectId,
                "SubjectMembersImported",
                message,
                recipients,
                cancellationToken);
        }

        return new OperationResult(imported > 0, message);
    }

    public async Task<OperationResult> CreateSubjectAsync(
        CreateSubjectRequestDto request,
        CancellationToken cancellationToken = default)
    {
        if (request.HeadTeacherId.HasValue
            && !await IsValidHeadTeacherAsync(request.HeadTeacherId.Value, cancellationToken))
        {
            return new OperationResult(false, "Trưởng bộ môn phải là tài khoản giảng viên đang hoạt động.");
        }

        try
        {
            var subject = new Subject
            {
                SubjectCode = request.SubjectCode.Trim(),
                SubjectName = request.SubjectName.Trim(),
                Description = request.Description?.Trim(),
                CreatedBy = request.HeadTeacherId,
                CreatedAt = DateTime.UtcNow
            };

            await _subjectRepository.AddAsync(subject, cancellationToken);

            if (request.HeadTeacherId.HasValue)
            {
                await _subjectRepository.AddOrUpdateEnrollmentAsync(
                    subject.Id,
                    request.HeadTeacherId.Value,
                    UserRoleNames.Teacher,
                    cancellationToken);
            }

            _logger.LogInformation("Created subject {Code} by user {UserId}", subject.SubjectCode, request.CreatedBy);
            const string message = "Tạo môn học thành công.";
            var recipients = await ResolveSubjectRecipientIdsAsync(subject.Id, cancellationToken);
            await NotifyUsersSafelyAsync(
                recipients,
                "Môn học mới",
                $"Môn học {subject.SubjectCode} - {subject.SubjectName} đã được tạo.",
                "SubjectCreated",
                subject.Id,
                cancellationToken);
            await NotifySubjectChangedSafelyAsync(
                subject.Id,
                "SubjectCreated",
                message,
                recipients,
                cancellationToken);

            return new OperationResult(true, message);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to create subject {Code}", request.SubjectCode);
            return new OperationResult(false, "Có lỗi khi tạo môn học. Mã môn học có thể đã tồn tại.");
        }
    }

    public async Task<OperationResult> UpdateSubjectAsync(
        UpdateSubjectRequestDto request,
        CancellationToken cancellationToken = default)
    {
        if (request.HeadTeacherId.HasValue
            && !await IsValidHeadTeacherAsync(request.HeadTeacherId.Value, cancellationToken))
        {
            return new OperationResult(false, "Trưởng bộ môn phải là tài khoản giảng viên đang hoạt động.");
        }

        var subject = await _subjectRepository.GetByIdAsync(request.Id, cancellationToken);
        if (subject is null)
        {
            return new OperationResult(false, "Không tìm thấy môn học.");
        }

        try
        {
            subject.SubjectCode = request.SubjectCode.Trim();
            subject.SubjectName = request.SubjectName.Trim();
            subject.Description = request.Description?.Trim();
            subject.CreatedBy = request.HeadTeacherId;
            subject.UpdatedAt = DateTime.UtcNow;

            await _subjectRepository.UpdateAsync(subject, cancellationToken);

            if (request.HeadTeacherId.HasValue)
            {
                await _subjectRepository.AddOrUpdateEnrollmentAsync(
                    request.Id,
                    request.HeadTeacherId.Value,
                    UserRoleNames.Teacher,
                    cancellationToken);
            }

            _logger.LogInformation("Updated subject {Id}", subject.Id);
            const string message = "Cập nhật môn học thành công.";
            var recipients = await ResolveSubjectRecipientIdsAsync(subject.Id, cancellationToken);
            await NotifyUsersSafelyAsync(
                recipients,
                "Môn học đã cập nhật",
                $"Môn học {subject.SubjectCode} - {subject.SubjectName} đã được cập nhật.",
                "SubjectUpdated",
                subject.Id,
                cancellationToken);
            await NotifySubjectChangedSafelyAsync(
                subject.Id,
                "SubjectUpdated",
                message,
                recipients,
                cancellationToken);

            return new OperationResult(true, message);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to update subject {Id}", request.Id);
            return new OperationResult(false, "Có lỗi khi cập nhật môn học. Mã môn học có thể đã tồn tại.");
        }
    }

    public async Task<OperationResult> DeleteSubjectAsync(
        int id,
        int deletedBy,
        string? reason,
        CancellationToken cancellationToken = default)
    {
        var subject = await _subjectRepository.GetByIdIncludingDeletedAsync(id, cancellationToken);
        if (subject is null)
        {
            return new OperationResult(false, "Không tìm thấy môn học.");
        }

        if (subject.IsDeleted)
        {
            return new OperationResult(true, "Môn học đã được xóa trước đó.");
        }

        try
        {
            var recipients = await ResolveSubjectRecipientIdsAsync(id, cancellationToken);
            await _subjectRepository.SoftDeleteAsync(subject, deletedBy, reason, cancellationToken);

            _logger.LogInformation("Soft deleted subject {Id} by user {UserId}", id, deletedBy);
            const string message = "Đã xóa môn học.";
            await NotifyUsersSafelyAsync(
                recipients,
                "Môn học đã bị gỡ",
                $"Môn học {subject.SubjectCode} - {subject.SubjectName} đã bị gỡ khỏi hệ thống học tập.",
                "SubjectDeleted",
                id,
                cancellationToken);
            await NotifySubjectChangedSafelyAsync(
                id,
                "SubjectDeleted",
                message,
                recipients,
                cancellationToken);

            return new OperationResult(true, message);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to soft delete subject {Id}", id);
            return new OperationResult(false, "Không thể xóa môn học.");
        }
    }

    public async Task<OperationResult> RestoreSubjectAsync(
        int id,
        int restoredBy,
        CancellationToken cancellationToken = default)
    {
        var subject = await _subjectRepository.GetByIdIncludingDeletedAsync(id, cancellationToken);
        if (subject is null)
        {
            return new OperationResult(false, "Không tìm thấy môn học.");
        }

        if (!subject.IsDeleted)
        {
            return new OperationResult(true, "Môn học đang hoạt động.");
        }

        try
        {
            await _subjectRepository.RestoreAsync(subject, cancellationToken);
            _logger.LogInformation("Restored subject {Id} by user {UserId}", id, restoredBy);
            const string message = "Đã khôi phục môn học.";
            var recipients = await ResolveSubjectRecipientIdsAsync(id, cancellationToken);
            await NotifyUsersSafelyAsync(
                recipients,
                "Môn học đã khôi phục",
                $"Môn học {subject.SubjectCode} - {subject.SubjectName} đã được khôi phục.",
                "SubjectRestored",
                id,
                cancellationToken);
            await NotifySubjectChangedSafelyAsync(
                id,
                "SubjectRestored",
                message,
                recipients,
                cancellationToken);

            return new OperationResult(true, message);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to restore subject {Id}", id);
            return new OperationResult(false, "Không thể khôi phục môn học.");
        }
    }

    private async Task NotifySubjectChangedSafelyAsync(
        int subjectId,
        string action,
        string message,
        IReadOnlyCollection<int> recipientUserIds,
        CancellationToken cancellationToken)
    {
        try
        {
            await _subjectRealtimeNotifier.NotifySubjectChangedAsync(
                subjectId,
                action,
                message,
                recipientUserIds,
                cancellationToken);
        }
        catch (Exception exception)
        {
            _logger.LogWarning(
                exception,
                "Could not broadcast subject realtime event {Action} for subject {SubjectId}",
                action,
                subjectId);
        }
    }

    private async Task NotifySubjectMembersChangedSafelyAsync(
        int subjectId,
        string action,
        string message,
        IReadOnlyCollection<int> recipientUserIds,
        CancellationToken cancellationToken)
    {
        try
        {
            await _subjectRealtimeNotifier.NotifySubjectMembersChangedAsync(
                subjectId,
                action,
                message,
                recipientUserIds,
                cancellationToken);
        }
        catch (Exception exception)
        {
            _logger.LogWarning(
                exception,
                "Could not broadcast subject members realtime event {Action} for subject {SubjectId}",
                action,
                subjectId);
        }
    }

    private async Task<IReadOnlyCollection<int>> ResolveSubjectRecipientIdsAsync(
        int subjectId,
        CancellationToken cancellationToken,
        params int[] extraUserIds)
    {
        var subject = await _subjectRepository.GetByIdIncludingDeletedAsync(subjectId, cancellationToken);
        var adminIds = await GetActiveAdminIdsAsync(cancellationToken);
        if (subject is null)
        {
            return adminIds
                .Concat(extraUserIds)
                .Where(userId => userId > 0)
                .Distinct()
                .ToList();
        }

        return adminIds
            .Concat(subject.SubjectEnrollments
                .Where(enrollment => enrollment.User is { IsActive: true })
                .Select(enrollment => enrollment.UserId))
            .Concat(subject.CreatedBy.HasValue && subject.CreatedByNavigation?.IsActive == true
                ? new[] { subject.CreatedBy.Value }
                : [])
            .Concat(extraUserIds)
            .Where(userId => userId > 0)
            .Distinct()
            .ToList();
    }

    private async Task<IReadOnlyCollection<int>> GetActiveAdminIdsAsync(CancellationToken cancellationToken)
    {
        var users = await _userRepository.GetAllAsync(cancellationToken);
        return users
            .Where(user => user.IsActive
                && string.Equals(user.Role, UserRoleNames.Admin, StringComparison.OrdinalIgnoreCase))
            .Select(user => user.Id)
            .ToList();
    }

    private async Task NotifyUsersSafelyAsync(
        IReadOnlyCollection<int> recipientUserIds,
        string title,
        string message,
        string type,
        int? relatedSubjectId,
        CancellationToken cancellationToken)
    {
        try
        {
            await _notificationService.NotifyUsersAsync(
                recipientUserIds,
                title,
                message,
                type,
                relatedSubjectId,
                cancellationToken);
        }
        catch (Exception exception)
        {
            _logger.LogWarning(
                exception,
                "Could not create subject notification {Type} for subject {SubjectId}",
                type,
                relatedSubjectId);
        }
    }

    private async Task<bool> ImportMemberRowAsync(
        int subjectId,
        string email,
        string? requestedRole,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(email))
        {
            return false;
        }

        var user = await _userRepository.GetByEmailAsync(email.Trim(), cancellationToken);
        if (user is null || !user.IsActive || !IsClassRole(user.Role))
        {
            return false;
        }

        var role = string.IsNullOrWhiteSpace(requestedRole)
            ? NormalizeClassRole(user.Role)
            : requestedRole.Trim();

        if (!TryNormalizeClassRole(role, out var roleInClass)
            || !string.Equals(user.Role, roleInClass, StringComparison.OrdinalIgnoreCase))
        {
            return false;
        }

        await _subjectRepository.AddOrUpdateEnrollmentAsync(subjectId, user.Id, roleInClass, cancellationToken);
        return true;
    }

    private async Task<bool> IsValidHeadTeacherAsync(
        int userId,
        CancellationToken cancellationToken)
    {
        var user = await _userRepository.GetByIdAsync(userId, cancellationToken);
        return user is not null
            && user.IsActive
            && string.Equals(user.Role, UserRoleNames.Teacher, StringComparison.OrdinalIgnoreCase);
    }

    private static string NormalizeManagementFilter(string? filter, string? currentUserRole)
    {
        if (string.Equals(currentUserRole, UserRoleNames.Admin, StringComparison.OrdinalIgnoreCase))
        {
            if (string.Equals(filter, FilterDeleted, StringComparison.OrdinalIgnoreCase))
            {
                return FilterDeleted;
            }

            if (string.Equals(filter, FilterAll, StringComparison.OrdinalIgnoreCase))
            {
                return FilterAll;
            }

            return FilterActive;
        }

        if (string.Equals(filter, FilterCreated, StringComparison.OrdinalIgnoreCase))
        {
            return FilterCreated;
        }

        if (string.Equals(filter, FilterEnrolled, StringComparison.OrdinalIgnoreCase))
        {
            return FilterEnrolled;
        }

        return string.Equals(currentUserRole, UserRoleNames.Teacher, StringComparison.OrdinalIgnoreCase)
            ? FilterEnrolled
            : FilterActive;
    }

    private static bool IsTeacherParticipant(Subject subject, int userId)
    {
        return subject.CreatedBy == userId
            || subject.SubjectEnrollments.Any(enrollment =>
                enrollment.UserId == userId
                && string.Equals(enrollment.RoleInClass, UserRoleNames.Teacher, StringComparison.OrdinalIgnoreCase));
    }

    private static User? ResolveHeadTeacher(Subject subject)
    {
        return subject.CreatedByNavigation is not null
            && string.Equals(subject.CreatedByNavigation.Role, UserRoleNames.Teacher, StringComparison.OrdinalIgnoreCase)
                ? subject.CreatedByNavigation
                : null;
    }

    private static SubjectDto MapToDto(
        Subject s,
        int? currentUserId = null,
        string? currentUserRole = null)
    {
        var totalDocs = s.Documents.Count;
        var indexedDocs = s.Documents.Count(d => d.Status == DocumentStatus.Indexed);
        var students = s.SubjectEnrollments.Count(e =>
            string.Equals(e.RoleInClass, UserRoleNames.Student, StringComparison.OrdinalIgnoreCase));
        var headTeacher = ResolveHeadTeacher(s);
        var teacherIds = s.SubjectEnrollments
            .Where(e => string.Equals(e.RoleInClass, UserRoleNames.Teacher, StringComparison.OrdinalIgnoreCase))
            .Select(e => e.UserId)
            .Concat(headTeacher is null ? [] : new[] { headTeacher.Id })
            .Distinct()
            .ToList();
        var isTeacherEnrolled = currentUserId.HasValue
            && IsTeacherParticipant(s, currentUserId.Value);
        var isStudentEnrolled = currentUserId.HasValue
            && s.SubjectEnrollments.Any(e =>
                e.UserId == currentUserId.Value
                && string.Equals(e.RoleInClass, UserRoleNames.Student, StringComparison.OrdinalIgnoreCase));
        var canManage = string.Equals(currentUserRole, UserRoleNames.Admin, StringComparison.OrdinalIgnoreCase);
        var teacherNames = s.SubjectEnrollments
            .Where(e => string.Equals(e.RoleInClass, UserRoleNames.Teacher, StringComparison.OrdinalIgnoreCase))
            .Select(e => e.User?.FullName ?? "Giảng viên")
            .Concat(headTeacher is null ? [] : new[] { headTeacher.FullName })
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();
        var memberNames = s.SubjectEnrollments
            .OrderBy(e => string.Equals(e.RoleInClass, UserRoleNames.Student, StringComparison.OrdinalIgnoreCase) ? 0 : 1)
            .ThenBy(e => e.User?.FullName)
            .Select(e => e.User?.FullName ?? (string.Equals(e.RoleInClass, UserRoleNames.Student, StringComparison.OrdinalIgnoreCase) ? "Sinh viên" : "Giảng viên"))
            .Concat(headTeacher is null ? [] : new[] { headTeacher.FullName })
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();

        return new SubjectDto(
            s.Id,
            s.SubjectCode,
            s.SubjectName,
            s.Description,
            totalDocs,
            indexedDocs,
            students,
            teacherIds.Count,
            s.CreatedAt,
            headTeacher?.Id,
            headTeacher?.FullName,
            isTeacherEnrolled,
            isStudentEnrolled,
            canManage,
            s.IsDeleted,
            s.DeletedAt,
            s.DeleteReason,
            teacherNames,
            memberNames);
    }

    private static bool IsClassRole(string? role)
    {
        return string.Equals(role, UserRoleNames.Teacher, StringComparison.OrdinalIgnoreCase)
            || string.Equals(role, UserRoleNames.Student, StringComparison.OrdinalIgnoreCase);
    }

    private static bool TryNormalizeClassRole(string? role, out string normalizedRole)
    {
        normalizedRole = string.Empty;
        if (string.Equals(role, UserRoleNames.Teacher, StringComparison.OrdinalIgnoreCase))
        {
            normalizedRole = UserRoleNames.Teacher;
            return true;
        }

        if (string.Equals(role, UserRoleNames.Student, StringComparison.OrdinalIgnoreCase))
        {
            normalizedRole = UserRoleNames.Student;
            return true;
        }

        return false;
    }

    private static string NormalizeClassRole(string role)
    {
        return string.Equals(role, UserRoleNames.Teacher, StringComparison.OrdinalIgnoreCase)
            ? UserRoleNames.Teacher
            : UserRoleNames.Student;
    }

    private static IReadOnlyList<ImportMemberRow> ReadImportRows(Stream stream, string fileName)
    {
        var extension = Path.GetExtension(fileName).ToLowerInvariant();
        if (extension is ".xlsx" or ".xlsm")
        {
            return ReadSpreadsheetRows(stream);
        }

        if (extension is ".csv" or ".xls")
        {
            return ReadCsvRows(stream);
        }

        return [];
    }

    private static IReadOnlyList<ImportMemberRow> ReadCsvRows(Stream stream)
    {
        using var reader = new StreamReader(stream, leaveOpen: true);
        var rows = new List<ImportMemberRow>();
        var lineIndex = 0;
        while (!reader.EndOfStream)
        {
            var line = reader.ReadLine();
            lineIndex++;
            if (string.IsNullOrWhiteSpace(line))
            {
                continue;
            }

            var values = SplitCsvLine(line);
            if (lineIndex == 1 && IsHeader(values))
            {
                continue;
            }

            var email = values.ElementAtOrDefault(0)?.Trim() ?? string.Empty;
            var role = values.ElementAtOrDefault(1)?.Trim();
            rows.Add(new ImportMemberRow(email, role));
        }

        return rows;
    }

    private static IReadOnlyList<ImportMemberRow> ReadSpreadsheetRows(Stream stream)
    {
        using var document = SpreadsheetDocument.Open(stream, false);
        var workbookPart = document.WorkbookPart;
        var worksheetPart = workbookPart?.WorksheetParts.FirstOrDefault();
        if (workbookPart is null || worksheetPart is null)
        {
            return [];
        }

        var rows = worksheetPart.Worksheet.Descendants<Row>().ToList();
        var result = new List<ImportMemberRow>();
        var index = 0;
        foreach (var row in rows)
        {
            var values = row.Elements<Cell>()
                .Select(cell => GetCellValue(workbookPart, cell))
                .ToList();
            index++;
            if (values.All(string.IsNullOrWhiteSpace))
            {
                continue;
            }

            if (index == 1 && IsHeader(values))
            {
                continue;
            }

            result.Add(new ImportMemberRow(
                values.ElementAtOrDefault(0)?.Trim() ?? string.Empty,
                values.ElementAtOrDefault(1)?.Trim()));
        }

        return result;
    }

    private static string GetCellValue(WorkbookPart workbookPart, Cell cell)
    {
        var value = cell.CellValue?.Text ?? string.Empty;
        if (cell.DataType?.Value == CellValues.SharedString
            && int.TryParse(value, out var sharedStringIndex))
        {
            return workbookPart.SharedStringTablePart?.SharedStringTable
                .Elements<SharedStringItem>()
                .ElementAtOrDefault(sharedStringIndex)
                ?.InnerText ?? string.Empty;
        }

        return value;
    }

    private static bool IsHeader(IReadOnlyList<string> values)
    {
        var first = values.ElementAtOrDefault(0)?.Trim();
        return string.Equals(first, "email", StringComparison.OrdinalIgnoreCase)
            || string.Equals(first, "mail", StringComparison.OrdinalIgnoreCase)
            || string.Equals(first, "useremail", StringComparison.OrdinalIgnoreCase);
    }

    private static IReadOnlyList<string> SplitCsvLine(string line)
    {
        return line.Split(',')
            .Select(value => value.Trim().Trim('"'))
            .ToList();
    }

    private sealed record ImportMemberRow(string Email, string? RoleInClass);
}
