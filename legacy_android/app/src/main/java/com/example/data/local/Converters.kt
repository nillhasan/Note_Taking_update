package com.example.data.local

import androidx.room.TypeConverter
import com.example.data.model.TranscriptSegment
import com.squareup.moshi.Moshi
import com.squareup.moshi.Types
import com.squareup.moshi.kotlin.reflect.KotlinJsonAdapterFactory

class Converters {
    private val moshi = Moshi.Builder()
        .add(KotlinJsonAdapterFactory())
        .build()

    private val stringListType = Types.newParameterizedType(List::class.java, String::class.java)
    private val stringListAdapter = moshi.adapter<List<String>>(stringListType)

    private val segmentListType = Types.newParameterizedType(List::class.java, TranscriptSegment::class.java)
    private val segmentListAdapter = moshi.adapter<List<TranscriptSegment>>(segmentListType)

    @TypeConverter
    fun fromStringList(value: List<String>?): String {
        return if (value == null) "[]" else stringListAdapter.toJson(value)
    }

    @TypeConverter
    fun toStringList(value: String?): List<String> {
        if (value.isNullOrBlank()) return emptyList()
        return try {
            stringListAdapter.fromJson(value) ?: emptyList()
        } catch (e: Exception) {
            emptyList()
        }
    }

    @TypeConverter
    fun fromSegmentList(value: List<TranscriptSegment>?): String {
        return if (value == null) "[]" else segmentListAdapter.toJson(value)
    }

    @TypeConverter
    fun toSegmentList(value: String?): List<TranscriptSegment> {
        if (value.isNullOrBlank()) return emptyList()
        return try {
            segmentListAdapter.fromJson(value) ?: emptyList()
        } catch (e: Exception) {
            emptyList()
        }
    }
}
