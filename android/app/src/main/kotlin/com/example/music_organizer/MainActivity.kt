package com.example.music_organizer

import android.media.MediaMetadataRetriever
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.jaudiotagger.audio.AudioFileIO
import org.jaudiotagger.tag.FieldKey
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader
import java.io.FileInputStream
import java.security.MessageDigest

class MainActivity : FlutterFragmentActivity() {
    private val METADATA_CHANNEL = "music_organizer/metadata"
    private val ACOUSTID_CHANNEL = "music_organizer/acoustid"
    private val ID3_WRITER_CHANNEL = "music_organizer/id3_writer"
    private val UTILS_CHANNEL = "music_organizer/utils"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── Metadata extraction channel ──────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METADATA_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getAudioMetadata" -> {
                        val filePath = call.argument<String>("filePath")
                        if (filePath == null) {
                            result.error("INVALID_ARG", "filePath is required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val metadata = getAudioMetadata(filePath)
                            result.success(metadata)
                        } catch (e: Exception) {
                            result.error("METADATA_ERROR", e.message, null)
                        }
                    }
                    "getAudioMetadataBatch" -> {
                        val filePaths = call.argument<List<String>>("filePaths")
                        if (filePaths == null) {
                            result.error("INVALID_ARG", "filePaths is required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val results = filePaths.map { path ->
                                try {
                                    getAudioMetadata(path)
                                } catch (e: Exception) {
                                    mapOf("error" to e.message)
                                }
                            }
                            result.success(results)
                        } catch (e: Exception) {
                            result.error("BATCH_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // ── AcoustID fingerprint channel ─────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ACOUSTID_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "generateFingerprint" -> {
                        val filePath = call.argument<String>("filePath")
                        if (filePath == null) {
                            result.error("INVALID_ARG", "filePath is required", null)
                            return@setMethodCallHandler
                        }

                        val audioFile = File(filePath)
                        if (!audioFile.exists()) {
                            result.error("FILE_NOT_FOUND", "File not found: $filePath", null)
                            return@setMethodCallHandler
                        }

                        Thread {
                            try {
                                val fpcalcPath = applicationInfo.nativeLibraryDir + "/libfpcalc.so"
                                val fpcalcFile = File(fpcalcPath)

                                if (!fpcalcFile.exists()) {
                                    runOnUiThread {
                                        result.error(
                                            "FPCALC_NOT_FOUND",
                                            "fpcalc binary not bundled. " +
                                                "Place libfpcalc.so in jniLibs/arm64-v8a/",
                                            null
                                        )
                                    }
                                    return@Thread
                                }

                                fpcalcFile.setExecutable(true)

                                val process = ProcessBuilder(fpcalcPath, filePath)
                                    .redirectErrorStream(true)
                                    .start()

                                val reader = BufferedReader(InputStreamReader(process.inputStream))
                                val lines = reader.readLines()
                                val exitCode = process.waitFor()

                                if (exitCode != 0) {
                                    runOnUiThread {
                                        result.error(
                                            "FPCALC_ERROR",
                                            "fpcalc exited with code $exitCode: ${lines.joinToString("\n")}",
                                            null
                                        )
                                    }
                                    return@Thread
                                }

                                var fingerprint: String? = null
                                var duration: Int? = null

                                for (line in lines) {
                                    when {
                                        line.startsWith("FINGERPRINT=") ->
                                            fingerprint = line.substringAfter("FINGERPRINT=")
                                        line.startsWith("DURATION=") ->
                                            duration = line.substringAfter("DURATION=").toIntOrNull()
                                    }
                                }

                                if (fingerprint == null || duration == null) {
                                    runOnUiThread {
                                        result.error(
                                            "PARSE_ERROR",
                                            "Could not parse fpcalc output: ${lines.joinToString("\n")}",
                                            null
                                        )
                                    }
                                    return@Thread
                                }

                                val resultMap = mapOf(
                                    "fingerprint" to fingerprint,
                                    "duration" to duration
                                )

                                runOnUiThread {
                                    result.success(resultMap)
                                }
                            } catch (e: Exception) {
                                runOnUiThread {
                                    result.error("FINGERPRINT_ERROR", e.message, null)
                                }
                            }
                        }.start()
                    }
                    else -> result.notImplemented()
                }
            }

        // ── ID3 Writer Channel ───────────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ID3_WRITER_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "writeMetadata" -> {
                        val filePath = call.argument<String>("filePath")
                        if (filePath == null) {
                            result.error("INVALID_ARG", "filePath is required", null)
                            return@setMethodCallHandler
                        }

