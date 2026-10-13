using System.Runtime.InteropServices;
using WindowPort.Host.Contracts;

namespace WindowPort.Host.Services;

public sealed class InputService
{
    public void Pointer(HostSession session, PointerEvent input)
    {
        if (session.Process.MainWindowHandle == IntPtr.Zero || !GetWindowRect(session.Process.MainWindowHandle, out var rect)) return;
        SetForegroundWindow(session.Process.MainWindowHandle);
        var x = rect.Left + (int)((rect.Right - rect.Left) * Math.Clamp(input.X, 0, 1));
        var y = rect.Top + (int)((rect.Bottom - rect.Top) * Math.Clamp(input.Y, 0, 1));
        SetCursorPos(x, y);
        if (input.Kind == "down") mouse_event(0x0002, 0, 0, 0, UIntPtr.Zero);
        if (input.Kind == "up") mouse_event(0x0004, 0, 0, 0, UIntPtr.Zero);
        if (input.Kind == "scroll") mouse_event(0x0800, 0, 0, (uint)(input.DeltaY ?? 0), UIntPtr.Zero);
    }

    public void Text(HostSession session, string text)
    {
        SetForegroundWindow(session.Process.MainWindowHandle);
        SendKeys.SendWait(text.Replace("{", "{{}").Replace("}", "{}}"));
    }

    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr handle, out Rect rect);
    [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr handle);
    [DllImport("user32.dll")] static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] static extern void mouse_event(uint flags, uint dx, uint dy, uint data, UIntPtr extraInfo);
    private struct Rect { public int Left, Top, Right, Bottom; }
}

