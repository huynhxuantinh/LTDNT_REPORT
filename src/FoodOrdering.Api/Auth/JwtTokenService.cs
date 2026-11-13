using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using FoodOrdering.Api.Models;
using Microsoft.IdentityModel.Tokens;

namespace FoodOrdering.Api.Auth;

public sealed class JwtOptions
{
    public required string Issuer { get; init; }
    public required string Audience { get; init; }
    public required string Key { get; init; }
    public int AccessTokenMinutes { get; init; } = 30;
}

public interface ITokenService
{
    string CreateAccessToken(User user);
}

public sealed class JwtTokenService(JwtOptions options) : ITokenService
{
    public string CreateAccessToken(User user)
    {
        var claims = new[]
        {
            new Claim(ClaimTypes.NameIdentifier, user.UserId.ToString()),
            new Claim(ClaimTypes.Name, user.FullName),
            new Claim(ClaimTypes.Email, user.Email),
            new Claim(ClaimTypes.Role, user.Role?.RoleName ?? "Member"),
        };

        var signingKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(options.Key));
        var token = new JwtSecurityToken(
            issuer: options.Issuer,
            audience: options.Audience,
            claims: claims,
            expires: DateTime.UtcNow.AddMinutes(options.AccessTokenMinutes),
            signingCredentials: new SigningCredentials(signingKey, SecurityAlgorithms.HmacSha256));

        return new JwtSecurityTokenHandler().WriteToken(token);
    }
}
