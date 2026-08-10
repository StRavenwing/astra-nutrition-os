<template>
  <section class="theory-page">
    <div class="panel theory-placeholder">
      <p class="eyebrow">ТЕОРИЯ</p>
      <h2>Раздел в доработке</h2>
      <p>Материалы и полезные рекомендации появятся здесь позже.</p>
    </div>
  </section>
</template>

<style lang="scss">
.theory-placeholder {
  min-height: 260px;
  display: grid;
  align-content: center;
  justify-items: center;
  gap: 8px;
  text-align: center;

  h2,
  p { margin: 0; }

  > p:last-child { color: var(--muted); }
}
</style>
