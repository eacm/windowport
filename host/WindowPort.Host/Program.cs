using WindowPort.Host.Contracts;
using WindowPort.Host.Services;
using System.Net;
using System.Runtime.InteropServices;

if (OperatingSystem.IsWindows()) SetProcessDPIAware();
var builder = WebApplication.CreateBuilder(args);
builder.Services.AddSingleton<AppCatalog>();
builder.Services.AddSingleton<SessionManager>();
builder.Services.AddSingleton<WindowCapture>();
builder.Services.AddSingleton<InputService>();
var app = builder.Build();

// The MVP has no device authentication yet. Fail closed outside loopback and
// RFC1918/private address space so it cannot be exposed directly to the web.
app.Use(async (context, next) =>
{
    var address = context.Connection.RemoteIpAddress;
    if (address is not null && !IsPrivate(address))
    {
        context.Response.StatusCode = StatusCodes.Status403Forbidden;
        await context.Response.WriteAsJsonAsync(new { error = "Port accepts private-network clients only." });
        return;
    }
    await next();
});

app.MapGet("/api/health", () => Results.Ok(new { status = "ready", host = Environment.MachineName }));

app.MapGet("/api/apps", async (AppCatalog catalog, CancellationToken token) =>
    Results.Ok(await catalog.GetAsync(token)));

app.MapPost("/api/apps/{id}/launch", async (string id, HttpRequest request, AppCatalog catalog, SessionManager sessions, CancellationToken token) =>
{
    var published = await catalog.GetAsync(token);
    var selected = published.FirstOrDefault(item => string.Equals(item.Id, id, StringComparison.OrdinalIgnoreCase));
    if (selected is null) return Results.NotFound();
    var session = sessions.Launch(selected);
    var stream = new Uri($"{request.Scheme}://{request.Host}/api/sessions/{session.Id}/stream");
    return Results.Ok(new RemoteSession(session.Id, selected, stream, session.Width, session.Height));
});

app.MapGet("/api/sessions/{id:guid}/stream", async (Guid id, HttpResponse response, SessionManager sessions, WindowCapture capture, CancellationToken token) =>
{
    if (!sessions.TryGet(id, out var session)) { response.StatusCode = 404; return; }
    response.ContentType = "multipart/x-mixed-replace; boundary=frame";
    while (!token.IsCancellationRequested && !session.Process.HasExited)
    {
        var jpeg = capture.Capture(session);
        await response.WriteAsync($"--frame\r\nContent-Type: image/jpeg\r\nContent-Length: {jpeg.Length}\r\n\r\n", token);
        await response.Body.WriteAsync(jpeg, token);
        await response.WriteAsync("\r\n", token);
        await response.Body.FlushAsync(token);
        await Task.Delay(100, token);
    }
});

app.MapPost("/api/sessions/{id:guid}/pointer", (Guid id, PointerEvent input, SessionManager sessions, InputService service) =>
{
    if (!sessions.TryGet(id, out var session)) return Results.NotFound();
    var result = service.Pointer(session, input);
    return result is null ? Results.BadRequest() : Results.Ok(result);
});

app.MapPost("/api/sessions/{id:guid}/text", (Guid id, TextEvent input, SessionManager sessions, InputService service) =>
{
    if (!sessions.TryGet(id, out var session)) return Results.NotFound();
    service.Text(session, input.Text);
    return Results.NoContent();
});

app.MapPost("/api/sessions/{id:guid}/key", (Guid id, KeyEvent input, SessionManager sessions, InputService service) =>
{
    if (!sessions.TryGet(id, out var session)) return Results.NotFound();
    service.Key(session, input);
    return Results.NoContent();
});

app.MapPost("/api/sessions/{id:guid}/resize", (Guid id, ResizeEvent input, SessionManager sessions) =>
{
    if (!sessions.TryGet(id, out var session)) return Results.NotFound();
    sessions.Resize(session, input.Width, input.Height);
    return Results.NoContent();
});

app.Run();

static bool IsPrivate(IPAddress address)
{
    if (IPAddress.IsLoopback(address)) return true;
    if (address.IsIPv4MappedToIPv6) address = address.MapToIPv4();
    var bytes = address.GetAddressBytes();
    if (bytes.Length == 16) return address.IsIPv6LinkLocal || address.IsIPv6UniqueLocal;
    return bytes[0] == 10
        || (bytes[0] == 172 && bytes[1] is >= 16 and <= 31)
        || (bytes[0] == 192 && bytes[1] == 168)
        || (bytes[0] == 100 && bytes[1] is >= 64 and <= 127);
}

[DllImport("user32.dll")]
static extern bool SetProcessDPIAware();

