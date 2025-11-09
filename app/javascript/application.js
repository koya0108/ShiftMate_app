import "@hotwired/turbo-rails"
import "./controllers"
import * as bootstrap from "bootstrap"

import "./calendar"

import TomSelect from "tom-select"

document.addEventListener("turbo:load", () => {
  document.querySelectorAll('.tom-select').forEach((el) => {
    new TomSelect(el, {
      plugins: ['remove_button'],
      placeholder: '🔍 検索・複数選択が可能です',
      maxItems: null
    })
  })
})

document.addEventListener("turbo:load", () => {
  const btn = document.getElementById("menu-toggle");
  const sidebar = document.getElementById("sidebar");
  if (!btn || !sidebar) return;

  // ← 二重登録防止
  if (btn.dataset.listenerAdded) return;
  btn.dataset.listenerAdded = true;

  btn.addEventListener("click", () => {
    document.body.classList.toggle("with-sidebar");
  });
});