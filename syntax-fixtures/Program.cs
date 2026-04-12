using System;

namespace Reviu.App;

public sealed class Greeter
{
  public string Greet(string name)
  {
    return $"Hello, {name}";
  }

  public static void Main()
  {
    Console.WriteLine(new Greeter().Greet("Reviu"));
  }
}
