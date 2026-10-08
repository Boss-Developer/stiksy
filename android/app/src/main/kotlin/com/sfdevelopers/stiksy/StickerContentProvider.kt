package com.sfdevelopers.stiksy

import android.content.ContentProvider
import android.content.ContentValues
import android.content.res.AssetFileDescriptor
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.ParcelFileDescriptor
import java.io.File
import java.io.FileNotFoundException

/** WhatsApp's documented read-only sticker provider contract. */
class StickerContentProvider : ContentProvider() {
    override fun onCreate() = true
    override fun query(uri: Uri, projection: Array<out String>?, selection: String?, selectionArgs: Array<out String>?, sortOrder: String?): Cursor {
        val ctx = requireNotNull(context)
        val segments = uri.pathSegments
        require(segments.isNotEmpty()) { "Unknown sticker URI" }
        val cursor = when (segments[0]) {
            "metadata" -> {
                require(segments.size in 1..2)
                val columns = arrayOf("sticker_pack_identifier", "sticker_pack_name", "sticker_pack_publisher", "sticker_pack_icon", "android_play_store_link", "ios_app_download_link", "sticker_pack_publisher_email", "sticker_pack_publisher_website", "sticker_pack_privacy_policy_website", "sticker_pack_license_agreement_website", "image_data_version", "whatsapp_will_not_cache_stickers", "animated_sticker_pack")
                val result = MatrixCursor(columns)
                val packs = if (segments.size == 2) listOfNotNull(StickerStore.pack(ctx, segments[1])) else StickerStore.packs(ctx)
                for (pack in packs) {
                    // Incomplete packs must remain local until they contain at least 3 stickers.
                    if (pack.getJSONArray("stickers").length() < 3) continue
                    result.addRow(arrayOf(pack.getString("identifier"), pack.getString("name"), "Stiksy", "tray.png", "", "", "", "", "", "", pack.getString("version"), 0, 0))
                }
                result
            }
            "stickers" -> {
                require(segments.size == 2)
                val result = MatrixCursor(arrayOf("sticker_file_name", "sticker_emoji", "sticker_accessibility_text"))
                val pack = StickerStore.pack(ctx, segments[1])
                val stickers = pack?.getJSONArray("stickers")
                if (stickers != null) for (i in 0 until stickers.length()) {
                    val sticker = stickers.getJSONObject(i)
                    result.addRow(arrayOf(sticker.getString("file"), sticker.getString("emojis"), sticker.getString("text")))
                }
                result
            }
            else -> throw IllegalArgumentException("Unknown sticker URI")
        }
        cursor.setNotificationUri(ctx.contentResolver, uri)
        return cursor
    }
    private fun asset(uri: Uri): File {
        val parts = uri.pathSegments
        if (parts.size != 3 || parts[0] != "stickers_asset") throw FileNotFoundException("Unknown sticker asset")
        val ctx = requireNotNull(context)
        val pack = StickerStore.pack(ctx, parts[1]) ?: throw FileNotFoundException("Unknown pack")
        val filename = parts[2]
        val stickers = pack.getJSONArray("stickers")
        val known = filename == "tray.png" || (0 until stickers.length()).any { stickers.getJSONObject(it).getString("file") == filename }
        if (!known) throw FileNotFoundException("Unknown sticker")
        val dir = StickerStore.directory(ctx, parts[1])
        val file = File(dir, filename)
        if (file.canonicalFile.parentFile != dir.canonicalFile || !file.isFile) throw FileNotFoundException("Unknown sticker")
        return file
    }
    override fun openAssetFile(uri: Uri, mode: String): AssetFileDescriptor {
        if (mode != "r") throw FileNotFoundException("Read-only provider")
        val file = asset(uri)
        return AssetFileDescriptor(ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY), 0, file.length())
    }
    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor {
        if (mode != "r") throw FileNotFoundException("Read-only provider")
        return ParcelFileDescriptor.open(asset(uri), ParcelFileDescriptor.MODE_READ_ONLY)
    }
    override fun getType(uri: Uri): String = when (uri.pathSegments.firstOrNull()) {
        "metadata" -> if (uri.pathSegments.size == 1) "vnd.android.cursor.dir/vnd.${requireNotNull(context).packageName}.stickercontentprovider.metadata" else "vnd.android.cursor.item/vnd.${requireNotNull(context).packageName}.stickercontentprovider.metadata"
        "stickers" -> "vnd.android.cursor.dir/vnd.${requireNotNull(context).packageName}.stickercontentprovider.stickers"
        "stickers_asset" -> if (uri.lastPathSegment == "tray.png") "image/png" else "image/webp"
        else -> throw IllegalArgumentException("Unknown sticker URI")
    }
    override fun insert(uri: Uri, values: ContentValues?): Uri? = throw UnsupportedOperationException("Read only")
    override fun update(uri: Uri, values: ContentValues?, selection: String?, selectionArgs: Array<out String>?): Int = throw UnsupportedOperationException("Read only")
    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int = throw UnsupportedOperationException("Read only")
}
