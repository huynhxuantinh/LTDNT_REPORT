namespace FoodOrdering.Api.Common;

public sealed record ApiError(string Code, string Message, IReadOnlyDictionary<string, string[]>? Details = null);

public sealed record ApiErrorResponse(ApiError Error)
{
    public static ApiErrorResponse Create(string code, string message) => new(new ApiError(code, message));

    public static ApiErrorResponse Validation(IReadOnlyDictionary<string, string[]> details) =>
        new(new ApiError("validation_error", "Dữ liệu gửi lên không hợp lệ.", details));
}

public sealed record PageRequest(int Page = 1, int PageSize = 20)
{
    public int ValidPage => Math.Max(1, Page);
    public int ValidPageSize => Math.Clamp(PageSize, 1, 100);
}

public sealed record PageMeta(int Page, int PageSize, int TotalItems, int TotalPages);

public sealed record PagedResponse<T>(IReadOnlyList<T> Data, PageMeta Meta)
{
    public static PagedResponse<T> Create(IReadOnlyList<T> data, int page, int pageSize, int totalItems) =>
        new(data, new PageMeta(page, pageSize, totalItems, (int)Math.Ceiling(totalItems / (double)pageSize)));
}
