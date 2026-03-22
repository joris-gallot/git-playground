<script lang="ts">
  let count = 0
  const title = 'Reviu'

  function increment() {
    count += 1
  }
</script>

<svelte:head>
  <title class="text-blue-100">{title}</title>
</svelte:head>

<button on:click={increment}>
  {title} count: {count}
</button>

<style>
  button {
    color: tomato;
  }
</style>
