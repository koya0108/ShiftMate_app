import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="shift-detail"
export default class extends Controller {
  update(event) {
    const select = event.target
    const id = select.dataset.shiftDetailId
    const field = select.dataset.field
    const value = select.value

    const row = select.closest("tr[data-shift-detail-id]")
    const groupInput = row.querySelector('input[name="group_id"]')
    const groupId = groupInput ? groupInput.value : null

    // 変更前の値を保存（失敗時に戻すため）
    if (!select.dataset.previousValue) {
      select.dataset.previousValue = value
    }

    fetch(`/shift_details/${id}`, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
      },
      body: JSON.stringify({
        shift_detail: {
          [field]: value,
          group_id: groupId
        }
      })
    })
      .then(res => res.json())
      .then(data => {
        if (data.success) {
          // 成功時：前回値を更新 & セルを再描画
          select.dataset.previousValue = value
          this.refreshRow(data.detail)
        } else {
          alert("更新に失敗しました: " + data.errors.join(", "))
          select.value = select.dataset.previousValue
          if (data.detail) this.refreshRow(data.detail)
        }
      })
      .catch(() => {
        alert("通信エラーが発生しました。")
        select.value = select.dataset.previousValue
      })
  }

  // === 時間軸セルの再描画 ===
  refreshRow(detail) {
    const row = document.querySelector(`tr[data-shift-detail-id="${detail.id}"]`)
    if (!row) return

    // 既存の色をリセット
    row.querySelectorAll("td.time-cell").forEach(td => td.classList.remove("bg-info"))

    // サーバーから送られた時間（18〜33の整数形式）
    const start = parseInt(detail.rest_start_time, 10)
    const end   = parseInt(detail.rest_end_time, 10)

    // すべての時間セルをチェックして該当範囲を塗る
    row.querySelectorAll("td.time-cell").forEach(td => {
      const cellHour = parseInt(td.dataset.hour, 10)

      // 翌日(0〜9)は+24して比較
      const normalizedCellHour = cellHour < 18 ? cellHour + 24 : cellHour

      if (normalizedCellHour >= start && normalizedCellHour < end) {
        td.classList.add("bg-info")
      }
    })
  }
}