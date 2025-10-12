// Entry point for the build script in your package.json
import "@hotwired/turbo-rails"
import "./controllers"
import * as bootstrap from "bootstrap"

import "./calendar"

import TomSelect from "tom-select"

document.addEventListener("turbo:load", () => {
  document.querySelectorAll('.tom-select').forEach((el) => {
    new TomSelect(el, {
      plugins: ['remove_button'],   // タグに×ボタンを付ける
      placeholder: '🔍 検索・複数選択が可能です',
      maxItems: null                // 制限なし（null）
    })
  })
})

document.addEventListener("turbo:load", () => {
  const btn = document.getElementById("menu-toggle");
  const sidebar = document.getElementById("sidebar");
  if (!btn || !sidebar) return;

  btn.addEventListener("click", () => {
    sidebar.classList.toggle("d-none");
    document.body.classList.toggle("with-sidebar", !sidebar.classList.contains("d-none"));
  });
});