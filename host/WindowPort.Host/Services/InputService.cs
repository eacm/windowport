using System.Runtime.InteropServices;
using WindowPort.Host.Contracts;

namespace WindowPort.Host.Services;

public sealed class InputService
{
    private const uint InputMouse = 0, InputKeyboard = 1;
    private const uint KeyUp = 0x0002, KeyUnicode = 0x0004, KeyExtended = 0x0001;
    private const uint MouseMove = 0x0001, MouseLeftDown = 0x0002, MouseLeftUp = 0x0004;
    private const uint MouseRightDown = 0x0008, MouseRightUp = 0x0010;
    private const uint MouseWheel = 0x0800, MouseVirtualDesk = 0x4000, MouseAbsolute = 0x8000;

    private static readonly Dictionary<string, ushort> Keys = new(StringComparer.OrdinalIgnoreCase)
    {
        ["backspace"] = 0x08, ["tab"] = 0x09, ["return"] = 0x0D, ["escape"] = 0x1B,
        ["space"] = 0x20, ["pageUp"] = 0x21, ["pageDown"] = 0x22, ["end"] = 0x23,
        ["home"] = 0x24, ["left"] = 0x25, ["up"] = 0x26, ["right"] = 0x27,
        ["down"] = 0x28, ["delete"] = 0x2E,
        ["f1"] = 0x70, ["f2"] = 0x71, ["f3"] = 0x72, ["f4"] = 0x73,
        ["f5"] = 0x74, ["f6"] = 0x75, ["f7"] = 0x76, ["f8"] = 0x77,
        ["f9"] = 0x78, ["f10"] = 0x79, ["f11"] = 0x7A, ["f12"] = 0x7B
    };

    public PointerResult? Pointer(HostSession session, PointerEvent input)
    {
        var handle = session.Process.MainWindowHandle;
        if (handle == IntPtr.Zero || !GetWindowRect(handle, out var rect)) return null;
        SetForegroundWindow(handle);

        var screenLeft = GetSystemMetrics(76);
        var screenTop = GetSystemMetrics(77);
        var screenWidth = Math.Max(GetSystemMetrics(78), 1);
        var screenHeight = Math.Max(GetSystemMetrics(79), 1);
        var pixelX = rect.Left + (rect.Right - rect.Left) * Math.Clamp(input.X, 0, 1);
        var pixelY = rect.Top + (rect.Bottom - rect.Top) * Math.Clamp(input.Y, 0, 1);
        var absoluteX = (int)Math.Round((pixelX - screenLeft) * 65535.0 / Math.Max(screenWidth - 1, 1));
        var absoluteY = (int)Math.Round((pixelY - screenTop) * 65535.0 / Math.Max(screenHeight - 1, 1));

        var inputs = new List<Input> { MouseInput(absoluteX, absoluteY, 0, MouseMove | MouseAbsolute | MouseVirtualDesk) };
        if (input.Kind == "down") inputs.Add(MouseInput(0, 0, 0, MouseLeftDown));
        if (input.Kind == "up") inputs.Add(MouseInput(0, 0, 0, MouseLeftUp));
        if (input.Kind == "click")
        {
            inputs.Add(MouseInput(0, 0, 0, MouseLeftDown));
            inputs.Add(MouseInput(0, 0, 0, MouseLeftUp));
        }
        if (input.Kind == "rightClick")
        {
            inputs.Add(MouseInput(0, 0, 0, MouseRightDown));
            inputs.Add(MouseInput(0, 0, 0, MouseRightUp));
        }
        if (input.Kind == "scroll") inputs.Add(MouseInput(0, 0, input.DeltaY ?? 0, MouseWheel));
        var sent = Send(inputs);
        GetCursorPos(out var cursor);
        return new PointerResult(sent, (int)pixelX, (int)pixelY, cursor.X, cursor.Y, Marshal.GetLastWin32Error());
    }

    public void Text(HostSession session, string text)
    {
        SetForegroundWindow(session.Process.MainWindowHandle);
        foreach (var character in text)
        {
            if (character is '\n' or '\r') SendVirtualKey(0x0D);
            else if (character == '\b') SendVirtualKey(0x08);
            else SendUnicode(character);
        }
    }

