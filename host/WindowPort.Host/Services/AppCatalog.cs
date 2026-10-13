using System.Text.Json;
using WindowPort.Host.Contracts;

namespace WindowPort.Host.Services;

public sealed class AppCatalog(IHostEnvironment environment)
{
    private readonly string _path = Path.Combine(environment.ContentRootPath, "published-apps.json");

    public async Task<IReadOnlyList<PublishedApplication>> GetAsync(CancellationToken token)
    {
        if (!File.Exists(_path))
        {
            var starter = new[] { new PublishedApplication("notepad", "Notepad", "notepad.exe", null, "Tools") };
            await File.WriteAllTextAsync(_path, JsonSerializer.Serialize(starter, JsonOptions), token);
            return starter;
        }
        await using var stream = File.OpenRead(_path);
        return await JsonSerializer.DeserializeAsync<PublishedApplication[]>(stream, JsonOptions, token) ?? [];
    }

    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web) { WriteIndented = true };
}

