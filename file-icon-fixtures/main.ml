module Greeter = struct
  let greet name =
    "Hello " ^ name
end

let () = print_endline (Greeter.greet "OCaml")
