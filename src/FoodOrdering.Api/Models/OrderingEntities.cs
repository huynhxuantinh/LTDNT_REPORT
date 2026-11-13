namespace FoodOrdering.Api.Models;

public sealed class Category
{
    public int CategoryId { get; set; }
    public required string Name { get; set; }
    public string? Description { get; set; }
    public string? ImageUrl { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public ICollection<FoodItem> FoodItems { get; set; } = new List<FoodItem>();
}

public sealed class FoodItem
{
    public int FoodItemId { get; set; }
    public int CategoryId { get; set; }
    public Category? Category { get; set; }
    public required string Name { get; set; }
    public string? Description { get; set; }
    public decimal Price { get; set; }
    public string? ImageUrl { get; set; }
    public bool IsAvailable { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public ICollection<CartItem> CartItems { get; set; } = new List<CartItem>();
    public ICollection<OrderDetail> OrderDetails { get; set; } = new List<OrderDetail>();
}

public sealed class Cart
{
    public Guid CartId { get; set; }
    public Guid UserId { get; set; }
    public User? User { get; set; }
    public DateTime UpdatedAt { get; set; }
    public ICollection<CartItem> CartItems { get; set; } = new List<CartItem>();
}

public sealed class CartItem
{
    public int CartItemId { get; set; }
    public Guid CartId { get; set; }
    public Cart? Cart { get; set; }
    public int FoodItemId { get; set; }
    public FoodItem? FoodItem { get; set; }
    public int Quantity { get; set; }
    public decimal UnitPrice { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
}

public sealed class DiningTable
{
    public int TableId { get; set; }
    public required string TableCode { get; set; }
    public byte Capacity { get; set; }
    public required string Status { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public ICollection<FoodOrder> Orders { get; set; } = new List<FoodOrder>();
}

public sealed class OrderStatus
{
    public byte OrderStatusId { get; set; }
    public required string Name { get; set; }
    public byte DisplayOrder { get; set; }
    public ICollection<FoodOrder> Orders { get; set; } = new List<FoodOrder>();
}

public sealed class FoodOrder
{
    public long OrderId { get; set; }
    public required string OrderCode { get; set; }
    public Guid UserId { get; set; }
    public User? User { get; set; }
    public byte OrderStatusId { get; set; }
    public OrderStatus? OrderStatus { get; set; }
    public string? OrderType { get; set; }
    public int? TableId { get; set; }
    public DiningTable? DiningTable { get; set; }
    public string? ReceiverName { get; set; }
    public string? ReceiverPhone { get; set; }
    public string? DeliveryAddress { get; set; }
    public string? Note { get; set; }
    public decimal TotalAmount { get; set; }
    public required string PaymentStatus { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public ICollection<OrderDetail> OrderDetails { get; set; } = new List<OrderDetail>();
    public ICollection<Payment> Payments { get; set; } = new List<Payment>();
}

public sealed class OrderDetail
{
    public long OrderDetailId { get; set; }
    public long OrderId { get; set; }
    public FoodOrder? Order { get; set; }
    public int FoodItemId { get; set; }
    public FoodItem? FoodItem { get; set; }
    public required string FoodNameSnapshot { get; set; }
    public string? ImageUrlSnapshot { get; set; }
    public decimal UnitPrice { get; set; }
    public int Quantity { get; set; }
}

public sealed class Payment
{
    public long PaymentId { get; set; }
    public long OrderId { get; set; }
    public FoodOrder? Order { get; set; }
    public required string Method { get; set; }
    public required string Status { get; set; }
    public decimal Amount { get; set; }
    public string? ProviderTxnCode { get; set; }
    public string? PaymentUrl { get; set; }
    public DateTime? PaidAt { get; set; }
    public DateTime CreatedAt { get; set; }
}
