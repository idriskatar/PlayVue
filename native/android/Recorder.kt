package com.playvue.playvue

import java.io.BufferedInputStream
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.io.InputStream
import java.io.OutputStream
import java.net.HttpURLConnection
import java.net.URI
import java.net.URL

/**
 * Canlı akışı dosyaya yazar. Ham TS akışı ve şifresiz HLS (TS segment) desteklenir.
 * Bağlantı koparsa bitiş zamanına kadar yeniden bağlanır.
 */
class Recorder(
    private val url: String,
    private val ua: String?,
    private val out: File,
    private val endMs: Long,
    private val onBytes: (Long) -> Unit
) {
    @Volatile private var stopFlag = false
    @Volatile private var finished = false
    @Volatile private var conn: HttpURLConnection? = null
    @Volatile var stoppedByUser = false
    @Volatile var bytes = 0L
    @Volatile var error: String? = null

    fun stop() {
        stoppedByUser = true
        stopFlag = true
        try { conn?.disconnect() } catch (_: Exception) {}
    }

    private fun done() = stopFlag || System.currentTimeMillis() >= endMs

    private fun open(u: String): Pair<HttpURLConnection, String> {
        var cur = u
        for (n in 0 until 6) {
            val c = URL(cur).openConnection() as HttpURLConnection
            c.instanceFollowRedirects = false
            c.connectTimeout = 15000
            c.readTimeout = 20000
            c.setRequestProperty("User-Agent", ua ?: "Mozilla/5.0 PlayVue")
            c.connect()
            val code = c.responseCode
            if (code in 300..399) {
                val loc = c.getHeaderField("Location")
                c.disconnect()
                if (loc == null) throw IOException("Yönlendirme hatası")
                cur = URI(cur).resolve(loc).toString()
                continue
            }
            if (code >= 400) {
                c.disconnect()
                throw IOException("HTTP $code")
            }
            return Pair(c, cur)
        }
        throw IOException("Çok fazla yönlendirme")
    }

    fun run() {
        FileOutputStream(out, true).use { fos ->
            while (!done() && !finished) {
                try {
                    val (c, finalUrl) = open(url)
                    conn = c
                    val input = BufferedInputStream(c.inputStream, 65536)
                    input.mark(16)
                    val head = ByteArray(7)
                    val n = input.read(head)
                    input.reset()
                    val isHls = (n == 7 && String(head) == "#EXTM3U")
                    if (isHls) {
                        val text = input.readBytes().toString(Charsets.UTF_8)
                        c.disconnect()
                        hls(finalUrl, text, fos)
                    } else {
                        val vod = c.contentLengthLong > 0
                        copy(input, fos)
                        c.disconnect()
                        if (vod && !done()) finished = true
                    }
                } catch (e: Exception) {
                    if (done()) break
                    error = e.message
                }
                if (!done() && !finished) sleepMs(2000)
            }
        }
    }

    private fun copy(inp: InputStream, os: OutputStream) {
        val buf = ByteArray(65536)
        while (!done()) {
            val r = try {
                inp.read(buf)
            } catch (e: IOException) {
                if (done()) return else throw e
            }
            if (r < 0) return
            os.write(buf, 0, r)
            bytes += r
            onBytes(bytes)
        }
    }

    private fun fetchText(u: String): String {
        val (c, _) = open(u)
        conn = c
        try {
            return c.inputStream.readBytes().toString(Charsets.UTF_8)
        } finally {
            c.disconnect()
        }
    }

    private fun sleepMs(ms: Long) {
        var w = 0L
        while (w < ms && !done()) {
            Thread.sleep(200)
            w += 200
        }
    }

    private fun hls(startUrl: String, firstText: String?, os: OutputStream) {
        var plUrl = startUrl
        var text = firstText
        val seen = LinkedHashSet<String>()
        while (!done()) {
            val body = text ?: fetchText(plUrl)
            text = null
            val lines = body.lines().map { it.trim() }.filter { it.isNotEmpty() }

            if (lines.any { it.startsWith("#EXT-X-STREAM-INF") }) {
                var best = -1L
                var bestUri: String? = null
                for (i in lines.indices) {
                    if (!lines[i].startsWith("#EXT-X-STREAM-INF")) continue
                    val bw = Regex("BANDWIDTH=(\\d+)").find(lines[i])?.groupValues?.get(1)?.toLong() ?: 0L
                    val uri = lines.drop(i + 1).firstOrNull { !it.startsWith("#") }
                    if (uri != null && bw >= best) {
                        best = bw
                        bestUri = uri
                    }
                }
                plUrl = URI(plUrl).resolve(bestUri ?: throw IOException("HLS varyantı bulunamadı")).toString()
                continue
            }
            if (lines.any { it.startsWith("#EXT-X-KEY") && !it.contains("METHOD=NONE") }) {
                throw IOException("Şifreli HLS desteklenmiyor")
            }
            if (lines.any { it.startsWith("#EXT-X-MAP") }) {
                throw IOException("fMP4 HLS desteklenmiyor")
            }

            var target = 4.0
            lines.firstOrNull { it.startsWith("#EXT-X-TARGETDURATION") }
                ?.substringAfter(":")?.trim()?.toDoubleOrNull()?.let { target = it }

            for (l in lines) {
                if (l.startsWith("#")) continue
                val seg = URI(plUrl).resolve(l).toString()
                if (seen.contains(seg)) continue
                if (done()) break
                try {
                    val (c, _) = open(seg)
                    conn = c
                    try {
                        copy(c.inputStream, os)
                    } finally {
                        c.disconnect()
                    }
                } catch (e: Exception) {
                    if (done()) break
                    error = e.message
                }
                seen.add(seg)
                if (seen.size > 500) seen.remove(seen.first())
            }
            if (lines.contains("#EXT-X-ENDLIST")) {
                finished = true
                return
            }
            sleepMs((target * 500).toLong().coerceAtLeast(1000L))
        }
    }
}
