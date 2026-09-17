package com.example.data.local

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.example.data.model.EmailActivityRecord
import kotlinx.coroutines.flow.Flow

@Dao
interface EmailActivityDao {
    @Query("SELECT * FROM email_activities WHERE noteId = :noteId ORDER BY sentAt DESC")
    fun getActivitiesForNote(noteId: String): Flow<List<EmailActivityRecord>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(record: EmailActivityRecord)
}
