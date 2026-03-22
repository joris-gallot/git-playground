defmodule ReviuFixture do
  def greet(name) do
    "Hello #{name}"
  end
end

IO.puts(ReviuFixture.greet("Elixir"))