                        // Check permissions
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                            if (!Environment.isExternalStorageManager()) {
                                result.error(
                                    "PERMISSION_DENIED",
                                    "MANAGE_EXTERNAL_STORAGE is required on Android 11+",
                                    null
                                )
                                return@setMethodCallHandler
                            }
                        }

                        Thread {
                            try {
                                val audioFile = File(filePath)
                                if (!audioFile.exists()) {
                                    runOnUiThread {
                                        result.error("FILE_NOT_FOUND", "File not found at: $filePath", null)
                                    }
                                    return@Thread
                                }

                                val f = org.jaudiotagger.audio.AudioFileIO.read(audioFile)
                                var tag = f.tag
                                if (tag == null) {
                                    // Some files might not have any tag at all, create a default
                                    tag = f.createDefaultTag()
                                    f.tag = tag
                                }

                                val title = call.argument<String>("title")
                                val artist = call.argument<String>("artist")
                                val album = call.argument<String>("album")
                                val genre = call.argument<String>("genre")
                                val year = call.argument<String>("year")
                                val trackNumber = call.argument<String>("trackNumber")

                                if (title != null) tag.setField(FieldKey.TITLE, title)
                                if (artist != null) tag.setField(FieldKey.ARTIST, artist)
                                if (album != null) tag.setField(FieldKey.ALBUM, album)
                                if (genre != null) tag.setField(FieldKey.GENRE, genre)
                                if (year != null) tag.setField(FieldKey.YEAR, year)
                                if (trackNumber != null) tag.setField(FieldKey.TRACK, trackNumber)

                                AudioFileIO.write(f)

                                // Trigger MediaScanner so the Android system picks up the changes immediately
                                MediaScannerConnection.scanFile(
                                    this@MainActivity,
                                    arrayOf(filePath),
                                    null
                                ) { path, uri ->
                                    // Scan completed
                                }

                                runOnUiThread {
                                    result.success(true)
                                }
                            } catch (e: Exception) {
                                runOnUiThread {
                                    result.error("WRITE_ERROR", e.message, null)
                                }
                            }
                        }.start()
                    }
                    else -> result.notImplemented()
                }
            }

        // ── Utils Channel ────────────────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UTILS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getFileHash" -> {
                        val filePath = call.argument<String>("filePath")
                        if (filePath == null) {
                            result.error("INVALID_ARG", "filePath is required", null)
                            return@setMethodCallHandler
                        }

                        Thread {
                            try {
                                val file = File(filePath)
                                if (!file.exists()) {
                                    runOnUiThread {
                                        result.error("FILE_NOT_FOUND", "File not found at: $filePath", null)
                                    }
                                    return@Thread
                                }

                                val digest = MessageDigest.getInstance("SHA-256")
                                val inputStream = FileInputStream(file)
                                val buffer = ByteArray(8192)
                                var bytesRead: Int

                                while (inputStream.read(buffer).also { bytesRead = it } != -1) {
                                    digest.update(buffer, 0, bytesRead)
                                }
                                inputStream.close()

                                val hashBytes = digest.digest()
                                val hexString = StringBuilder(2 * hashBytes.size)
                                for (b in hashBytes) {
                                    val hex = Integer.toHexString(0xff and b.toInt())
                                    if (hex.length == 1) hexString.append('0')
                                    hexString.append(hex)
                                }

                                runOnUiThread {
                                    result.success(hexString.toString())
                                }
                            } catch (e: Exception) {
                                runOnUiThread {
                                    result.error("HASH_ERROR", e.message, null)
                                }
                            }
                        }.start()
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Reads audio metadata from a file using Android's MediaMetadataRetriever.
     *
     * Works on Android 10 (API 29) through Android 16 (API 36).
     */
    private fun getAudioMetadata(filePath: String): Map<String, Any?> {
        val retriever = MediaMetadataRetriever()
        return try {
            val file = File(filePath)
            if (!file.exists()) {
                throw IllegalArgumentException("File not found: $filePath")
            }

            retriever.setDataSource(filePath)

            val title = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_TITLE)
            val artist = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ARTIST)
            val album = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ALBUM)
            val genre = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_GENRE)
            val year = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_YEAR)
            val trackNumber = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_CD_TRACK_NUMBER)

            val durationStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
            val duration = durationStr?.toLongOrNull()

            val bitrateStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_BITRATE)
            val bitrate = bitrateStr?.toIntOrNull()

            val sampleRateStr = retriever.extractMetadata(
                MediaMetadataRetriever.METADATA_KEY_SAMPLERATE
            )
            val sampleRate = sampleRateStr?.toIntOrNull()

            val mimeType = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_MIMETYPE)

            // Check if embedded album art exists
            val embeddedArt = retriever.embeddedPicture
            val hasAlbumArt = embeddedArt != null

            mapOf(
                "title" to title,
                "artist" to artist,
                "album" to album,
                "genre" to genre,
                "year" to year,
                "trackNumber" to trackNumber,
                "duration" to duration,
                "bitrate" to bitrate,
                "sampleRate" to sampleRate,
                "mimeType" to mimeType,
                "hasAlbumArt" to hasAlbumArt
            )
        } finally {
            retriever.release()
        }
    }
}
