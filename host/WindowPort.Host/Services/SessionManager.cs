using System.Collections.Concurrent;
using System.Diagnostics;
using System.Runtime.InteropServices;
using WindowPort.Host.Contracts;

namespace WindowPort.Host.Services;

public sealed record HostSession(Guid Id, PublishedApplication Application, Process Process, int Width, int Height);

public sealed class SessionManager
{
    private readonly ConcurrentDictionary<Guid, HostSession> _sessions = new();

    public HostSession Launch(PublishedApplication app)
    {
        var start = new ProcessStartInfo(app.Executable, app.Arguments ?? "") { UseShellExecute = true };
        var launched = Process.Start(start) ?? throw new InvalidOperationException($"Windows could not start {app.Name}.");
        var processName = Path.GetFileNameWithoutExtension(app.Executable);
        var process = ResolveVisibleProcess(launched, processName);
        var size = GetWindowSize(process.MainWindowHandle);
        var session = new HostSession(Guid.NewGuid(), app, process, size.Width, size.Height);
        _sessions[session.Id] = session;
        return session;
    }

    public bool TryGet(Guid id, out HostSession session) => _sessions.TryGetValue(id, out session!);

    private static Process ResolveVisibleProcess(Process launched, string processName)
    {
        for (var attempt = 0; attempt < 40; attempt++)
        {
            if (!launched.HasExited)
            {
                launched.Refresh();
                if (launched.MainWindowHandle != IntPtr.Zero) return launched;
            }

            var existing = Process.GetProcessesByName(processName)
                .FirstOrDefault(candidate => candidate.MainWindowHandle != IntPtr.Zero);
            if (existing is not null) return existing;
            Thread.Sleep(100);
        }

        if (!launched.HasExited) return launched;
        throw new InvalidOperationException($"The app started but Port could not find its visible window.");
    }

    private static (int Width, int Height) GetWindowSize(IntPtr handle)
    {
        if (handle != IntPtr.Zero && GetWindowRect(handle, out var rect))
            return (Math.Max(1, rect.Right - rect.Left), Math.Max(1, rect.Bottom - rect.Top));
        return (1280, 720);
    }

    [DllImport("user32.dll")]
    private static extern bool GetWindowRect(IntPtr handle, out Rect rect);
    private struct Rect { public int Left, Top, Right, Bottom; }
}

