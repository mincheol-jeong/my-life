package com.mincheol.mylife

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

class PaymentNotificationListener : NotificationListenerService() {
    override fun onNotificationPosted(notification: StatusBarNotification) {
        if (notification.notification.flags and Notification.FLAG_GROUP_SUMMARY != 0) return
        val store = PaymentInbox(this)
        if (!store.enabled || notification.packageName !in store.selected) return
        val extras = notification.notification.extras
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        val body = (extras.getCharSequence(Notification.EXTRA_BIG_TEXT)
            ?: extras.getCharSequence(Notification.EXTRA_TEXT))?.toString().orEmpty()
        val text = "$title\n$body"
        // Only purchase-looking messages enter the local handoff queue.
        if (!Regex("승인|결제|이용").containsMatchIn(text) || !Regex("\\d[\\d,]*\\s*원").containsMatchIn(text)) return
        if (Regex("취소|환불|충전|입금|이체|청구|결제예정|인증번호").containsMatchIn(text)) return
        store.add(notification.packageName, "${notification.key}|${notification.postTime}",
            text, notification.postTime)
    }
}
