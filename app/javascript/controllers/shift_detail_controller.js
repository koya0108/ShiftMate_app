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

  // 時間軸セルの再描画
  refreshRow(detail) {
    const row = document.querySelector(`tr[data-shift-detail-id="${detail.id}"]`)
    if (!row) return

    const table = row.closest("table[data-shift-detail-shift-type]")
    const shiftType = table ? table.dataset.shiftDetailShiftType : "night"

    // 既存の色をリセット
    row.querySelectorAll("td.time-cell").forEach(td => td.classList.remove("bg-info"))

    // 小数を扱えるように
    const start = parseFloat(detail.rest_start_time)
    const end   = parseFloat(detail.rest_end_time)

    row.querySelectorAll("td.time-cell").forEach(td => {
      const cellHour = this.parseTimeToFloat(td.dataset.hour)

      // 夜勤と日勤で異なる補正
      let normalizedCellHour

      if (shiftType === "night") {
        // 夜勤: 18〜33 のみ +24 補正
        normalizedCellHour = cellHour < 18 ? cellHour + 24 : cellHour
      } else {
        // 日勤: 10〜15 など通常通り
        normalizedCellHour = cellHour
      }

      // 時間範囲に含まれていれば塗りつぶし
      if (normalizedCellHour >= start && normalizedCellHour < end) {
        td.classList.add("bg-info")
      }
    })
  }
  parseTimeToFloat(timeStr) {
    const [h, m] = timeStr.split(":").map(Number)
    return h + (m / 60)
  }
}