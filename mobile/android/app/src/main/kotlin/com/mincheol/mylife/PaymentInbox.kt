package com.mincheol.mylife

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

class PaymentInbox(context: Context) {
    private val preferences = context.getSharedPreferences("payment_import", Context.MODE_PRIVATE)
    val enabled: Boolean get() = preferences.getBoolean("enabled", false)
    val selected: Set<String> get() = preferences.getStringSet("selected", emptySet()) ?: emptySet()

    fun configure(enabled: Boolean, selected: List<String>) = synchronized(lock) {
        preferences.edit().putBoolean("enabled", enabled).putStringSet("selected", selected.toSet())
            .apply { if (!enabled) remove("pending") }.commit()
        Unit
    }

    fun add(source: String, id: String, text: String, receivedAt: Long) = synchronized(lock) {
        if (!enabled || source !in selected || text.isBlank() || text.length > 2000) return@synchronized
        val rows = read().filterNot { it.getString("id") == id }.toMutableList()
        rows.add(JSONObject().put("source", source).put("id", id).put("text", text).put("receivedAt", receivedAt))
        write(rows.takeLast(100))
    }

    fun pending(): List<Map<String, Any>> = synchronized(lock) {
        read().map { mapOf("source" to it.getString("source"), "id" to it.getString("id"),
            "text" to it.getString("text"), "receivedAt" to it.getLong("receivedAt")) }
    }

    fun acknowledge(ids: List<String>) = synchronized(lock) {
        write(read().filterNot { it.getString("id") in ids })
    }

    private fun read(): List<JSONObject> {
        val array = JSONArray(preferences.getString("pending", "[]"))
        val cutoff = System.currentTimeMillis() - 7L * 24 * 60 * 60 * 1000
        return (0 until array.length()).map { array.getJSONObject(it) }
            .filter { it.getLong("receivedAt") >= cutoff }
    }
    private fun write(rows: List<JSONObject>) {
        preferences.edit().putString("pending", JSONArray(rows).toString()).commit()
    }
    companion object { private val lock = Any() }
}
