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

    public void Resize(HostSession session, int requestedWidth, int requestedHeight)
    {
        if (requestedWidth <= 0 || requestedHeight <= 0) return;
        var screenWidth = GetSystemMetrics(0);
        var screenHeight = GetSystemMetrics(1);
        var targetAspect = (double)requestedWidth / requestedHeight;
        var screenAspect = (double)screenWidth / screenHeight;
        var width = screenWidth;
        var height = screenHeight;
        if (screenAspect > targetAspect) width = Math.Max(480, (int)(height * targetAspect));
        else height = Math.Max(360, (int)(width / targetAspect));
        var x = Math.Max(0, (screenWidth - width) / 2);
        var y = Math.Max(0, (screenHeight - height) / 2);
        ShowWindow(session.Process.MainWindowHandle, 9);
        SetWindowPos(session.Process.MainWindowHandle, IntPtr.Zero, x, y, width, height, 0x0040);
    }

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
    [DllImport("user32.dll")]
    private static extern bool SetWindowPos(IntPtr handle, IntPtr insertAfter, int x, int y, int width, int height, uint flags);
    [DllImport("user32.dll")]
    private static extern bool ShowWindow(IntPtr handle, int command);
    [DllImport("user32.dll")]
    private static extern int GetSystemMetrics(int index);
    private struct Rect { public int Left, Top, Right, Bottom; }
}

