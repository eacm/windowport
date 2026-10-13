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
        foreach (var character in text)
        {
            if (character == '\n' || character == '\r') SendVirtualKey(0x0D);
            else if (character == '\b') SendVirtualKey(0x08);
            else SendUnicode(character);
        }
    }

    private static void SendUnicode(char character)
    {
        var inputs = new[]
        {
            KeyboardInput(character, 0x0004),
            KeyboardInput(character, 0x0004 | 0x0002)
        };
        SendInput((uint)inputs.Length, inputs, Marshal.SizeOf<Input>());
    }

    private static void SendVirtualKey(ushort key)
    {
        var inputs = new[] { KeyboardInput(key, 0), KeyboardInput(key, 0x0002) };
        SendInput((uint)inputs.Length, inputs, Marshal.SizeOf<Input>());
    }

    private static Input KeyboardInput(ushort value, uint flags) => new()
    {
        Type = 1,
        Data = new InputUnion { Keyboard = new KeyboardInputData { VirtualKey = flags == 0 || flags == 0x0002 ? value : (ushort)0, ScanCode = flags is 0x0004 or 0x0006 ? value : (ushort)0, Flags = flags } }
    };

    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr handle, out Rect rect);
    [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr handle);
    [DllImport("user32.dll")] static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] static extern void mouse_event(uint flags, uint dx, uint dy, uint data, UIntPtr extraInfo);
    [DllImport("user32.dll", SetLastError = true)] static extern uint SendInput(uint count, Input[] inputs, int size);
    [StructLayout(LayoutKind.Sequential)] private struct Input { public uint Type; public InputUnion Data; }
    [StructLayout(LayoutKind.Explicit, Size = 32)] private struct InputUnion { [FieldOffset(0)] public KeyboardInputData Keyboard; }
    [StructLayout(LayoutKind.Sequential)] private struct KeyboardInputData
    {
        public ushort VirtualKey;
        public ushort ScanCode;
        public uint Flags;
        public uint Time;
        public UIntPtr ExtraInfo;
    }
    private struct Rect { public int Left, Top, Right, Bottom; }
}

