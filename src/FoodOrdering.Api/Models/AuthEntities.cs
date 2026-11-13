namespace FoodOrdering.Api.Models;

public sealed class Role
{
    public byte RoleId { get; set; }
    public required string RoleName { get; set; }
    public ICollection<User> Users { get; set; } = new List<User>();
}

public sealed class User
{
    public Guid UserId { get; set; }
    public required string FullName { get; set; }
    public required string Email { get; set; }
    public required string PasswordHash { get; set; }
    public string? PhoneNumber { get; set; }
    public byte RoleId { get; set; }
    public Role? Role { get; set; }
    public bool IsEmailVerified { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public ICollection<RefreshToken> RefreshTokens { get; set; } = new List<RefreshToken>();
}

public sealed class RefreshToken
{
    public Guid RefreshTokenId { get; set; }
    public Guid UserId { get; set; }
    public User? User { get; set; }
    public required string TokenHash { get; set; }
    public DateTime ExpiresAt { get; set; }
    public DateTime? RevokedAt { get; set; }
    public DateTime CreatedAt { get; set; }
}
