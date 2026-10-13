using System.Collections.Concurrent;
using System.Diagnostics;
using WindowPort.Host.Contracts;

namespace WindowPort.Host.Services;

public sealed record HostSession(Guid Id, PublishedApplication Application, Process Process);

public sealed class SessionManager
{
    private readonly ConcurrentDictionary<Guid, HostSession> _sessions = new();

    public HostSession Launch(PublishedApplication app)
    {
        var start = new ProcessStartInfo(app.Executable, app.Arguments ?? "") { UseShellExecute = true };
        var process = Process.Start(start) ?? throw new InvalidOperationException($"Windows could not start {app.Name}.");
        var session = new HostSession(Guid.NewGuid(), app, process);
        _sessions[session.Id] = session;
        return session;
    }

    public bool TryGet(Guid id, out HostSession session) => _sessions.TryGetValue(id, out session!);
}

