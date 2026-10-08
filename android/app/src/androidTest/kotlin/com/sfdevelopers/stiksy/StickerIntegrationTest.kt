package com.sfdevelopers.stiksy

import android.content.Context
import android.content.ContextWrapper
import android.content.pm.ProviderInfo
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.net.Uri
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileNotFoundException
import java.util.UUID
import kotlin.random.Random

@RunWith(AndroidJUnit4::class)
class StickerIntegrationTest {
    private lateinit var context: Context
    private lateinit var root: File
    private lateinit var provider: StickerContentProvider
    @Before fun setup() {
        val target = InstrumentationRegistry.getInstrumentation().targetContext
        // Tests use a separate temporary filesDir; existing user packs/preferences are untouched.
        root = File(target.cacheDir, "sticker_test_${UUID.randomUUID()}").apply { mkdirs() }
        context = object : ContextWrapper(target) { override fun getFilesDir() = root }
        provider = StickerContentProvider()
        provider.attachInfo(context, ProviderInfo().apply { authority = "${target.packageName}.stickercontentprovider" })
    }
    @After fun cleanup() { root.deleteRecursively() }
    private fun png(size: Int = 512, color: Int = Color.GREEN): ByteArray {
        val image = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        Canvas(image).drawCircle(size / 2f, size / 2f, size / 3f, Paint().apply { this.color = color })
        val output = ByteArrayOutputStream(); image.compress(Bitmap.CompressFormat.PNG, 100, output); image.recycle()
        return output.toByteArray()
    }
    private fun uri(path: String) = Uri.parse("content://${context.packageName}.stickercontentprovider/$path")
    @Test fun webpIs512TransparentAndBelow100Kb() {
        val webp = StickerStore.encode(png(256))
        assertTrue(webp.size < 100 * 1024)
        assertEquals("RIFF", String(webp.copyOfRange(0, 4)))
        assertEquals("WEBP", String(webp.copyOfRange(8, 12)))
        val decoded = BitmapFactory.decodeByteArray(webp, 0, webp.size)
        assertEquals(512, decoded.width); assertEquals(512, decoded.height)
        assertEquals(0, Color.alpha(decoded.getPixel(0, 0)))
        assertTrue(Color.alpha(decoded.getPixel(256, 256)) > 0)
        decoded.recycle()
    }
    @Test fun noisyColorImageIsCompressedWithoutReducingResolution() {
        val image = Bitmap.createBitmap(512, 512, Bitmap.Config.ARGB_8888)
        val random = Random(42)
        image.setPixels(IntArray(512 * 512) { Color.rgb(random.nextInt(256), random.nextInt(256), random.nextInt(256)) }, 0, 512, 0, 0, 512, 512)
        val output = ByteArrayOutputStream(); image.compress(Bitmap.CompressFormat.PNG, 100, output); image.recycle()
        val webp = StickerStore.encode(output.toByteArray())
        assertTrue(webp.size < 100 * 1024)
        val decoded = BitmapFactory.decodeByteArray(webp, 0, webp.size)
        assertEquals(512, decoded.width); assertEquals(512, decoded.height); decoded.recycle()
    }
    @Test fun providerPublishesOnlyCompletePacksAndServesCorrectFiles() {
        val created = StickerStore.create(context, "Protocol test")
        val id = created.getString("identifier")
        provider.query(uri("metadata/$id"), null, null, null, null).use { assertEquals(0, it.count) }
        var pack = created
        for (color in listOf(Color.RED, Color.GREEN, Color.BLUE)) pack = StickerStore.add(context, id, StickerStore.encode(png(color = color)), "Test circle")
        provider.query(uri("metadata/$id"), null, null, null, null).use {
            assertEquals(1, it.count); assertTrue(it.moveToFirst())
            assertEquals(id, it.getString(it.getColumnIndexOrThrow("sticker_pack_identifier")))
            assertEquals("4", it.getString(it.getColumnIndexOrThrow("image_data_version")))
            assertEquals(0, it.getInt(it.getColumnIndexOrThrow("animated_sticker_pack")))
        }
        provider.query(uri("stickers/$id"), null, null, null, null).use { assertEquals(3, it.count) }
        val file = pack.getJSONArray("stickers").getJSONObject(0).getString("file")
        provider.openAssetFile(uri("stickers_asset/$id/$file"), "r").use { descriptor ->
            val bytes = descriptor.createInputStream().use { it.readBytes() }
            assertTrue(bytes.size < 100 * 1024)
            assertArrayEquals(File(StickerStore.directory(context, id), file).readBytes(), bytes)
        }
        provider.openAssetFile(uri("stickers_asset/$id/tray.png"), "r").use { descriptor ->
            val bytes = descriptor.createInputStream().use { it.readBytes() }
            assertTrue(bytes.size < 50 * 1024)
            val tray = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
            assertEquals(96, tray.width); assertEquals(96, tray.height); tray.recycle()
        }
        try { provider.openAssetFile(uri("stickers_asset/$id/metadata.json"), "r"); fail("Private metadata must not be exposed") } catch (_: FileNotFoundException) { }
        try { StickerStore.directory(context, "../outside"); fail("Traversal must be rejected") } catch (_: IllegalArgumentException) { }
    }
    @Test fun maximumPackSizeAndInvalidInputAreRejected() {
        val id = StickerStore.create(context, "Capacity test").getString("identifier")
        val bytes = StickerStore.encode(png())
        repeat(30) { StickerStore.add(context, id, bytes, "Test $it") }
        try { StickerStore.add(context, id, bytes, "31st"); fail("31st sticker must be rejected") } catch (_: IllegalArgumentException) { }
        try { StickerStore.encode(byteArrayOf(1, 2, 3)); fail("Invalid image must be rejected") } catch (_: IllegalArgumentException) { }
    }
    @Test fun manifestProtectsExportedProviderWithWhatsAppReadPermission() {
        val info = context.packageManager.resolveContentProvider("${context.packageName}.stickercontentprovider", 0)
        assertNotNull(info); assertTrue(info!!.exported)
        assertEquals("com.whatsapp.sticker.READ", info.readPermission)
        val files = context.packageManager.resolveContentProvider("${context.packageName}.stickerfiles", 0)
        assertNotNull(files); assertFalse(files!!.exported); assertTrue(files.grantUriPermissions)
    }
    @Test fun renameAndRemoveUpdatePackVersionAndRejectPrivateFiles() {
        val id = StickerStore.create(context, "Original").getString("identifier")
        val bytes = StickerStore.encode(png())
        var pack = StickerStore.create(context, "Other pack")
        repeat(3) { pack = StickerStore.add(context, id, bytes, "Test sticker") }
        val first = pack.getJSONArray("stickers").getJSONObject(0).getString("file")
        assertArrayEquals(bytes, StickerStore.readSticker(context, id, first))
        try { StickerStore.readSticker(context, id, "metadata.json"); fail("Private metadata must not be readable") } catch (_: IllegalArgumentException) { }
        pack = StickerStore.rename(context, id, "Renamed")
        assertEquals("Renamed", pack.getString("name"))
        assertEquals("5", pack.getString("version"))
        pack = StickerStore.removeSticker(context, id, first)
        assertEquals(2, pack.getJSONArray("stickers").length())
        assertEquals("6", pack.getString("version"))
        assertFalse(File(StickerStore.directory(context, id), first).exists())
        provider.query(uri("metadata/$id"), null, null, null, null).use { assertEquals(0, it.count) }
        try { StickerStore.removeSticker(context, id, "../metadata.json"); fail("Unknown files must be rejected") } catch (_: IllegalStateException) { }
    }
}
