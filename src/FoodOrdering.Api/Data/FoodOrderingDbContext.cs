using FoodOrdering.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace FoodOrdering.Api.Data;

public sealed class FoodOrderingDbContext(DbContextOptions<FoodOrderingDbContext> options) : DbContext(options)
{
    public DbSet<Role> Roles => Set<Role>();
    public DbSet<User> Users => Set<User>();
    public DbSet<RefreshToken> RefreshTokens => Set<RefreshToken>();
    public DbSet<EmailVerificationToken> EmailVerificationTokens => Set<EmailVerificationToken>();
    public DbSet<PasswordResetToken> PasswordResetTokens => Set<PasswordResetToken>();
    public DbSet<Category> Categories => Set<Category>();
    public DbSet<FoodItem> FoodItems => Set<FoodItem>();
    public DbSet<Cart> Carts => Set<Cart>();
    public DbSet<CartItem> CartItems => Set<CartItem>();
    public DbSet<DiningTable> DiningTables => Set<DiningTable>();
    public DbSet<OrderStatus> OrderStatuses => Set<OrderStatus>();
    public DbSet<FoodOrder> Orders => Set<FoodOrder>();
    public DbSet<OrderDetail> OrderDetails => Set<OrderDetail>();
    public DbSet<Payment> Payments => Set<Payment>();
    public DbSet<OrderStatusHistory> OrderStatusHistories => Set<OrderStatusHistory>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Role>(entity =>
        {
            entity.ToTable("Roles");
            entity.HasKey(x => x.RoleId);
            entity.Property(x => x.RoleName).HasMaxLength(20).IsRequired();
        });

