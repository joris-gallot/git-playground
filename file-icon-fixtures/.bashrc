export REVIU_ENV="dev"
alias gs='git status --short'

reviu_hello() {
  local name="${1:-world}"
  echo "hello ${name} from bashrc"
}
