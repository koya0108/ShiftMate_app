import { Calendar } from '@fullcalendar/core'
import dayGridPlugin from '@fullcalendar/daygrid'
import listPlugin from '@fullcalendar/list'
import jaLocale from '@fullcalendar/core/locales/ja'

document.addEventListener('turbo:load', () => {
  const calendarEl = document.getElementById('calendar')
  if (!calendarEl) return

  const projectId = calendarEl.dataset.projectId

  const isMobile = window.innerWidth <= 768
  const initialView = isMobile ? 'listMonth' : 'dayGridMonth'

  const calendar = new Calendar(calendarEl, {
    plugins: [dayGridPlugin, listPlugin],
    initialView: initialView,
    locale: jaLocale,
    headerToolbar: {
      left: 'prev,next today',
      center: 'title',
      right: ''
    },

    // Ajax でイベントを取得
    events: function(info, successCallback, failureCallback) {
      fetch(`/projects/${projectId}/shifts/fetch?start=${info.startStr}&end=${info.endStr}`)
        .then(response => response.json())
        .then(data => {
          let events = []

          // カレンダー範囲の日付を全部「未作成」にする
          const startDate = new Date(info.start)
          const endDate = new Date(info.end)

          for (let d = new Date(startDate); d <= endDate; d.setDate(d.getDate() + 1)) {
            const dateStr = d.toISOString().split('T')[0]

            // 日勤・夜勤
            events.push({
              start: dateStr,
              extendedProps: {
                type: "new_day",
                url: `/projects/${projectId}/shifts/step1?date=${dateStr}&shift_category=day`
              }
            })
            events.push({
              start: dateStr,
              extendedProps: {
                type: "new_night",
                url: `/projects/${projectId}/shifts/step1?date=${dateStr}&shift_category=night`
              }
            })
          }

          // DBにある日付を「参照アイコン」に上書き
          data.forEach(shift => {
            const dateStr = shift.shift_date.split('T')[0]
            const category = shift.shift_category

            // 対応するtypeを決定
            const key = category === "day" ? "new_day" : "new_night"

            // 同じtypeの新規アイコンを削除してpdfアイコンに差し替え
            events = events.filter(e => !(e.start === dateStr && e.extendedProps.type === key))
            events.push({
              start: dateStr,
              extendedProps: {
                type: category === "day" ? "created_day" : "created_night",
                url: `/projects/${projectId}/shifts/${shift.id}/confirm`
              }
            })
          })

          // アイコン並び順固定
          events.sort((a,b) => {
            if (a.start < b.start) return -1
            if (a.start < b.start) return 1

            const order = { new_day: 1, created_day: 1, new_night: 2, created_night: 2 }
            return order[a.extendedProps.type] - order[b.extendedProps.type]
          })
          successCallback(events)
        })
        .catch(failureCallback)
    },

    eventBackgroundColor: 'transparent',
    eventBorderColor: 'transparent',

    eventContent: function(arg) {
      const wrapper = document.createElement("div")
      wrapper.classList.add("shift-icon-wrapper")

      const icon = document.createElement("i")
      const label = document.createElement("span")
      label.classList.add("shift-label")

      // 状態に応じてスタイルと内容を切り替え
      switch (arg.event.extendedProps.type) {
        case "new_day":
          icon.className = "bi bi-sun-fill text-warning me-1"
          label.textContent = ""
          wrapper.classList.add("day-shift")
          break
        case "new_night":
          icon.className = "bi bi-moon-stars-fill text-info me-1"
          label.textContent = ""
          wrapper.classList.add("night-shift")
          break
        case "created_day":
          icon.className = "bi bi-file-earmark-text-fill text-warning me-1"
          label.textContent = "シフト"
          wrapper.classList.add("day-shift")
          break
        case "created_night":
          icon.className = "bi bi-file-earmark-text-fill text-info me-1"
          label.textContent = "シフト"
          wrapper.classList.add("night-shift")
          break
      }

      // クリック範囲を拡大するため、aタグをラッパー全体に適用
      const link = document.createElement("a")
      link.href = arg.event.extendedProps.url
      link.classList.add("shift-link") // ← 後でCSSでボックス全体をクリック範囲化
      link.append(icon, label)
      wrapper.append(link)

      return { domNodes: [wrapper] }
    }
  })

  calendar.render()
})