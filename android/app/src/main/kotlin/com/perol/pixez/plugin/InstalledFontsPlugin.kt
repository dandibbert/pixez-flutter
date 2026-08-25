package com.perol.pixez.plugin

import android.graphics.fonts.SystemFonts
import android.os.Build
import android.util.Xml
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.xmlpull.v1.XmlPullParser
import java.io.File
import java.io.FileInputStream
import java.io.RandomAccessFile
import java.nio.charset.Charset

class InstalledFontsPlugin {
    companion object {
        private const val CHANNEL = "com.perol.dev/fonts"
        private const val TAG_TTCF = 0x74746366
        private const val TAG_NAME = 0x6E616D65

        fun bindChannel(flutterEngine: FlutterEngine) {
            MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                CHANNEL
            ).setMethodCallHandler { call, result ->
                if (call.method == "listFamilies") {
                    result.success(listFamilies())
                } else {
                    result.notImplemented()
                }
            }
        }

        private fun listFamilies(): List<String> {
            val names = sortedSetOf(String.CASE_INSENSITIVE_ORDER)
            parseXmlFile(File("/system/etc/fonts.xml"), names)
            parseXmlFile(File("/system/etc/font_fallback.xml"), names)
            parseXmlFile(File("/product/etc/fonts_customization.xml"), names)
            File("/system/etc").listFiles()?.forEach { file ->
                if (file.isFile && file.name.contains("font") && file.extension == "xml") {
                    parseXmlFile(file, names)
                }
            }
            parseXmlFile(File("/data/fonts/files/fonts.xml"), names)
            scanFontFiles(File("/system/fonts"), names)
            scanFontFiles(File("/product/fonts"), names)
            scanFontFiles(File("/data/fonts"), names)
            scanFontFiles(File("/sdcard/Fonts"), names)
            scanFontFiles(File("/sdcard/fonts"), names)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                for (font in SystemFonts.getAvailableFonts()) {
                    font.file?.let { addFileName(it, names) }
                }
            }
            return names.filter { it.isNotBlank() }
        }

        private fun parseXmlFile(file: File, names: MutableSet<String>) {
            if (!file.exists() || !file.canRead()) {
                return
            }
            try {
                FileInputStream(file).use { input ->
                    val parser = Xml.newPullParser()
                    parser.setInput(input, null)
                    var event = parser.eventType
                    while (event != XmlPullParser.END_DOCUMENT) {
                        if (event == XmlPullParser.START_TAG) {
                            val tag = parser.name
                            if (tag == "family" || tag == "alias") {
                                parser.getAttributeValue(null, "name")?.let { names.add(it) }
                                parser.getAttributeValue(null, "to")?.let { names.add(it) }
                            }
                        }
                        event = parser.next()
                    }
                }
            } catch (_: Exception) {
            }
        }

        private fun scanFontFiles(directory: File, names: MutableSet<String>) {
            if (!directory.exists() || !directory.canRead()) {
                return
            }
            directory.walkTopDown().maxDepth(3).forEach { file ->
                if (file.isFile) {
                    addFileName(file, names)
                }
            }
        }

        private fun addFileName(file: File, names: MutableSet<String>) {
            val ext = file.extension.lowercase()
            if (ext != "ttf" && ext != "otf" && ext != "ttc" && ext != "otc") {
                return
            }
            familyNameFromFontFile(file)?.let { names.add(it) }
            val base = file.nameWithoutExtension
                .substringBeforeLast('-')
                .substringBeforeLast('_')
                .trim()
            if (base.isNotEmpty()) {
                names.add(base)
            }
        }

        private fun familyNameFromFontFile(file: File): String? {
            return try {
                RandomAccessFile(file, "r").use { raf ->
                    val magic = raf.readInt()
                    val offset = if (magic == TAG_TTCF) {
                        raf.seek(12)
                        Integer.toUnsignedLong(raf.readInt())
                    } else {
                        0L
                    }
                    readNameTableFamily(raf, offset)
                }
            } catch (_: Exception) {
                null
            }
        }

        private fun readNameTableFamily(raf: RandomAccessFile, sfntOffset: Long): String? {
            raf.seek(sfntOffset + 4)
            val numTables = raf.readUnsignedShort()
            raf.skipBytes(6)
            var nameOffset = -1L
            for (i in 0 until numTables) {
                val tag = raf.readInt()
                raf.skipBytes(4)
                val tableOffset = Integer.toUnsignedLong(raf.readInt())
                raf.skipBytes(4)
                if (tag == TAG_NAME) {
                    nameOffset = sfntOffset + tableOffset
                    break
                }
            }
            if (nameOffset < 0) {
                return null
            }
            raf.seek(nameOffset)
            raf.skipBytes(2)
            val count = raf.readUnsignedShort()
            val stringOffset = raf.readUnsignedShort()
            val records = ArrayList<IntArray>(count)
            for (i in 0 until count) {
                records.add(
                    intArrayOf(
                        raf.readUnsignedShort(),
                        raf.readUnsignedShort(),
                        raf.readUnsignedShort(),
                        raf.readUnsignedShort(),
                        raf.readUnsignedShort(),
                        raf.readUnsignedShort(),
                    )
                )
            }
            fun readName(id: Int): String? {
                val matches = records.filter { it[3] == id }
                val rec = matches.firstOrNull { it[0] == 3 && (it[1] == 1 || it[1] == 10) }
                    ?: matches.firstOrNull { it[0] == 0 }
                    ?: matches.firstOrNull { it[0] == 1 }
                    ?: return null
                raf.seek(nameOffset + stringOffset + rec[5])
                val bytes = ByteArray(rec[4])
                raf.readFully(bytes)
                val text = when {
                    rec[0] == 3 || rec[0] == 0 -> String(bytes, Charsets.UTF_16BE)
                    else -> String(bytes, Charset.forName("ISO-8859-1"))
                }.trim()
                return text.takeIf { it.isNotEmpty() }
            }
            return readName(16) ?: readName(1)
        }
    }
}
