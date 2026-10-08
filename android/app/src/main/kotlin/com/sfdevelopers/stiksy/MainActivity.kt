package com.sfdevelopers.stiksy

import android.Manifest
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.ClipboardManager
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val worker = Executors.newSingleThreadExecutor()
    private var pendingAdd: MethodChannel.Result? = null
    private val authority get() = "$packageName.stickercontentprovider"
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "stiksy/stickers").setMethodCallHandler { call, result ->
            if (call.method == "addToWhatsApp") {
                try {
                    check(pendingAdd == null) { "Finish the current WhatsApp request first" }
                    val id = requireNotNull(call.argument<String>("id"))
                    val pack = StickerStore.pack(this, id) ?: error("Pack not found")
                    require(pack.getJSONArray("stickers").length() in 3..30) { "Save at least 3 stickers in this pack before adding it to WhatsApp" }
                    val intent = Intent("com.whatsapp.intent.action.ENABLE_STICKER_PACK")
                        .setPackage(if (call.argument<Boolean>("business") == true) "com.whatsapp.w4b" else "com.whatsapp")
                        .putExtra("sticker_pack_id", id).putExtra("sticker_pack_authority", authority)
                        .putExtra("sticker_pack_name", pack.getString("name"))
                    pendingAdd = result
                    startActivityForResult(intent, 8201)
                } catch (_: ActivityNotFoundException) { pendingAdd = null; result.error("whatsapp_unavailable", "Install or update the selected WhatsApp app first.", null) }
                catch (e: Exception) { pendingAdd = null; result.error("pack_error", e.message, null) }
                return@setMethodCallHandler
            }
            if (call.method == "availableWhatsApp") {
                fun installed(name: String): Boolean = try { packageManager.getPackageInfo(name, 0); true } catch (_: PackageManager.NameNotFoundException) { false }
                result.success(mapOf("whatsapp" to installed("com.whatsapp"), "business" to installed("com.whatsapp.w4b")))
                return@setMethodCallHandler
            }
            if (call.method == "copySticker") {
                try {
                    val bytes = requireNotNull(call.argument<ByteArray>("bytes"))
                    val dir = File(cacheDir, "shared_stickers").apply { mkdirs() }
                    val file = File(dir, "clipboard_${System.currentTimeMillis()}.webp").apply { writeBytes(bytes) }
                    val uri = FileProvider.getUriForFile(this, "$packageName.stickerfiles", file)
                    (getSystemService(CLIPBOARD_SERVICE) as ClipboardManager).setPrimaryClip(ClipData.newUri(contentResolver, "Stiksy sticker", uri))
                    result.success(null)
                } catch (e: Exception) { result.error("clipboard_error", e.message, null) }
                return@setMethodCallHandler
            }
            if (call.method == "shareToWhatsApp") {
                try {
                    val bytes = requireNotNull(call.argument<ByteArray>("bytes"))
                    val dir = File(cacheDir, "shared_stickers").apply { mkdirs() }
                    val file = File(dir, "stiksy_${System.currentTimeMillis()}.webp").apply { writeBytes(bytes) }
                    val uri = FileProvider.getUriForFile(this, "$packageName.stickerfiles", file)
                    val intent = Intent(Intent.ACTION_SEND).setType("image/webp")
                        .setPackage(if (call.argument<Boolean>("business") == true) "com.whatsapp.w4b" else "com.whatsapp")
                        .putExtra(Intent.EXTRA_STREAM, uri).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    intent.clipData = ClipData.newUri(contentResolver, "Stiksy sticker", uri)
                    startActivity(intent)
                    result.success(null)
                } catch (_: ActivityNotFoundException) { result.error("whatsapp_unavailable", "Install or update the selected WhatsApp app first.", null) }
                catch (e: Exception) { result.error("share_error", e.message, null) }
                return@setMethodCallHandler
            }
            if (call.method == "saveToGallery" && Build.VERSION.SDK_INT < 29 && checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
                result.error("gallery_permission", "Allow storage access to save this sticker.", null)
                return@setMethodCallHandler
            }
            worker.execute {
                try {
                    val value: Any? = when (call.method) {
                        "encodeWebP" -> StickerStore.encode(requireNotNull(call.argument<ByteArray>("png")))
                        "listPacks" -> StickerStore.packs(this).map { it.toString() }
                        "createPack" -> StickerStore.create(this, requireNotNull(call.argument<String>("name"))).toString()
                        "addSticker" -> {
                            val id = requireNotNull(call.argument<String>("id"))
                            val data = StickerStore.add(this, id, requireNotNull(call.argument<ByteArray>("bytes")), call.argument<String>("text") ?: "Stiksy sticker")
                            contentResolver.notifyChange(Uri.parse("content://$authority/metadata/$id"), null)
                            contentResolver.notifyChange(Uri.parse("content://$authority/stickers/$id"), null)
                            data.toString()
                        }
                        "readSticker" -> StickerStore.readSticker(this, requireNotNull(call.argument<String>("id")), requireNotNull(call.argument<String>("file")))
                        "renamePack", "removeSticker" -> {
                            val id = requireNotNull(call.argument<String>("id"))
                            val data = if (call.method == "renamePack") StickerStore.rename(this, id, requireNotNull(call.argument<String>("name")))
                                else StickerStore.removeSticker(this, id, requireNotNull(call.argument<String>("file")))
                            contentResolver.notifyChange(Uri.parse("content://$authority/metadata/$id"), null)
                            contentResolver.notifyChange(Uri.parse("content://$authority/stickers/$id"), null)
                            data.toString()
                        }
                        "deletePack" -> { StickerStore.delete(this, requireNotNull(call.argument<String>("id"))); null }
                        "saveToGallery" -> saveToGallery(requireNotNull(call.argument<ByteArray>("bytes")))
                        else -> { runOnUiThread { result.notImplemented() }; return@execute }
                    }
                    runOnUiThread { result.success(value) }
                } catch (e: Exception) { runOnUiThread { result.error("sticker_error", e.message ?: "Sticker operation failed", null) } }
            }
        }
    }
    private fun saveToGallery(bytes: ByteArray): String {
        val name = "Stiksy_${System.currentTimeMillis()}.webp"
        if (Build.VERSION.SDK_INT >= 29) {
            val values = ContentValues().apply { put(MediaStore.Images.Media.DISPLAY_NAME, name); put(MediaStore.Images.Media.MIME_TYPE, "image/webp"); put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/Stiksy"); put(MediaStore.Images.Media.IS_PENDING, 1) }
            val uri = contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values) ?: error("Unable to create gallery image")
            try {
                (contentResolver.openOutputStream(uri) ?: error("Unable to save image")).use { it.write(bytes) }
                values.clear(); values.put(MediaStore.Images.Media.IS_PENDING, 0); contentResolver.update(uri, values, null, null)
                return uri.toString()
            } catch (e: Exception) { contentResolver.delete(uri, null, null); throw e }
        }
        val dir = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES), "Stiksy").apply { mkdirs() }
        val file = File(dir, name).apply { writeBytes(bytes) }
        MediaScannerConnection.scanFile(this, arrayOf(file.absolutePath), arrayOf("image/webp"), null)
        return file.absolutePath
    }
    @Deprecated("Legacy WhatsApp confirmation callback")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 8201) {
            val error = data?.getStringExtra("validation_error")
            pendingAdd?.success(mapOf("status" to if (resultCode == Activity.RESULT_OK) "added" else if (error != null) "rejected" else "cancelled", "message" to (error ?: "")))
            pendingAdd = null
        }
    }
    override fun onDestroy() { worker.shutdown(); super.onDestroy() }
}