    public void Key(HostSession session, KeyEvent input)
    {
        SetForegroundWindow(session.Process.MainWindowHandle);
        var key = ResolveKey(input.Key);
        if (key == 0) return;
        var modifiers = new List<ushort>();
        if (input.Control) modifiers.Add(0xA2);
        if (input.Alt) modifiers.Add(0xA4);
        if (input.Shift) modifiers.Add(0xA0);
        if (input.Command) modifiers.Add(0x5B);

        var inputs = new List<Input>();
        inputs.AddRange(modifiers.Select(value => KeyboardInput(value, 0)));
        var extended = IsExtended(key) ? KeyExtended : 0;
        inputs.Add(KeyboardInput(key, extended));
        inputs.Add(KeyboardInput(key, extended | KeyUp));
        inputs.AddRange(modifiers.AsEnumerable().Reverse().Select(value => KeyboardInput(value, KeyUp)));
        Send(inputs);
    }

    private static ushort ResolveKey(string key)
    {
        if (Keys.TryGetValue(key, out var value)) return value;
        if (key.Length == 1)
        {
            var mapped = VkKeyScan(key[0]);
            return mapped == -1 ? (ushort)0 : (ushort)(mapped & 0xFF);
        }
        return 0;
    }

    private static bool IsExtended(ushort key) => key is >= 0x21 and <= 0x28 or 0x2E;
    private static void SendUnicode(char character) => Send(new[] { KeyboardInput(character, KeyUnicode), KeyboardInput(character, KeyUnicode | KeyUp) });
    private static void SendVirtualKey(ushort key) => Send(new[] { KeyboardInput(key, 0), KeyboardInput(key, KeyUp) });
    private static uint Send(IEnumerable<Input> source)
    {
        var inputs = source.ToArray();
        return inputs.Length > 0 ? SendInput((uint)inputs.Length, inputs, Marshal.SizeOf<Input>()) : 0;
    }

    private static Input KeyboardInput(ushort value, uint flags) => new()
    {
        Type = InputKeyboard,
        Data = new InputUnion { Keyboard = new KeyboardInputData { VirtualKey = (flags & KeyUnicode) == 0 ? value : (ushort)0, ScanCode = (flags & KeyUnicode) != 0 ? value : (ushort)0, Flags = flags } }
    };
    private static Input MouseInput(int x, int y, double data, uint flags) => new()
    {
        Type = InputMouse,
        Data = new InputUnion { Mouse = new MouseInputData { X = x, Y = y, MouseData = unchecked((uint)(int)data), Flags = flags } }
    };

    [DllImport("user32.dll")] private static extern bool GetWindowRect(IntPtr handle, out Rect rect);
    [DllImport("user32.dll")] private static extern bool SetForegroundWindow(IntPtr handle);
    [DllImport("user32.dll")] private static extern int GetSystemMetrics(int index);
    [DllImport("user32.dll")] private static extern bool GetCursorPos(out Point point);
    [DllImport("user32.dll")] private static extern short VkKeyScan(char character);
    [DllImport("user32.dll", SetLastError = true)] private static extern uint SendInput(uint count, Input[] inputs, int size);
    [StructLayout(LayoutKind.Sequential)] private struct Input { public uint Type; public InputUnion Data; }
    [StructLayout(LayoutKind.Explicit, Size = 32)] private struct InputUnion
    {
        [FieldOffset(0)] public MouseInputData Mouse;
        [FieldOffset(0)] public KeyboardInputData Keyboard;
    }
    [StructLayout(LayoutKind.Sequential)] private struct MouseInputData
    {
        public int X, Y;
        public uint MouseData, Flags, Time;
        public UIntPtr ExtraInfo;
    }
    [StructLayout(LayoutKind.Sequential)] private struct KeyboardInputData
    {
        public ushort VirtualKey, ScanCode;
        public uint Flags, Time;
        public UIntPtr ExtraInfo;
    }
    private struct Rect { public int Left, Top, Right, Bottom; }
    private struct Point { public int X, Y; }
}
