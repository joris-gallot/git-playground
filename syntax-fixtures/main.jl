module ReviuFixture

struct Greeter
  name::String
end

function greet(g::Greeter)
  return "Hello $(g.name)"
end

println(greet(Greeter("Julia")))
