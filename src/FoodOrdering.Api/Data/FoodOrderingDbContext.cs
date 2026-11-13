using FoodOrdering.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace FoodOrdering.Api.Data;

public sealed class FoodOrderingDbContext(DbContextOptions<FoodOrderingDbContext> options) : DbContext(options)
{
    public DbSet<Role> Roles => Set<Role>();
    public DbSet<User> Users => Set<User>();
    public DbSet<RefreshToken> RefreshTokens => Set<RefreshToken>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Role>(entity =>
        {
            entity.ToTable("Roles");
            entity.HasKey(role => role.RoleId);
            entity.Property(role => role.RoleName).HasMaxLength(20).IsRequired();
        });

        modelBuilder.Entity<User>(entity =>
        {
            entity.ToTable("Users");
            entity.HasKey(user => user.UserId);
            entity.Property(user => user.FullName).HasMaxLength(120).IsRequired();
            entity.Property(user => user.Email).HasMaxLength(254).IsRequired();
            entity.Property(user => user.PasswordHash).HasMaxLength(255).IsRequired();
            entity.Property(user => user.PhoneNumber).HasMaxLength(20);
            entity.HasIndex(user => user.Email).IsUnique();
            entity.HasOne(user => user.Role)
                .WithMany(role => role.Users)
                .HasForeignKey(user => user.RoleId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<RefreshToken>(entity =>
        {
            entity.ToTable("RefreshTokens");
            entity.HasKey(token => token.RefreshTokenId);
            entity.Property(token => token.TokenHash).HasMaxLength(255).IsRequired();
            entity.HasIndex(token => token.TokenHash).IsUnique();
            entity.HasOne(token => token.User)
                .WithMany(user => user.RefreshTokens)
                .HasForeignKey(token => token.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });
    }
}
