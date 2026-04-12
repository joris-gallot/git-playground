#include <stdio.h>

static int add(int a, int b) {
  return a + b;
}

int main(void) {
  const char *name = "Reviu";
  printf("hello %s %d\n", name, add(2, 3));
  return 0;
}
