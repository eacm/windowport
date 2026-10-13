namespace WindowPort.Host.Contracts;

public sealed record PublishedApplication(string Id, string Name, string Executable, string? Arguments, string? Category, Uri? IconUrl = null);
public sealed record RemoteSession(Guid Id, PublishedApplication Application, Uri StreamUrl, int Width, int Height);
public sealed record PointerEvent(string Kind, double X, double Y, double? DeltaY);
public sealed record TextEvent(string Text);

