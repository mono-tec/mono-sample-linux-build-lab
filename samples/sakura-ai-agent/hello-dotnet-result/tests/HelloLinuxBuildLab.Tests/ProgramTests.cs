namespace HelloLinuxBuildLab.Tests;

[TestClass]
public sealed class ProgramTests
{
    [TestMethod]
    public void Main_WritesExpectedOutputToConsole()
    {
        var originalOut = Console.Out;
        using var sw = new StringWriter();
        Console.SetOut(sw);

        try
        {
            Program.Main(Array.Empty<string>());
        }
        finally
        {
            Console.SetOut(originalOut);
        }

        Assert.AreEqual("Hello from Linux Build Lab\n", sw.ToString());
    }
}
