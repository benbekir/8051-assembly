using System.Text;
using System.Text.RegularExpressions;

namespace macros;

public class Program
{
    private static readonly Regex _macroDefinition = new(@"^#(define|DEFINE)\s+[A-Za-z_][A-Za-z0-9_]*?\s+.*?$", RegexOptions.Compiled);
    private static readonly Regex _comment = new(@"^\s*;.*?$", RegexOptions.Compiled);
    private static readonly Regex _emptyLine = new(@"^\s*$", RegexOptions.Compiled);

    // any whitespace character (equivalent to [\r\n\t\f\v ])
    private static readonly char[] _whiteSpace = new char[] { '\r', '\n', '\t', '\f', '\v', ' ' };

    public static void Main(string[] args)
    {
        if (args.Length is 0 or > 1)
        {
            Console.WriteLine("Usage: macros <file>");
            return;
        }
        string[] lines = File.ReadAllLines(args[0]);
        Dictionary<string, string> macros = new();
        int i = 0;
        for (; i < lines.Length; i++)
        {
            if (_macroDefinition.IsMatch(lines[i]))
            {
                string[] parts = lines[i].Split(_whiteSpace, StringSplitOptions.RemoveEmptyEntries);
                if (parts.Length is not 3)
                {
                    Console.WriteLine("Invalid macro definition: {0}", lines[i]);
                    return;
                }
                if (!macros.TryAdd(parts[1], parts[2]))
                {
                    Console.WriteLine("Duplicate macro definition: {0}", lines[i]);
                    return;
                }
                continue;
            }
            else if (_comment.IsMatch(lines[i]) || _emptyLine.IsMatch(lines[i]))
            {
                continue;
            }
            break;
        }
        Console.WriteLine("{0} macros defined", macros.Count);
        if (macros.Count is 0)
        {
            return;
        }
        Console.WriteLine("Defined macros:");
        foreach (KeyValuePair<string, string> kvp in macros)
        {
            Console.WriteLine("{0} = {1}", kvp.Key, kvp.Value);
        }
        string outputFileName = args[0].Replace(".a51", string.Empty) + "-generated.a51";
        if (File.Exists(outputFileName))
        {
            File.Delete(outputFileName);
        }
        using FileStream output = File.OpenWrite(outputFileName);
        for (; i < lines.Length; i++)
        {
            RETRY_MACROS:
            foreach ((string macro, string replacement) in macros)
            {
                Match m = Regex.Match(lines[i], $@"\b{macro}\b");
                if (m.Success)
                {
                    lines[i] = Regex.Replace(lines[i], $@"\b{macro}\b", replacement);
                    // allow recursive macros to work :)
                    goto RETRY_MACROS;
                }
            }
            output.Write(Encoding.UTF8.GetBytes(lines[i] + "\r\n"));
        }
    }
}