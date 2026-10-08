package com.sfdevelopers.stiksy

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.util.AtomicFile
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.UUID

/** Persistent sticker files; metadata reads and writes share one process lock. */
object StickerStore {
    const val LIMIT = 100 * 1024
    private fun root(context: Context) = File(context.filesDir, "sticker_packs").apply { mkdirs() }
    private fun validId(id: String) = id.matches(Regex("[a-zA-Z0-9_-]{1,80}"))
    fun directory(context: Context, id: String): File {
        require(validId(id)) { "Invalid pack identifier" }
        return File(root(context), id)
    }
    private fun writeJson(file: File, json: JSONObject) {
        val atomic = AtomicFile(file)
        val stream = atomic.startWrite()
        try { stream.write(json.toString().toByteArray()); atomic.finishWrite(stream) }
        catch (e: Exception) { atomic.failWrite(stream); throw e }
    }
    @Synchronized fun packs(context: Context): List<JSONObject> = root(context).listFiles().orEmpty()
        .filter { it.isDirectory && validId(it.name) }.mapNotNull { dir ->
            try { JSONObject(File(dir, "metadata.json").readText()) } catch (_: Exception) { null }
        }.sortedBy { it.optString("name") }
    @Synchronized fun pack(context: Context, id: String): JSONObject? {
        if (!validId(id)) return null
        val file = File(directory(context, id), "metadata.json")
        return if (file.exists()) JSONObject(file.readText()) else null
    }
    @Synchronized fun create(context: Context, name: String): JSONObject {
        require(packs(context).size < 10) { "You can keep up to 10 sticker packs. Remove a pack before creating another." }
        require(name.isNotBlank() && name.length <= 128) { "Enter a pack name (up to 128 characters)" }
        val id = "pack_" + UUID.randomUUID().toString().replace("-", "")
        val data = JSONObject().put("identifier", id).put("name", name.trim())
            .put("publisher", "Stiksy").put("tray", "tray.png").put("version", "1")
            .put("stickers", JSONArray())
        directory(context, id).mkdirs()
        writeJson(File(directory(context, id), "metadata.json"), data)
        return data
    }
    fun encode(png: ByteArray): ByteArray {
        val original = BitmapFactory.decodeByteArray(png, 0, png.size)
            ?: throw IllegalArgumentException("Unable to decode sticker")
        val bitmap = if (original.width == 512 && original.height == 512) original else
            Bitmap.createScaledBitmap(original, 512, 512, true)
        try {
            val format = if (Build.VERSION.SDK_INT >= 30) Bitmap.CompressFormat.WEBP_LOSSY else Bitmap.CompressFormat.WEBP
            for (quality in listOf(90, 80, 70, 60, 50, 40, 30, 20, 10, 5, 1)) {
                val output = ByteArrayOutputStream()
                check(bitmap.compress(format, quality, output)) { "WebP encoding failed" }
                val bytes = output.toByteArray()
                if (bytes.size < LIMIT) return bytes
            }
            throw IllegalArgumentException("This design cannot fit under 100 KB. Simplify it and try again.")
        } finally {
            if (bitmap !== original) bitmap.recycle()
            original.recycle()
        }
    }
    @Synchronized fun add(context: Context, id: String, webp: ByteArray, text: String): JSONObject {
        val data = pack(context, id) ?: throw IllegalArgumentException("Pack not found")
        val stickers = data.getJSONArray("stickers")
        require(stickers.length() < 30) { "A WhatsApp pack can contain up to 30 stickers" }
        require(webp.size < LIMIT) { "Sticker exceeds 100 KB" }
        val bitmap = BitmapFactory.decodeByteArray(webp, 0, webp.size) ?: error("Invalid WebP")
        try {
            require(bitmap.width == 512 && bitmap.height == 512) { "Sticker must be 512 × 512" }
            val filename = "sticker_" + UUID.randomUUID().toString().replace("-", "") + ".webp"
            val dir = directory(context, id)
            val file = File(dir, filename)
            file.writeBytes(webp)
            try {
                if (stickers.length() == 0) {
                    val tray = Bitmap.createScaledBitmap(bitmap, 96, 96, true)
                    try { File(dir, "tray.png").outputStream().use { check(tray.compress(Bitmap.CompressFormat.PNG, 100, it)) } }
                    finally { tray.recycle() }
                }
                stickers.put(JSONObject().put("file", filename).put("emojis", "💚").put("text", text.take(125)))
                data.put("version", (data.optString("version", "1").toLong() + 1).toString())
                writeJson(File(dir, "metadata.json"), data)
            } catch (e: Exception) { file.delete(); throw e }
            return data
        } finally { bitmap.recycle() }
    }
    @Synchronized fun readSticker(context: Context, id: String, filename: String): ByteArray {
        val data = pack(context, id) ?: error("Pack not found")
        val stickers = data.getJSONArray("stickers")
        require((0 until stickers.length()).any { stickers.getJSONObject(it).getString("file") == filename }) { "Sticker not found" }
        return File(directory(context, id), filename).readBytes()
    }
    @Synchronized fun rename(context: Context, id: String, name: String): JSONObject {
        require(name.isNotBlank() && name.trim().length <= 32) { "Enter a pack name (up to 32 characters)" }
        val data = pack(context, id) ?: error("Pack not found")
        data.put("name", name.trim()).put("version", (data.getString("version").toLong() + 1).toString())
        writeJson(File(directory(context, id), "metadata.json"), data)
        return data
    }
    @Synchronized fun removeSticker(context: Context, id: String, filename: String): JSONObject {
        val data = pack(context, id) ?: error("Pack not found")
        val stickers = data.getJSONArray("stickers")
        val index = (0 until stickers.length()).firstOrNull { stickers.getJSONObject(it).getString("file") == filename }
            ?: error("Sticker not found")
        stickers.remove(index)
        if (index == 0 && stickers.length() > 0) {
            val bytes = File(directory(context, id), stickers.getJSONObject(0).getString("file")).readBytes()
            val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size) ?: error("Invalid sticker")
            val tray = Bitmap.createScaledBitmap(bitmap, 96, 96, true)
            try { File(directory(context, id), "tray.png").outputStream().use { check(tray.compress(Bitmap.CompressFormat.PNG, 100, it)) } }
            finally { if (tray !== bitmap) tray.recycle(); bitmap.recycle() }
        }
        data.put("version", (data.getString("version").toLong() + 1).toString())
        writeJson(File(directory(context, id), "metadata.json"), data)
        File(directory(context, id), filename).delete()
        return data
    }
    @Synchronized fun delete(context: Context, id: String) { directory(context, id).deleteRecursively() }
}
