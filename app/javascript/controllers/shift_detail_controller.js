import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="shift-detail"
export default class extends Controller {

  connect() {
    this.breakRooms = JSON.parse(
      this.element.dataset.shiftDetailBreakRooms || "[]"
    )

    // ★ 初期表示の select に色を設定
    this.element.querySelectorAll('select[data-field="break_room_id"]').forEach(select => {
      const value = select.value
      const br = this.breakRooms.find(b => b.id == value)
      if (br) select.style.color = br.color
    })

    // ★ 初期描画の段階でも時間軸に色を付ける
    this.element.querySelectorAll("tr[data-shift-detail-id]").forEach(row => {
      const id = row.dataset.shiftDetailId
      const start = row.dataset.restStart
      const end = row.dataset.restEnd
      const color = row.dataset.breakRoomColor
      const breakRoomId = row.dataset.breakRoomId

      if (start && end) {
        this.refreshRow({
          id: id,
          rest_start_time: start,
          rest_end_time: end,
          break_room_color: color,
          break_room_id: breakRoomId
        })
      }
    })
  }

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

          // ★ 休憩室の色を select に反映
          if (field === "break_room_id") {
            const br = this.breakRooms.find(b => b.id == value)
            if (br) select.style.color = br.color
          }

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

 
  // ★ 時間軸セルの再描画（夜勤/日勤を自動判別）
  refreshRow(detail) {
    const row = document.querySelector(`tr[data-shift-detail-id="${detail.id}"]`)
    if (!row) return

    const table = row.closest("table[data-shift-detail-shift-type]")
    const shiftType = table ? table.dataset.shiftDetailShiftType : "day";

    let color;

    if (shiftType === "night" && !detail.break_room_id) {
      color = "#e9ecef";
    } else {
      color = detail.break_room_color || "#0dcaf0";
    }

    // 既存色リセット
    row.querySelectorAll("td.time-cell").forEach(td => {
      td.style.backgroundColor = ""
      td.classList.remove("bg-info");
    })

    // ▼ start/end → 正規化
    const start = this.normalizeHour(detail.rest_start_time, shiftType)
    const end   = this.normalizeHour(detail.rest_end_time, shiftType)

    // ▼ 各時間セルを塗る
    row.querySelectorAll("td.time-cell").forEach(td => {
      const cellHour = this.normalizeHour(td.dataset.hour, shiftType)

      if (cellHour >= start && cellHour < end) {
        td.style.backgroundColor = color
      }
    })
  }

  // ★ "HH:MM" → 日勤/夜勤対応の内部時間へ変換
  normalizeHour(timeVal, shiftType) {
    let h, m = 0;

    // 数字だけ -> HH:00 に補正
    if (typeof timeVal === "string" && /^\d+$/.test(timeVal)) {
      timeVal = `${timeVal.padStart(2, "0")}:00`;
    }

    if (typeof timeVal === "string" && timeVal.includes(":")) {
      const [hour, min] = timeVal.split(":").map(Number);
      h = hour;
      m = min;
    } else if (typeof timeVal === "number") {
      h = timeVal;
    } else {
      return 0;
    }

    let value = h + m / 60;

    if (shiftType === "night" && value <= 9) {
      value += 24;
    }

    return value;
  }
}
