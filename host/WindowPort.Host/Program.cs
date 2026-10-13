using WindowPort.Host.Contracts;
using WindowPort.Host.Services;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddSingleton<AppCatalog>();
builder.Services.AddSingleton<SessionManager>();
builder.Services.AddSingleton<WindowCapture>();
builder.Services.AddSingleton<InputService>();
var app = builder.Build();

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
    return Results.Ok(new RemoteSession(session.Id, selected, stream));
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
    service.Pointer(session, input);
    return Results.NoContent();
});

app.MapPost("/api/sessions/{id:guid}/text", (Guid id, TextEvent input, SessionManager sessions, InputService service) =>
{
    if (!sessions.TryGet(id, out var session)) return Results.NotFound();
    service.Text(session, input.Text);
    return Results.NoContent();
});

app.Run();

