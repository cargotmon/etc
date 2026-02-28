package kr.lsj.etc.etc

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.app.PendingIntent
import android.widget.RemoteViews
import android.content.ComponentName
import android.graphics.Color
import android.util.Log
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

class HomeWidgetProvider : AppWidgetProvider() {

    // 1. 서버에서 데이터를 가져오는 별도 함수
    private fun fetchServerData(context: Context) {
        thread {
            try {
                // PHP 서버 주소 (실제 주소로 변경하세요)
                val url = URL("your-domain.com")
                val conn = url.openConnection() as HttpURLConnection
                conn.requestMethod = "GET"
                conn.connectTimeout = 5000 // 타임아웃 설정

                val response = conn.inputStream.bufferedReader().readText().trim()

                // 오늘 날짜 가져오기
                val today = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())

                // SharedPreferences에 서버 데이터 저장
                val prefs =
                    context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
                prefs.edit().apply {
                    putString("med_time", response)        // 서버에서 온 시간 (예: "14:30")
                    putString("last_update_date", today)   // 오늘 날짜로 갱신
                    apply()
                }

                // 데이터 저장 후 위젯 UI 강제 갱신 호출
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val componentName = ComponentName(context, HomeWidgetProvider::class.java)
                val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
                onUpdate(context, appWidgetManager, appWidgetIds)

                Log.d("WIDGET_DEBUG", "서버 동기화 완료: $response")
            } catch (e: Exception) {
                Log.e("WIDGET_DEBUG", "서버 연결 실패: ${e.message}")
            }
        }
    }

    // 시스템 신호를 직접 수신하는 부분 추가
    override fun onReceive(context: Context, intent: Intent) {
        //Log.d("WIDGET_DEBUG", "신호 수신: ${intent.action}")
        android.util.Log.d("WIDGET_DEBUG", "신호 수신: ${intent.action}")

        super.onReceive(context, intent)

        // intent.action이 null일 수 있으므로 안전하게 체크
        val action = intent.action

        // Intent.ACTION_TIME_SET의 실제 문자열 값은 "android.intent.action.TIME_SET" 입니다.
        if (action == "android.intent.action.DATE_CHANGED" ||
            action == "android.intent.action.TIMEZONE_CHANGED" ||
            action == "android.intent.action.TIME_SET" ||
            action == "android.intent.action.BOOT_COMPLETED"
        ) {

            // 재부팅이나 날짜 변경 시 서버에서 최신 상태를 한 번 긁어옴
            //fetchServerData(context)
            val appWidgetManager = AppWidgetManager.getInstance(context)

            // 본인 위젯 클래스 명칭(HomeWidgetProvider)을 정확히 입력
            val componentName = ComponentName(context, HomeWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
            onUpdate(context, appWidgetManager, appWidgetIds)


        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        // 1. 현재 실제 오늘 날짜 계산
        val sdf = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
        val today = sdf.format(Date())

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.home_widget_layout)

            // 2. SharedPreferences 로드 (home_widget 패키지 기본 저장소)
            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)

            // Flutter에서 넘겨준 값들 읽기
            val lastUpdateDate = prefs.getString("last_update_date", "") // 예: "2024-05-20"
            val medTime = prefs.getString("med_time", "") ?: "" // 예: "14:30" 또는 ""

            val displayTime: String
            val isDone: Boolean

            // 3. 핵심 로직: 저장된 날짜가 오늘과 일치하고, 복용 시간 데이터가 있는가?
            if (lastUpdateDate == today && medTime.isNotEmpty()) {
                // 오늘 복용 완료한 상태
                displayTime = "${medTime}에 비타민\n복용 완료!"
                isDone = true
            } else {
                // 날짜가 지났거나 오늘 기록이 없는 상태 (초기화)
                displayTime = "💊약은 드셨어?\n그래?"
                isDone = false
            }

            // 4. UI 업데이트
            views.setTextViewText(R.id.med_time, displayTime)

            if (isDone) {
                // 완료 상태 UI
                views.setInt(R.id.widget_root, "setBackgroundResource", R.drawable.widget_bg_done)
                views.setTextColor(R.id.med_time, Color.parseColor("#BDBDBD"))
            } else {
                // 미복용 상태 UI (강조)
                views.setInt(R.id.widget_root, "setBackgroundResource", R.drawable.widget_bg_alert)
                views.setTextColor(R.id.med_time, Color.WHITE)
            }

            // 5. 클릭 시 앱 실행 설정
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            // 6. 위젯 갱신 적용
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

    }

}