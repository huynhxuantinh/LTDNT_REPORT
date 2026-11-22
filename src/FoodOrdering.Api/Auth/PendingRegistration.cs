namespace FoodOrdering.Api.Auth;

public sealed class PendingRegistration
{
    public Guid PendingRegistrationId { get; set; }
    public required string Email { get; set; }
    public required string FullName { get; set; }
    public required string TokenHash { get; set; }
    public int FailedAttempts { get; set; }
    public DateTime ExpiresAt { get; set; }
    public DateTime CreatedAt { get; set; }
}
