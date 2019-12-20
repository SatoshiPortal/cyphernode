using Mono.Options;
using NBitcoin;
using System;
using System.IO;
using System.Collections.Generic;
using System.Threading.Tasks;
using WalletWasabi.Helpers;
using WalletWasabi.Blockchain.Keys;

namespace WalletGenerator.CommandLine
{
  internal class GenerateWalletCommand : Command
  {
    public string WalletName { get; set; }
    public string Password { get; set; }
    public bool ShowHelp { get; set; }

    public GenerateWalletCommand()
    : base("generate", "Generate a new wallet file.")
    {
      Options = new OptionSet() {
        "usage: generate --wallet:WalletName",
        "",
        "Creates a new wallet file, reading a password from stdin and printing the mnemonics to stdout",
        "eg: echo -n \"password\" | ./walletgenerator generate --wallet:MyWalletName > mnemonics.txta",
        "",
        { "w|wallet=", "The name of the wallet file.",
          x =>  WalletName = x
        },
        { "h|help", "Show Help",
          v => ShowHelp = true
        }
      };
    }

    public override Task<int> InvokeAsync(IEnumerable<string> args)
    {
      var error = false;
      try
      {
        var extra = Options.Parse(args);
        if (ShowHelp)
        {
          Options.WriteOptionDescriptions(CommandSet.Out);
        }
        else if (string.IsNullOrWhiteSpace(WalletName) )
        {
          Console.WriteLine("Missing required argument `--wallet=WalletName`.");
          Console.WriteLine("Use `generate --help` for details.");
          error = true;
        }
        else
        {
          // Generate here
          try {

            string s = "";
            string password = "";
            while ((s = Console.ReadLine()) != null)
            {
              password += s;
            }

            password = Guard.Correct(password);

            string filePath = Path.Combine( WalletGenerator.WalletsDir, WalletName + ".json" );
            var manager = KeyManager.CreateNew( out Mnemonic mnemonic, password, filePath );

            manager.ToFile();
            Console.WriteLine(string.Join( ", ", mnemonic.Words));

          } catch ( Exception ) {
            Console.WriteLine($"There was a problem creating the wallet file.");
            error = true;
          }

        }
      }
      catch (Exception)
      {
        Console.WriteLine($"There was a problem interpreting the command, please review it.");
        error = true;
      }
      Environment.Exit(error ? 1 : 0);
      return Task.FromResult(0);
    }
  }
}
