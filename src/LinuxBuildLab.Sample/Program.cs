using System.Runtime.InteropServices;

Console.WriteLine("========================================");
Console.WriteLine("Linux Build Lab Sample");
Console.WriteLine("========================================");
Console.WriteLine($"実行日時 : {DateTimeOffset.Now:yyyy-MM-dd HH:mm:ss zzz}");
Console.WriteLine($"OS       : {RuntimeInformation.OSDescription}");
Console.WriteLine($"Architecture: {RuntimeInformation.OSArchitecture}");
Console.WriteLine($".NET     : {RuntimeInformation.FrameworkDescription}");
Console.WriteLine($"Machine  : {Environment.MachineName}");
Console.WriteLine("Hello from .NET 10 on Linux!");
Console.WriteLine("========================================");