        modelBuilder.Entity<User>(entity =>
        {
            entity.ToTable("Users");
            entity.HasKey(x => x.UserId);
            entity.Property(x => x.FullName).HasMaxLength(120).IsRequired();
            entity.Property(x => x.Email).HasMaxLength(254).IsRequired();
            entity.Property(x => x.PasswordHash).HasMaxLength(255).IsRequired();
            entity.Property(x => x.PhoneNumber).HasMaxLength(20);
            entity.HasIndex(x => x.Email).IsUnique();
            entity.HasOne(x => x.Role).WithMany(x => x.Users).HasForeignKey(x => x.RoleId).OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<RefreshToken>(entity =>
        {
            entity.ToTable("RefreshTokens");
            entity.HasKey(x => x.RefreshTokenId);
            entity.Property(x => x.TokenHash).HasMaxLength(255).IsRequired();
            entity.HasIndex(x => x.TokenHash).IsUnique();
            entity.HasOne(x => x.User).WithMany(x => x.RefreshTokens).HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<EmailVerificationToken>(entity =>
        {
            entity.ToTable("EmailVerificationTokens");
            entity.HasKey(x => x.EmailVerificationTokenId);
            entity.Property(x => x.TokenHash).HasMaxLength(255).IsRequired();
            entity.HasIndex(x => x.TokenHash).IsUnique();
            entity.HasOne(x => x.User).WithMany(x => x.EmailVerificationTokens).HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<PasswordResetToken>(entity =>
        {
            entity.ToTable("PasswordResetTokens");
            entity.HasKey(x => x.PasswordResetTokenId);
            entity.Property(x => x.TokenHash).HasMaxLength(255).IsRequired();
            entity.HasIndex(x => x.TokenHash).IsUnique();
            entity.HasOne(x => x.User).WithMany(x => x.PasswordResetTokens).HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<Category>(entity =>
        {
            entity.ToTable("Categories");
            entity.HasKey(x => x.CategoryId);
            entity.Property(x => x.Name).HasMaxLength(100).IsRequired();
            entity.Property(x => x.Description).HasMaxLength(500);
            entity.Property(x => x.ImageUrl).HasMaxLength(500);
            entity.HasIndex(x => x.Name).IsUnique();
        });

        modelBuilder.Entity<FoodItem>(entity =>
        {
            entity.ToTable("FoodItems");
            entity.HasKey(x => x.FoodItemId);
            entity.Property(x => x.Name).HasMaxLength(150).IsRequired();
            entity.Property(x => x.Price).HasPrecision(18, 2);
            entity.Property(x => x.ImageUrl).HasMaxLength(500);
            entity.HasIndex(x => new { x.CategoryId, x.Name }).IsUnique();
            entity.HasIndex(x => new { x.CategoryId, x.IsAvailable });
            entity.HasOne(x => x.Category).WithMany(x => x.FoodItems).HasForeignKey(x => x.CategoryId).OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<Cart>(entity =>
        {
            entity.ToTable("Carts");
            entity.HasKey(x => x.CartId);
            entity.HasIndex(x => x.UserId).IsUnique();
            entity.HasOne(x => x.User).WithOne(x => x.Cart).HasForeignKey<Cart>(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<CartItem>(entity =>
        {
            entity.ToTable("CartItems");
            entity.HasKey(x => x.CartItemId);
            entity.Property(x => x.UnitPrice).HasPrecision(18, 2);
            entity.HasIndex(x => new { x.CartId, x.FoodItemId }).IsUnique();
            entity.HasIndex(x => x.CartId);
            entity.HasOne(x => x.Cart).WithMany(x => x.CartItems).HasForeignKey(x => x.CartId).OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(x => x.FoodItem).WithMany(x => x.CartItems).HasForeignKey(x => x.FoodItemId).OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<DiningTable>(entity =>
        {
            entity.ToTable("DiningTables");
            entity.HasKey(x => x.TableId);
            entity.Property(x => x.TableCode).HasMaxLength(20).IsRequired();
            entity.Property(x => x.Status).HasMaxLength(20).IsRequired();
            entity.HasIndex(x => x.TableCode).IsUnique();
        });

        modelBuilder.Entity<OrderStatus>(entity =>
        {
            entity.ToTable("OrderStatuses");
            entity.HasKey(x => x.OrderStatusId);
            entity.Property(x => x.Name).HasMaxLength(50).IsRequired();
            entity.HasIndex(x => x.Name).IsUnique();
            entity.HasIndex(x => x.DisplayOrder).IsUnique();
        });

        modelBuilder.Entity<FoodOrder>(entity =>
        {
            entity.ToTable("Orders");
            entity.HasKey(x => x.OrderId);
            entity.Property(x => x.OrderCode).HasMaxLength(30).IsUnicode(false).IsRequired();
            entity.Property(x => x.OrderType).HasMaxLength(20).IsUnicode(false).IsRequired();
            entity.Property(x => x.ReceiverName).HasMaxLength(120);
            entity.Property(x => x.ReceiverPhone).HasMaxLength(20);
            entity.Property(x => x.DeliveryAddress).HasMaxLength(500);
            entity.Property(x => x.Note).HasMaxLength(1000);
            entity.Property(x => x.TotalAmount).HasPrecision(18, 2);
            entity.Property(x => x.PaymentStatus).HasMaxLength(20).IsUnicode(false).IsRequired();
            entity.HasIndex(x => x.OrderCode).IsUnique();
            entity.HasIndex(x => new { x.UserId, x.CreatedAt });
            entity.HasIndex(x => new { x.OrderStatusId, x.CreatedAt });
            entity.HasOne(x => x.User).WithMany(x => x.Orders).HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Restrict);
            entity.HasOne(x => x.OrderStatus).WithMany(x => x.Orders).HasForeignKey(x => x.OrderStatusId).OnDelete(DeleteBehavior.Restrict);
            entity.HasOne(x => x.DiningTable).WithMany(x => x.Orders).HasForeignKey(x => x.TableId).OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<OrderDetail>(entity =>
        {
            entity.ToTable("OrderDetails");
            entity.HasKey(x => x.OrderDetailId);
            entity.Property(x => x.FoodNameSnapshot).HasMaxLength(150).IsRequired();
            entity.Property(x => x.ImageUrlSnapshot).HasMaxLength(500);
            entity.Property(x => x.UnitPrice).HasPrecision(18, 2);
            entity.HasIndex(x => x.OrderId);
            entity.HasIndex(x => x.FoodItemId);
            entity.HasOne(x => x.Order).WithMany(x => x.OrderDetails).HasForeignKey(x => x.OrderId).OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(x => x.FoodItem).WithMany(x => x.OrderDetails).HasForeignKey(x => x.FoodItemId).OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<Payment>(entity =>
        {
            entity.ToTable("Payments");
            entity.HasKey(x => x.PaymentId);
            entity.Property(x => x.Method).HasMaxLength(20).IsUnicode(false).IsRequired();
            entity.Property(x => x.Status).HasMaxLength(20).IsUnicode(false).IsRequired();
            entity.Property(x => x.Amount).HasPrecision(18, 2);
            entity.Property(x => x.ProviderTxnCode).HasMaxLength(100);
            entity.Property(x => x.PaymentUrl).HasMaxLength(1000);
            entity.HasIndex(x => x.OrderId);
            entity.HasIndex(x => x.ProviderTxnCode).IsUnique().HasFilter("[ProviderTxnCode] IS NOT NULL");
            entity.HasOne(x => x.Order).WithMany(x => x.Payments).HasForeignKey(x => x.OrderId).OnDelete(DeleteBehavior.Restrict);
        });
        modelBuilder.Entity<OrderStatusHistory>(entity => { entity.ToTable("OrderStatusHistories"); entity.HasKey(x => x.OrderStatusHistoryId); entity.HasIndex(x => x.OrderId); });
    }
}
