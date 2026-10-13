using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

namespace WindowPort.Host.Services;

public sealed class WindowCapture
{
    public byte[] Capture(HostSession session)
    {
        session.Process.Refresh();
        var handle = session.Process.MainWindowHandle;
        if (handle == IntPtr.Zero || !GetWindowRect(handle, out var rect)) return Placeholder(session.Application.Name);
        var width = Math.Max(1, rect.Right - rect.Left);
        var height = Math.Max(1, rect.Bottom - rect.Top);
        using var bitmap = new Bitmap(width, height, PixelFormat.Format24bppRgb);
        using (var graphics = Graphics.FromImage(bitmap)) graphics.CopyFromScreen(rect.Left, rect.Top, 0, 0, new Size(width, height));
        using var stream = new MemoryStream();
        bitmap.Save(stream, ImageFormat.Jpeg);
        return stream.ToArray();
    }

    private static byte[] Placeholder(string name)
    {
        using var bitmap = new Bitmap(960, 540);
        using var graphics = Graphics.FromImage(bitmap);
        graphics.Clear(Color.FromArgb(14, 18, 22));
        using var font = new Font("Segoe UI", 28);
        graphics.DrawString($"Waiting for {name}…", font, Brushes.White, 40, 40);
        using var stream = new MemoryStream();
        bitmap.Save(stream, ImageFormat.Jpeg);
        return stream.ToArray();
    }

    [DllImport("user32.dll")]
    private static extern bool GetWindowRect(IntPtr handle, out Rect rect);
    private struct Rect { public int Left, Top, Right, Bottom; }
}

